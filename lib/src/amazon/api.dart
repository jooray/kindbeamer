import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'models.dart';
import 'signer.dart';

const String _firsUrl = 'https://firs-ta-g7g.amazon.com';
const String _stkUrl = 'https://stkservice.amazon.com';

const String clientIdPublic =
    '658490dfb190e494030082836775981fa23be0c2425441860352ba0f55915b43002d';

Map<String, String> _clientInfo() {
  String os;
  String arch;
  if (Platform.isMacOS) {
    os = 'MacOSX_10.14.6_x64';
    arch = 'x64';
  } else if (Platform.isAndroid) {
    os = 'Android_13_arm64';
    arch = 'arm64';
  } else if (Platform.isWindows) {
    os = 'Windows10_10.0_x64';
    arch = 'x64';
  } else {
    os = 'Linux_5.15_x64';
    arch = 'x64';
  }
  return {
    'appName': 'ShellExtension',
    'appVersion': '1.1.1.253',
    'os': os,
    'osArchitecture': arch,
  };
}

const Map<String, String> _commonHeaders = {
  'Accept-Language': 'en-US,*',
  'User-Agent': 'Mozilla/5.0',
};

Future<String> tokenExchange(
  String authorizationCode,
  String codeVerifier,
) async {
  final body = json.encode({
    'app_name': 'Unknown',
    'client_domain': 'DeviceLegacy',
    'client_id': clientIdPublic,
    'code_algorithm': 'SHA-256',
    'code_verifier': codeVerifier,
    'requested_token_type': 'access_token',
    'source_token': authorizationCode,
    'source_token_type': 'authorization_code',
  });
  final res = await http.post(
    Uri.parse('https://api.amazon.com/auth/token'),
    headers: {
      'Accept-Language': 'en-US',
      'x-amzn-identity-auth-domain': 'api.amazon.com',
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0',
    },
    body: body,
  );
  if (res.statusCode != 200) {
    throw ApiError('token exchange failed: HTTP ${res.statusCode}', res.body);
  }
  final token = (json.decode(res.body) as Map<String, dynamic>)['access_token'];
  if (token is! String || token.isEmpty) {
    throw ApiError(
      'token exchange returned no access token',
      _snippet(res.body),
    );
  }
  return token;
}

/// Enough of a response body to diagnose a failure, without pasting a whole
/// error page into the UI.
String _snippet(String body, [int max = 400]) {
  final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length <= max ? flat : '${flat.substring(0, max)}…';
}

/// Amazon has moved these fields between nesting levels before, so take every
/// leaf element regardless of where it sits.
Map<String, String> _flattenXml(XmlElement root) {
  final out = <String, String>{};
  void walk(XmlElement el) {
    final children = el.children.whereType<XmlElement>().toList();
    if (children.isEmpty) {
      out.putIfAbsent(el.name.local, () => el.innerText.trim());
      return;
    }
    for (final child in children) {
      walk(child);
    }
  }

  walk(root);
  return out;
}

/// Serial and pid of the registered device.
///
/// These two travel together and cannot be made up: registering with a freshly
/// generated serial (base32, same shape) against this pid answers
/// `<error><message>Internal Error</message></error>`, so the pid evidently has
/// to correspond to the serial. Both independent ports of this protocol —
/// `stkclient` (Python) and `stkclient-swift` — ship this same pair, which is
/// what the service accepts.
///
/// The cost is that one Amazon account can hold one KindBeamer registration at
/// a time: signing in on a second machine re-registers the same serial and
/// retires the first machine's credentials. Deriving a matching pid would lift
/// that; see the roadmap.
const String deviceSerialNumber = 'ZYSQ37GQ5JQDAIKDZ3WYH6I74MJCVEGG';
const String devicePid = 'D21NN3GG';

Future<http.Response> _postBytes(
  String url,
  Map<String, String> headers,
  List<int> bodyBytes,
) async {
  final client = http.Client();
  try {
    final request = http.Request('POST', Uri.parse(url))
      ..headers.addAll(headers)
      ..bodyBytes = bodyBytes;
    return await http.Response.fromStream(await client.send(request));
  } finally {
    client.close();
  }
}

