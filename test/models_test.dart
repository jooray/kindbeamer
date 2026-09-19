import 'package:flutter_test/flutter_test.dart';
import 'package:kindbeamer/src/amazon/models.dart';

OwnedDevice device(String name, String serial) => OwnedDevice(
  deviceCapabilities: const {},
  deviceName: name,
  deviceSerialNumber: serial,
);

void main() {
  test('devices listed twice under one serial collapse to one', () {
    final devices = OwnedDevice.dedupe([
      device('Daylight', 'AAA'),
      device('pix10f', 'BBB'),
      device('pix10f', 'BBB'),
      device('Tablet', 'CCC'),
    ]);
    expect(devices.map((d) => d.deviceSerialNumber), ['AAA', 'BBB', 'CCC']);
    expect(devices.map((d) => d.deviceName), ['Daylight', 'pix10f', 'Tablet']);
  });

  test('distinct devices sharing a name are both kept', () {
    final devices = OwnedDevice.dedupe([
      device('pix10f', 'BBB'),
      device('pix10f', 'DDD'),
    ]);
    expect(devices, hasLength(2));
  });
}
