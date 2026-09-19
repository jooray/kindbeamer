import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import '../amazon/client.dart';

const _storageKey = 'stk_next_client';

class CredentialsStore {
  CredentialsStore(this.supportDir);

  final Directory supportDir;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  File get _fallback => File(p.join(supportDir.path, 'credentials.json'));

  Future<StkClient?> load() async {
    String? raw;
    try {
      raw = await _secure.read(key: _storageKey);
    } catch (_) {
      raw = null;
    }
    if (raw == null && await _fallback.exists()) {
      try {
        raw = await _fallback.readAsString();
      } catch (_) {
        raw = null;
      }
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      return StkClient.fromMap(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(StkClient client) async {
    final raw = json.encode(client.toMap());
    try {
      await _secure.write(key: _storageKey, value: raw);
    } catch (_) {
      await supportDir.create(recursive: true);
      await _fallback.writeAsString(raw, flush: true);
    }
  }

  Future<void> clear() async {
    try {
      await _secure.delete(key: _storageKey);
    } catch (_) {}
    if (await _fallback.exists()) {
      try {
        await _fallback.delete();
      } catch (_) {}
    }
  }
}
