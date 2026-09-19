import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'models.dart';

class AdpSigner {
  AdpSigner({
    required this.modulus,
    required this.privateExponent,
    required this.adpToken,
  });

  final BigInt modulus;
  final BigInt privateExponent;
  final String adpToken;

  factory AdpSigner.fromDeviceInfo(DeviceInfo info) {
    final key = parsePkcs1Pem(info.devicePrivateKey);
    return AdpSigner(
      modulus: key.$1,
      privateExponent: key.$2,
      adpToken: info.adpToken,
    );
  }

  String digestHeaderForRequest(
    String method,
    String path,
    String postData, {
    DateTime? signingDate,
  }) {
    final date = signingDate ?? _now();
    final dateStr = _format(date);
    final sigData = utf8.encode(
      [method, path, dateStr, postData, adpToken].join('\n'),
    );
    final digest = sha256.convert(sigData).bytes;

    final padded = Uint8List(256 - digest.length);
    padded[0] = 0x01;
    for (var i = 1; i < padded.length - 1; i++) {
      padded[i] = 0xff;
    }
    padded[padded.length - 1] = 0x00;

    var m = BigInt.zero;
    for (final b in [...padded, ...digest]) {
      m = (m << 8) | BigInt.from(b);
    }
    final s = m.modPow(privateExponent, modulus);
    final sig = _intToBytes(s, 256);
    return '${base64.encode(sig)}:$dateStr';
  }

  static String _format(DateTime t) {
    final u = t.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
        'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }

  static DateTime _now() => DateTime.now().toUtc().subtract(
    Duration(milliseconds: DateTime.now().millisecond),
  );
}

Uint8List _intToBytes(BigInt v, int length) {
  final out = Uint8List(length);
  var x = v;
  for (var i = length - 1; i >= 0 && x > BigInt.zero; i--) {
    out[i] = (x & BigInt.from(0xff)).toInt();
    x = x >> 8;
  }
  return out;
}

(BigInt, BigInt) parsePkcs1Pem(String pem) {
  final lines = pem
      .split('\n')
      .where((l) => !l.startsWith('-----') && l.trim().isNotEmpty)
      .join();
  final der = base64.decode(lines);
  return _parsePkcs1Der(der);
}

(BigInt, BigInt) _parsePkcs1Der(Uint8List der) {
  var pos = 0;

  (int, int) readTL() {
    final tag = der[pos++];
    var len = der[pos++];
    if (len & 0x80 != 0) {
      final n = len & 0x7f;
      len = 0;
      for (var i = 0; i < n; i++) {
        len = (len << 8) | der[pos++];
      }
    }
    return (tag, len);
  }

  final seq = readTL();
  if (seq.$1 != 0x30) throw const FormatException('expected SEQUENCE');

  BigInt readInt() {
    final tl = readTL();
    if (tl.$1 != 0x02) throw const FormatException('expected INTEGER');
    var v = BigInt.zero;
    for (var i = 0; i < tl.$2; i++) {
      v = (v << 8) | BigInt.from(der[pos++]);
    }
    return v;
  }

  readInt(); // version
  final n = readInt();
  readInt(); // public exponent
  final d = readInt();
  return (n, d);
}
