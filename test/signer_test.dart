import 'package:flutter_test/flutter_test.dart';
import 'package:kindbeamer/src/amazon/signer.dart';

const String _testPem = '''
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAiU8x9epm1I3z3IpU4mzs/g5x1X3KEHG49oV5GADyG4vS8bSIIPEKwHzr4i9X
7jySz42pfFoj3IBfzg/BOusToTWcU/NA/4PcGcysVMKUwtFW1UGeWfP5a9PK14cBHvj/ZeqRKhvd
KrHWGZu5xDhW2Zs106WcpNbpvdwFJpCjVI9CEdrhw5laaIrbKbNJEoEeogEsN8wjAGXVP3oNN6FD
QsHZPHLBhFplrqyw8XAoXeH7b2gh6vugOrRq4oRgG1slS/hNBYJaytdrbxtrsKfb/qd4FWynbLFb
hIHqSnurB3GYReSZgiFWdxKkncdsI4Zy/RUjbMaHr0WQZnxC98vE4wIDAQABAoIBAGbxVvWVjQ6i
dkfL9iPjojI+xh1XN1zoxdEc9FKIsvrv83B+9ugrjvINNhPXhsb35uFwxbaTJfu0yx8ENMxlXcwp
E1DlOL/YLfWxuym40CrXI5Cyp3OtNDwhBxxa/P4pk+Dm4Xp+dWwC9A8y7y0rSAHRGaPZr/ztm0Ra
Zgopuio0Ow1W68BHfOZx7Seaxf+WmSNrYQD5uaP7rPVLzE3troxn19V0cUCeZzOUstkoRZgq5vH7
N9hYXvYHOc/J42b2GY44VV2iEFTJdajorcQqonneqrfi6g1NXaHYMC1XmycKfWijaDVVeH5Stdxt
lbXMJ5b2BtILcyRceZwUL1KRQHECgYEAzMsjVTnRx/+yfhRC/X/pcz5C31uQo/u/dYDgUGfxaYz1
lIpUX4BO6xQ6mv9lmwEFy4DyiERvZN1avKbl0LHj60CeeoCGxdHWnqn1CDEidZI9sCI1Jh4lVYY+
HyoYqAbv6wU/xBtlbast5G6R6OboQPCQ9aDOYQGZbjoLqKyNbH0CgYEAq6RjCH53hqqAFVdWkbCv
B0cAP8/estSQHGb92WVl53mjcIx/0jUl3/v4sf4yMr5yAdOgMzWGrm+bJJVctPva8rQ8eFHnjc8y
fiqfc0ffpgcJa3ckXO2Ds/egvnp+aj6n+ukWNDv4VAY4nSJnt8JdlM70QJhNnRuxoA+A1J0KlN8C
gYAkAfeVbZQgCSpWFrPspIfkdmcFpLDa1FHGlEFcgdolh95KHsRVAldd5/Gh/RPdXCGrtWFvajD3
2B+zGdlAh3aej38N5PlNYObOgO2PYiw/5dWo2Wrk59oCnpbfneQ17vpSJVsf3P1JehaYmoRXIfpm
KKYkOgDvd3uFsPkJ0EURdQKBgQCFM0Yzckl5tVk+to+U8mNyJ1R3MO7nIvRPRlHbYsgpUYlXr4EG
dX5WCymdn+H+5TJ+XmflNbW2KyBfzJWsUgNA9EQ1L4Kd11yc8qDZCr7yDmXuAwCyKRRbFmGlUFRI
SSV9H2O+14dIVaebsfaBcZHECLMeadNZiANZbo6Q8OokSwKBgB+Wc2Zv4opY4aKznAoyfLHOLLPX
rSR0zN2M5O99+JEwXCRWaK+LWM5FHAS72u6TDs44NKbsyUCqGU7mJIP+qEb7aW8PceGKOzmHNS1U
i5NQbpOI94zm8WfCCr0KQ46M8ZTAJzjEcOH38/8c485sPnfa+Mh+/p5W1DsLaiIpCU5b
-----END RSA PRIVATE KEY-----
''';

// Produced with stkclient's own padding constant (0x01 + 0xFF*221 + 0x00, a
// 255-byte block for a 2048-bit key) rather than a vector of our own making —
// an earlier vector was generated from this implementation and so agreed with
// its off-by-one, which the service rejected with "Couldn't decrypt the
// request's signature using the device info's public key".
const String _expectedHeader =
    'XIcrlEfeMChuBDGMIn5KM2Ba4OkOeVPuFUdsCDs5A6Ux+ne3H0aDZMAzG0T6V+2pWBQ3YcEndTd7FowluWsrD50JIhEHyeCuaOvPlt1qaFLL700HLa1kJJaFdoCXQb+niUZ8WwZp4wVhqLzjx3rzWBmb33864cy/xUTM/4bToFdPZ+Zg3q3LHbGnM6mIXD8jGsor/mVYrSrM0OK4KQ6E3ysrefBZJHCcUwMFnByUSCV1tXVAsSkqgrQGJsAeABRaAWmKRq5OXhL5Xt8bR22KE0DLSoS0AWTHOiTNub96wWfxk+CLBX+c4YYktMGsOICTOggI7l7vMnbpWbBDZzdPpQ==:2024-05-01T12:34:56Z';

void main() {
  test('parses PKCS#1 PEM private key', () {
    final key = parsePkcs1Pem(_testPem);
    expect(key.$1.bitLength, greaterThanOrEqualTo(2047));
    expect(key.$2, greaterThan(BigInt.zero));
  });

  test('digest header matches reference implementation vector', () {
    final key = parsePkcs1Pem(_testPem);
    final signer = AdpSigner(
      modulus: key.$1,
      privateExponent: key.$2,
      adpToken: 'AdpTokenTest==',
    );
    final header = signer.digestHeaderForRequest(
      'POST',
      '/GetUploadUrl',
      '{"fileSize": 1234}',
      signingDate: DateTime.utc(2024, 5, 1, 12, 34, 56),
    );
    expect(header, _expectedHeader);
  });

  test('digest header format is base64:iso8601', () {
    final key = parsePkcs1Pem(_testPem);
    final signer = AdpSigner(
      modulus: key.$1,
      privateExponent: key.$2,
      adpToken: 'tok',
    );
    final header = signer.digestHeaderForRequest('GET', '/x', '');
    final parts = header.split(':');
    expect(parts.length, 4);
    expect(parts[3], endsWith('Z'));
    expect(parts[0].endsWith('=='), isTrue);
  });
}
