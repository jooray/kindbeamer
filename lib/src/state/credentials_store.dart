import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import '../amazon/client.dart';

enum CredentialsBackend {
  unknown,
  secureStorage,
  file;

  String get description => switch (this) {
    CredentialsBackend.secureStorage =>
      'Credentials are stored in the OS keychain / encrypted storage.',
    CredentialsBackend.file =>
      'No keychain available — credentials are stored in a file readable only '
          'by your user account.',
    CredentialsBackend.unknown =>
      'Credentials are stored locally on this device '
          '(keychain / encrypted storage where available).',
  };
}

const _storageKey = 'kindbeamer_client';

/// Key used before the app was renamed; still read so an existing session
/// survives the upgrade.
const _legacyStorageKey = 'stk_next_client';

/// Device credentials (`adp_token` + RSA private key). They are long-lived and
/// grant full Send to Kindle access to the account, so they go into the OS
/// keychain / encrypted storage; the file fallback exists only for Linux boxes
/// without a secret service and is kept owner-readable.
class CredentialsStore {
  CredentialsStore(this.supportDir);

  final Directory supportDir;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  /// Where the last save actually landed, so the UI can be honest about it.
  /// The keychain is unavailable to ad-hoc signed macOS builds and to Linux
  /// desktops without a secret service.
  CredentialsBackend backend = CredentialsBackend.unknown;

  File get _fallback => File(p.join(supportDir.path, 'credentials.json'));

  Future<String?> _readSecure(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<StkClient?> load() async {
    var raw =
        await _readSecure(_storageKey) ?? await _readSecure(_legacyStorageKey);
    backend = raw != null ? CredentialsBackend.secureStorage : backend;
    if (raw == null && await _fallback.exists()) {
      try {
        raw = await _fallback.readAsString();
        backend = CredentialsBackend.file;
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
      backend = CredentialsBackend.secureStorage;
    } catch (_) {
      await _saveFallback(raw);
      backend = CredentialsBackend.file;
    }
  }

  Future<void> _saveFallback(String raw) async {
    await supportDir.create(recursive: true);
    final file = _fallback;
    await file.writeAsString(raw, flush: true);
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['600', file.path]);
      } catch (_) {}
    }
  }

  Future<void> clear() async {
    for (final key in [_storageKey, _legacyStorageKey]) {
      try {
        await _secure.delete(key: key);
      } catch (_) {}
    }
    if (await _fallback.exists()) {
      try {
        await _fallback.delete();
      } catch (_) {}
    }
  }
}
