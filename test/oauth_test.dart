import 'package:flutter_test/flutter_test.dart';
import 'package:kindbeamer/src/amazon/oauth.dart';

void main() {
  test('parses authorization code from amazon redirect', () {
    const url =
        'https://www.amazon.com/sendtokindle/maplanding'
        '?openid.assoc_handle=amzn_device_na'
        '&openid.oa2.authorization_code=ANTMNkABICRQwomAuQbjuZMn&';
    expect(OAuth2.parseAuthorizationCode(url), 'ANTMNkABICRQwomAuQbjuZMn');
    expect(OAuth2.isRedirectUrl(url), isTrue);
    expect(
      OAuth2.isRedirectUrl(
        'sendtokindle://www.amazon.com/sendtokindle/'
        'maplanding?openid.oa2.authorization_code=ABC123',
      ),
      isTrue,
    );
    expect(
      OAuth2.isRedirectUrl('https://www.amazon.com/gp/sendtokindle'),
      isFalse,
    );
  });

  test('rejects urls without a code', () {
    expect(
      () => OAuth2.parseAuthorizationCode(
        'https://www.amazon.com/sendtokindle/maplanding',
      ),
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
    expect(url.queryParameters['openid.oa2.client_id'], startsWith('device:'));
    expect(
      url.queryParameters['openid.return_to'],
      'https://www.amazon.com/sendtokindle/maplanding',
    );
  });
}
