import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kindbeamer/src/amazon/device_id.dart';

void main() {
  // The one pair known to be accepted by the service, shipped by both reference
  // implementations. If the derivation ever stops reproducing this, it is wrong.
  const referenceSerial = 'ZYSQ37GQ5JQDAIKDZ3WYH6I74MJCVEGG';
  const referencePid = 'D21NN3GG';

  test('reproduces the reference pid from the reference serial', () {
    expect(DeviceId.pidFor(referenceSerial), referencePid);
  });

  test('pids are eight characters from the alphabet without O or 0', () {
    final rnd = Random(20260919);
    for (var i = 0; i < 200; i++) {
      final id = DeviceId.generate(rnd);
      expect(id.pid, hasLength(8));
      expect(id.pid, matches(RegExp(r'^[A-NP-Z1-9]{8}$')), reason: id.serial);
    }
  });

  test('generated serials have the shape the service accepts', () {
    final rnd = Random(7);
    for (var i = 0; i < 50; i++) {
      final id = DeviceId.generate(rnd);
      expect(DeviceId.isValidSerial(id.serial), isTrue, reason: id.serial);
      expect(id.pid, DeviceId.pidFor(id.serial), reason: 'pid follows serial');
    }
  });

  test('serials differ between installations', () {
    final serials = {for (var i = 0; i < 100; i++) DeviceId.generate().serial};
    expect(serials, hasLength(100));
  });

  test('a serial from an older build is recognised as unusable', () {
    expect(DeviceId.isValidSerial('0123456789ABCDEFGHIJKLMNOPQRSTUV'), isFalse);
    expect(DeviceId.isValidSerial('too-short'), isFalse);
    expect(DeviceId.isValidSerial(referenceSerial), isTrue);
  });

  test('the derivation is stable, not random', () {
    expect(
      DeviceId.pidFor('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'),
      DeviceId.pidFor('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'),
    );
    expect(DeviceId.forSerial(referenceSerial).pid, referencePid);
  });
}
