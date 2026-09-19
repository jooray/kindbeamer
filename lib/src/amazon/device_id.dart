import 'dart:convert';
import 'dart:math';

/// Serial and pid of the registered device.
///
/// Registration takes a `deviceSerialNumber` and a `pid`, and refuses the pair
/// unless the pid matches the serial — a generated serial sent with the
/// reference pid answers `<error><message>Internal Error</message></error>`,
/// which is why both reference implementations of this protocol ship one fixed
/// pair and one registration per account.
///
/// The pid turns out to be the Mobipocket PID derivation applied to the serial:
/// CRC-32 folded over the serial's bytes, eight characters from a 34-letter
/// alphabet with `O` and `0` left out. Checked both ways — it reproduces the
/// reference pid `D21NN3GG` from the reference serial, and the service accepts
/// the pairs it mints — so KindBeamer can register a serial of its own per
/// installation, and two machines can hold their own registration at once.
class DeviceId {
  const DeviceId(this.serial, this.pid);

  final String serial;
  final String pid;

  /// Serials are unpadded base32 of 20 random bytes: 32 characters over A-Z2-7.
  /// The reference serial has exactly this shape, and nothing outside it has
  /// been seen to work.
  static const String _serialAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  static final RegExp _serialPattern = RegExp(r'^[A-Z2-7]{32}$');

  /// The Mobipocket PID alphabet: no `O` and no `0`, so the two are never
  /// confused by eye.
  static const String _pidAlphabet = 'ABCDEFGHIJKLMNPQRSTUVWXYZ123456789';

  static const int _pidLength = 8;

  static DeviceId generate([Random? random]) {
    final rnd = random ?? Random.secure();
    final serial = List.generate(
      32,
      (_) => _serialAlphabet[rnd.nextInt(_serialAlphabet.length)],
    ).join();
    return forSerial(serial);
  }

  static DeviceId forSerial(String serial) => DeviceId(serial, pidFor(serial));

  static bool isValidSerial(String serial) => _serialPattern.hasMatch(serial);

  /// The pid Amazon expects for [serial].
  static String pidFor(String serial) {
    final bytes = ascii.encode(serial);
    final crc = _crc32(bytes);
    final folded = List<int>.filled(_pidLength, 0);
    for (var i = 0; i < bytes.length; i++) {
      folded[i % _pidLength] ^= bytes[i];
    }
    final crcBytes = [
      (crc >> 24) & 0xff,
      (crc >> 16) & 0xff,
      (crc >> 8) & 0xff,
      crc & 0xff,
    ];
    final out = StringBuffer();
    for (var i = 0; i < _pidLength; i++) {
      final b = (folded[i] ^ crcBytes[i & 3]) & 0xff;
      out.write(_pidAlphabet[(b >> 7) + ((b >> 5 & 3) ^ (b & 0x1f))]);
    }
    return out.toString();
  }

  /// CRC-32 (the usual 0xEDB88320 table) with neither the initial nor the final
  /// inversion — the raw running value, which is what this derivation folds in.
  static int _crc32(List<int> data) {
    var crc = 0;
    for (final byte in data) {
      crc = _table[(crc ^ byte) & 0xff] ^ (crc >> 8);
    }
    return crc & 0xFFFFFFFF;
  }

  static final List<int> _table = List<int>.generate(256, (i) {
    var c = i;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  }, growable: false);
}