Future<DeviceInfo> registerDeviceWithToken(String accessToken) async {
  const deviceType = 'A1K6D1WRW0MALS';
  const serial = deviceSerialNumber;
  const pid = devicePid;
  const softwareVersion = '253';
  const osVersion = 'MacOSX_10.14.6_x64';
  const deviceModel = 'KindBeamer';
  final body =
      "<?xml version='1.0' encoding='UTF-8'?>\n"
      '<request><parameters>'
      '<deviceType>$deviceType</deviceType>'
      '<deviceSerialNumber>$serial</deviceSerialNumber>'
      '<pid>$pid</pid>'
      '<authToken>$accessToken</authToken>'
      '<authTokenType>AccessToken</authTokenType>'
      '<softwareVersion>$softwareVersion</softwareVersion>'
      '<os_version>$osVersion</os_version>'
      '<device_model>$deviceModel</device_model>'
      '</parameters></request>';
  // Sent as bytes on purpose: handing `package:http` a string body rewrites
  // `text/xml` into `text/xml; charset=utf-8`, and this endpoint is matched
  // against what the official client sends.
  final res = await _postBytes('$_firsUrl/FirsProxy/registerDeviceWithToken', {
    'Content-Type': 'text/xml',
    'Expect': '',
    'Accept-Language': 'en-US,*',
    'User-Agent': 'Mozilla/5.0',
  }, utf8.encode(body));
  if (res.statusCode != 200) {
    throw ApiError(
      'device registration failed: HTTP ${res.statusCode}',
      res.body,
    );
  }
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(res.body);
  } on XmlException catch (e) {
    throw ApiError(
      'device registration returned malformed XML (${e.message})',
      _snippet(res.body),
    );
  }
  final info = _flattenXml(doc.rootElement);
  const required = ['device_private_key', 'adp_token', 'device_type'];
  final missing = required.where((k) => (info[k] ?? '').isEmpty).toList();
  if (missing.isNotEmpty) {
    throw ApiError(
      'device registration returned no credentials '
      '(missing ${missing.join(', ')}; got ${info.keys.join(', ')})',
      _snippet(res.body),
    );
  }
  return DeviceInfo.fromMap(info);
}

Future<Map<String, dynamic>> _request(
  String path,
  AdpSigner signer,
  Map<String, dynamic> body,
) async {
  final data = const JsonEncoder.withIndent(
    '    ',
  ).convert({'ClientInfo': _clientInfo(), ...body});
  final res = await http.post(
    Uri.parse(_stkUrl + path),
    headers: {
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate',
      'Content-Type': 'application/json',
      'X-ADP-Request-Digest': signer.digestHeaderForRequest('POST', path, data),
      'X-ADP-Authentication-Token': signer.adpToken,
      ..._commonHeaders,
    },
    body: data,
  );
  if (res.statusCode != 200) {
    throw ApiError('HTTP ${res.statusCode} for $path', res.body);
  }
  return json.decode(res.body) as Map<String, dynamic>;
}

Future<List<OwnedDevice>> getOwnedDevices(AdpSigner signer) async {
  final res = await _request('/GetListOfOwnedDevices', signer, {});
  final devices = (res['ownedDevices'] as List? ?? [])
      .cast<Map<String, dynamic>>()
      .map(OwnedDevice.fromMap)
      .toList();
  return OwnedDevice.dedupe(devices);
}

Future<UploadUrlResponse> getUploadUrl(AdpSigner signer, int fileSize) async {
  final res = await _request('/GetUploadUrl', signer, {'fileSize': fileSize});
  return UploadUrlResponse.fromMap(res);
}

/// Streams [file] to the presigned S3 URL, reporting bytes written so the UI can
/// show progress for large books.
Future<void> uploadFile(
  String url,
  File file, {
  required int length,
  void Function(int sent, int total)? onProgress,
}) async {
  final client = http.Client();
  try {
    final request = http.StreamedRequest('PUT', Uri.parse(url))
      ..contentLength = length
      ..headers.addAll({'Accept-Encoding': 'gzip, deflate', ..._commonHeaders});
    var sent = 0;
    final body = file.openRead().map((chunk) {
      sent += chunk.length;
      onProgress?.call(sent, length);
      return chunk;
    });
    // Feeding through `addStream` keeps the socket in charge of the pace, so a
    // large file never has to sit in memory in one piece.
    unawaited(request.sink.addStream(body).whenComplete(request.sink.close));
    final res = await client.send(request);
    final resBody = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      throw ApiError('upload failed: HTTP ${res.statusCode}', resBody);
    }
  } finally {
    client.close();
  }
}

Future<SendToKindleResponse> sendToKindle(
  AdpSigner signer, {
  required String stkToken,
  required List<String> targetDeviceSerialNumbers,
  required String author,
  required String title,
  required String format,
  required bool archive,
}) async {
  final res = await _request('/SendToKindle', signer, {
    'DocumentMetadata': {
      'author': author,
      'crc32': 0,
      'inputFormat': format,
      'title': title,
    },
    'archive': archive,
    'deliveryMechanism': 'WIFI',
    'outputFormat': 'MOBI',
    'stkToken': stkToken,
    'targetDevices': targetDeviceSerialNumbers,
  });
  return SendToKindleResponse.fromMap(res);
}

Future<void> logout(AdpSigner signer) async {
  const path = '/FirsProxy/disownFiona?contentDeleted=false';
  final res = await http.get(
    Uri.parse(_firsUrl + path),
    headers: {
      'Content-Type': 'text/xml',
      'X-ADP-Request-Digest': signer.digestHeaderForRequest('GET', path, ''),
      'X-ADP-Authentication-Token': signer.adpToken,
      ..._commonHeaders,
    },
  );
  if (res.statusCode != 200) {
    throw ApiError('logout failed: HTTP ${res.statusCode}', res.body);
  }
}
