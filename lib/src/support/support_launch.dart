// SYNCED COPY of support-widget/flutter/lib/support/support_launch.dart. Do not edit here:
// change the canonical file and run support-widget/flutter/sync.sh <this repo>.
// Support ask: the URL contract and how it is opened.
// Canonical source: support-widget/flutter/lib/support/support_launch.dart (copied to apps by flutter/sync.sh).
// Contract: support-widget/spec/ask.md section 5. Nothing but the five parameters below, ever:
// no user id, no key, no device id, no version, no referrer.

import 'package:url_launcher/url_launcher.dart';

const supportBaseUrl = 'https://hackyourself.io/support';

/// [lang] is left out by apps that are not localized: the checkout then follows the browser's language.
Uri supportUri({
  required String appId,
  required String ref,
  required bool dark,
  String? lang,
  String? book,
  String baseUrl = supportBaseUrl,
}) {
  return Uri.parse('$baseUrl/s/$appId').replace(
    queryParameters: {
      'lang': ?lang,
      'theme': dark ? 'dark' : 'light',
      'ref': ref,
      'book': ?book,
    },
  );
}

abstract interface class SupportLauncher {
  /// Opens the checkout in the system browser. Returns whether it could.
  Future<bool> open(Uri uri);
}

/// Never a WebView: Apple Pay, Google Pay and Link do not work there.
class SystemSupportLauncher implements SupportLauncher {
  const SystemSupportLauncher();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
