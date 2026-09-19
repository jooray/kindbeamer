import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
  return json.decode(res.body)['access_token'] as String;
}

/// A per-installation device serial. The official clients ship one serial per
/// install; reusing a single hard-coded value would make two installs on the
/// same account fight over one entry in the device list.
String generateDeviceSerial() {
  const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final rnd = Random.secure();
  return List.generate(
    32,
    (_) => alphabet[rnd.nextInt(alphabet.length)],
  ).join();
}

Future<DeviceInfo> registerDeviceWithToken(
  String accessToken, {
  required String deviceSerial,
}) async {
  const deviceType = 'A1K6D1WRW0MALS';
  final serial = deviceSerial;
  const pid = 'D21NN3GG';
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
  final res = await http.post(
    Uri.parse('$_firsUrl/FirsProxy/registerDeviceWithToken'),
    headers: {
      'Content-Type': 'text/xml',
      'Expect': '',
      'Accept-Language': 'en-US,*',
      'User-Agent': 'Mozilla/5.0',
    },
    body: body,
  );
  if (res.statusCode != 200) {
    throw ApiError(
      'device registration failed: HTTP ${res.statusCode}',
      res.body,
    );
  }
  final doc = XmlDocument.parse(res.body);
  final info = <String, String>{};
  for (final el in doc.rootElement.children.whereType<XmlElement>()) {
    info[el.name.local] = el.innerText;
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
  return devices;
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
