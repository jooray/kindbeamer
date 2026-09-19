import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the per-platform declarations that only bite in a release build.
///
/// Both of these have already shipped broken once: the macOS release
/// entitlements lacked network access, so the sign-in webview came up blank,
/// and the Android release manifest lacked INTERNET, because Flutter's template
/// declares it in the debug and profile manifests only — a debug run is online
/// and the release APK is not.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('the Android release manifest asks for network access', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    expect(
      manifest,
      contains('android.permission.INTERNET'),
      reason: 'release APK is offline without it',
    );
  });

  test('Android accepts the document types the app can send', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    for (final mime in [
      'application/pdf',
      'application/epub+zip',
      'text/markdown',
      'text/plain',
    ]) {
      expect(manifest, contains(mime), reason: '$mime share target');
    }
  });

  test('both macOS entitlements allow outgoing connections', () {
    for (final path in [
      'macos/Runner/Release.entitlements',
      'macos/Runner/DebugProfile.entitlements',
    ]) {
      final entitlements = read(path);
      expect(
        entitlements,
        contains('com.apple.security.network.client'),
        reason: '$path: webview and API calls need it',
      );
      expect(
        entitlements,
        contains('com.apple.security.files.user-selected.read-only'),
        reason: '$path: the file dialog returns unreadable files without it',
      );
    }
  });

  test('the Linux desktop entry stays in step with the app id', () {
    final desktop = read('packaging/linux/dev.stkn.kindbeamer.desktop');
    expect(desktop, contains('StartupWMClass=dev.stkn.kindbeamer'));
    expect(desktop, contains('Exec=kindbeamer %F'));
    expect(desktop, contains('text/markdown'));
  });
}
