import 'package:flutter/material.dart';

import '../support/support_controller.dart';
import '../support/support_copy.dart';
import '../support/support_strip.dart';
import 'theme.dart';

/// KindBeamer's side of the support ask.
///
/// `lib/src/support/` is a synced copy of a shared module (see AGENTS.md, "Support ask"); this file is the
/// app's own: its numbers, its placement and its look. Change copy or rules in the shared module, change
/// only the look or the numbers here.
///
/// The app never talks to a server for this. Tapping Support opens the checkout in the browser.
const kindBeamerSupport = SupportConfig(
  appId: 'kindbeamer',
  // The placement: under the delivered row. The only statistic the server keeps is sales by this string.
  ref: 'after-delivery',
  // Default trigger: 3 days of use and 3 deliveries, at most 3 asks in a lifetime.
);

/// The label's voice: well ground, hairline, square corners. Support is an outlined press button, never an
/// inverted block (that is reserved for SEND), and "Not now" is plain text.
SupportStyle kindBeamerSupportStyle(Ink0 c) => SupportStyle(
  ground: c.well,
  border: c.rule,
  ink: c.ink,
  mid: c.inkMid,
  faint: c.inkFaint,
  focus: c.ink,
  body: typed(size: 13.5, height: 1.45),
  label: press(size: 12, tracking: 1.5),
  small: typed(size: 12),
);

/// The strip with its gap above it, which exists only while the strip does.
class KindBeamerSupportStrip extends StatelessWidget {
  const KindBeamerSupportStrip({super.key, required this.controller});

  final SupportController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.visible) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SupportStrip(
            controller: controller,
            // KindBeamer is English-only, so the copy is English and the checkout follows the browser's language.
            copy: SupportCopy.forLanguage('en', 'KindBeamer'),
            style: kindBeamerSupportStyle(Ink0.of(context)),
            brightness: Theme.of(context).brightness,
          ),
        );
      },
    );
  }
}
