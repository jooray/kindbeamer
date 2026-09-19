import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'api.dart' as api;
import 'device_id.dart';
import 'models.dart';

class OAuth2 {
  OAuth2() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    _verifier = _base64UrlEncode(bytes);
  }

  late final String _verifier;

  String get signinUrl {
    final challenge = _base64UrlEncode(
      sha256.convert(utf8.encode(_verifier)).bytes,
    );
    final q = {
      'openid.claimed_id': 'http://specs.openid.net/auth/2.0/identifier_select',
      'openid.ns.oa2': 'http://www.amazon.com/ap/ext/oauth/2',
      'openid.ns': 'http://specs.openid.net/auth/2.0',
      'openid.identity': 'http://specs.openid.net/auth/2.0/identifier_select',
      'openid.oa2.client_id': 'device:${api.clientIdPublic}',
      'openid.mode': 'checkid_setup',
      'openid.oa2.scope': 'device_auth_access',
      'openid.oa2.response_type': 'code',
      'openid.oa2.code_challenge': challenge,
      'openid.oa2.code_challenge_method': 'S256',
      'openid.return_to': 'https://www.amazon.com/sendtokindle/maplanding',
      'openid.ns.pape': 'http://specs.openid.net/extensions/pape/1.0',
      'openid.pape.max_auth_age': '0',
      'accountStatusPolicy': 'P1',
      'openid.assoc_handle': 'amzn_device_na',
      'pageId': 'amzn_device_common_dark',
      'disableLoginPrepopulate': '1',
    };
    final qs = q.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    return 'https://www.amazon.com/ap/signin?$qs';
  }

  Future<DeviceInfo> complete(
    String redirectUrl, {
    required DeviceId device,
  }) async {
    final code = parseAuthorizationCode(redirectUrl);
    final token = await api.tokenExchange(code, _verifier);
    return api.registerDeviceWithToken(token, device: device);
  }

  static bool isRedirectUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final code = uri.queryParameters['openid.oa2.authorization_code'];
    if (code == null || code.isEmpty) return false;
    if (uri.scheme == 'sendtokindle') return true;
    return uri.host == 'www.amazon.com' &&
        (uri.path.startsWith('/sendtokindle/maplanding') ||
            uri.path.startsWith('/gp/sendtokindle'));
  }

  static String parseAuthorizationCode(String redirectUrl) {
    final uri = Uri.parse(redirectUrl);
    final code = uri.queryParameters['openid.oa2.authorization_code'];
    if (code == null || code.isEmpty) {
      throw FormatException('no authorization code in redirect url');
    }
    return code;
  }

  static String _base64UrlEncode(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}
