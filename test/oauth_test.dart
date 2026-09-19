import 'package:flutter_test/flutter_test.dart';
import 'package:send_to_kindle_next/src/amazon/oauth.dart';

void main() {
  test('parses authorization code from amazon redirect', () {
    const url = 'https://www.amazon.com/gp/sendtokindle'
        '?openid.assoc_handle=amzn_device_na'
        '&openid.oa2.authorization_code=ANTMNkABICRQwomAuQbjuZMn&';
    expect(OAuth2.parseAuthorizationCode(url), 'ANTMNkABICRQwomAuQbjuZMn');
  });

  test('rejects urls without a code', () {
    expect(
      () => OAuth2.parseAuthorizationCode('https://www.amazon.com/gp/sendtokindle'),
      throwsFormatException,
    );
  });

  test('signin url carries pkce challenge and device client id', () {
    final oauth = OAuth2();
    final url = Uri.parse(oauth.signinUrl);
    expect(url.host, 'www.amazon.com');
    expect(url.path, '/ap/signin');
    expect(url.queryParameters['openid.oa2.code_challenge_method'], 'S256');
    expect(
      url.queryParameters['openid.oa2.code_challenge'],
      allOf(isNotNull, isNotEmpty),
    );
    expect(
      url.queryParameters['openid.oa2.client_id'],
      startsWith('device:'),
    );
    expect(
      url.queryParameters['openid.return_to'],
      'https://www.amazon.com/gp/sendtokindle',
    );
  });
}
