import 'package:flutter_test/flutter_test.dart';
import 'package:kindbeamer/src/amazon/api.dart';

void main() {
  Map<String, dynamic> body({bool? forceConvert}) => sendToKindleBody(
    stkToken: 'tok',
    targetDeviceSerialNumbers: ['S1'],
    author: 'A',
    title: 'T',
    format: 'PDF',
    archive: true,
    forceConvert: forceConvert,
  );

  // Checked on a Kindle for Android: the stkclient body reflowed a PDF, the
  // official client's body with forceConvert false kept its pages, and true
  // reflowed it again.
  test('without a layout choice it is the stkclient body', () {
    final b = body();
    expect(b['outputFormat'], 'MOBI');
    expect(b['deliveryMechanism'], 'WIFI');
    expect(b.containsKey('forceConvert'), isFalse);
  });

  test('a PDF body asks for its layout the way the official client does', () {
    for (final convert in [false, true]) {
      final b = body(forceConvert: convert);
      expect(b['forceConvert'], convert);
      expect(b.containsKey('outputFormat'), isFalse);
      expect(b.containsKey('deliveryMechanism'), isFalse);
      expect(b['stkToken'], 'tok');
      expect(b['targetDevices'], ['S1']);
      expect((b['DocumentMetadata'] as Map)['inputFormat'], 'PDF');
    }
  });
}
