// SYNCED COPY of support-widget/flutter/lib/support/support_copy.dart. Do not edit here:
// change the canonical file and run support-widget/flutter/sync.sh <this repo>.
// Support ask: the words. No price, no minimum, no currency: those live on the server and change without an app release.
// Canonical source: support-widget/flutter/lib/support/support_copy.dart (copied to apps by flutter/sync.sh).
// Source of the wording: support-widget/spec/ask.md section 6. Change it there first.

class SupportCopy {
  const SupportCopy({
    required this.region,
    required this.text,
    required this.yes,
    required this.later,
    required this.never,
    required this.menu,
  });

  /// Accessibility label of the whole strip.
  final String region;
  final String text;
  final String yes;
  final String later;

  /// "Don't ask again": the small link that ends the asking for good.
  final String never;

  /// The permanent entry an app keeps in a menu (settings), which opens the checkout without any ask.
  final String menu;

  static const languages = ['en', 'sk', 'cs'];

  /// Unknown languages fall back to English.
  factory SupportCopy.forLanguage(String lang, String appName) {
    switch (lang) {
      case 'sk':
        return SupportCopy(
          region: 'Podpora',
          text:
              '$appName je zadarmo a open source. Podpor ho a dostaneš e-knihu.',
          yes: 'Podporiť',
          later: 'Teraz nie',
          never: 'Už neukazovať',
          menu: 'Podporiť projekt',
        );
      case 'cs':
        return SupportCopy(
          region: 'Podpora',
          text:
              '$appName je zdarma a open source. Podpoř ho a dostaneš e-knihu.',
          yes: 'Podpořit',
          later: 'Teď ne',
          never: 'Už nezobrazovat',
          menu: 'Podpořit projekt',
        );
      default:
        return SupportCopy(
          region: 'Support',
          text:
              '$appName is free and open source. Support it and get an e-book.',
          yes: 'Support',
          later: 'Not now',
          never: "Don't ask again",
          menu: 'Support the project',
        );
    }
  }
}
