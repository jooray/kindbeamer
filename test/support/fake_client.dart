import 'dart:io';

import 'package:kindbeamer/src/amazon/client.dart';
import 'package:kindbeamer/src/amazon/models.dart';

/// A 2048-bit test key, the same fixture `signer_test.dart` signs with. It only
/// has to parse: nothing here ever reaches the network.
const String testPem = '''
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

DeviceInfo fakeDeviceInfo() => const DeviceInfo(
  devicePrivateKey: testPem,
  adpToken: '{enc:test}',
  deviceType: 'A1K1D5WQMBQPLM',
  givenName: 'Reader',
  name: 'Reader',
  accountPool: 'Amazon',
  userDirectedId: 'amzn1.account.TEST',
  userDeviceName: 'KindBeamer (test)',
);

OwnedDevice device(String name, String serial) => OwnedDevice(
  deviceCapabilities: const {},
  deviceName: name,
  deviceSerialNumber: serial,
);

/// Stands in for the real client so a UI test can drive a whole send without a
/// network, an account, or a signature.
class FakeStkClient extends StkClient {
  FakeStkClient({this.devices = const [], this.failWith, this.listFailure})
    : super(fakeDeviceInfo());

  final List<OwnedDevice> devices;

  /// When set, every `sendFile` throws it.
  final Object? failWith;

  /// When set, the first `getOwnedDevices` throws it — a stale registration or
  /// a service that is not answering.
  Object? listFailure;

  final List<String> sent = [];
  int listCalls = 0;

  @override
  Future<List<OwnedDevice>> getOwnedDevices() async {
    listCalls++;
    final failure = listFailure;
    if (failure != null) throw failure;
    return devices;
  }

  @override
  Future<String> sendFile(
    File file,
    List<String> targetDeviceSerialNumbers, {
    required String author,
    required String title,
    required String format,
    required bool archive,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (failWith != null) throw failWith!;
    onProgress?.call(512, 1024);
    onProgress?.call(1024, 1024);
    sent.add(title);
    return 'sku-${sent.length}';
  }
}
