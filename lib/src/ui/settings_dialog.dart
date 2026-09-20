import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import 'label_parts.dart';
import 'theme.dart';

Future<void> showSettingsDialog(BuildContext context, AppState state) async {
  await showDialog<void>(
    context: context,
    builder: (_) => SettingsDialog(state: state),
  );
}

/// The back of the label: the few defaults worth keeping between sends, and
/// the plain facts about what this app is.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final ScrollController _scroll = ScrollController();

  AppState get state => widget.state;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final c = Ink0.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Dialog(
        backgroundColor: c.ground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: c.ink, width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BarredEdge(),
                // The slip scrolls between its own edges, so the bottom border
                // is never the thing that falls off a short window.
                Flexible(
                  child: Scrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'SETTINGS',
                                    style: press(
                                      size: 13,
                                      color: c.ink,
                                      weight: FontWeight.w700,
                                      tracking: 4,
                                    ),
                                  ),
                                ),
                                PressButton(
                                  label: 'CLOSE',
                                  cap: 'ESC',
                                  dense: true,
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            _group(c, 'ACCOUNT'),
                            Text(
                              state.signedIn
                                  ? 'Signed in as ${state.accountName}'
                                  : 'Not signed in.',
                              style: typed(size: 13, color: c.ink),
                            ),
                            const SizedBox(height: 10),
                            if (state.signedIn)
                              Row(
                                children: [
                                  PressButton(
                                    label: 'REFRESH DEVICES',
                                    dense: true,
                                    onPressed: state.refreshDevices,
                                  ),
                                  const SizedBox(width: 8),
                                  PressButton(
                                    label: 'SIGN OUT',
                                    dense: true,
                                    onPressed: () async {
                                      await state.signOut();
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            const SizedBox(height: 17),

                            _group(c, 'AFTER A DELIVERY'),
                            _switchRow(
                              c,
                              on: state.closeOnSuccess,
                              label:
                                  'Close the window once everything is delivered',
                              onTap: () => state.setCloseOnSuccess(
                                !state.closeOnSuccess,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'A failed send keeps it, with the reason on it.',
                              style: typed(
                                size: 11.5,
                                color: c.inkFaint,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 17),

                            _group(c, 'APPEARANCE'),
                            Row(
                              children: [
                                for (final a in Appearance.values) ...[
                                  PressButton(
                                    label: switch (a) {
                                      Appearance.auto => 'AUTO',
                                      Appearance.paper => 'PAPER',
                                      Appearance.night => 'NIGHT',
                                    },
                                    dense: true,
                                    solid: state.appearance == a,
                                    onPressed: () => state.setAppearance(a),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ],
                            ),
                            const SizedBox(height: 17),

                            _group(c, 'DEFAULTS'),
                            Text(
                              'Ticked devices and the library copy carry over. '
                              'Press ? for the key list.',
                              style: typed(
                                size: 12,
                                color: c.inkMid,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 17),

                            _group(c, 'THIS INSTALLATION'),
                            Text(
                              state.credentialsBackend.description,
                              style: typed(
                                size: 11.5,
                                color: c.inkFaint,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'KindBeamer is not affiliated with, endorsed by, or '
                              'sponsored by Amazon.',
                              style: typed(
                                size: 11.5,
                                color: c.inkFaint,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                PressButton(
                                  label: 'HELP',
                                  dense: true,
                                  onPressed: () => _open(
                                    'https://github.com/jooray/kindbeamer',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PressButton(
                                  label: 'MANAGE YOUR KINDLE',
                                  dense: true,
                                  onPressed: () => _open(
                                    'https://www.amazon.com/hz/mycd/myx',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const BarredEdge(flip: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _group(Ink0 c, String name) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(name, style: press(size: 9.5, color: c.inkMid, tracking: 1.6)),
        const SizedBox(height: 5),
        const Rule(strong: true),
      ],
    ),
  );

  Widget _switchRow(
    Ink0 c, {
    required bool on,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          children: [
            TickBox(on: on),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: typed(size: 13, color: on ? c.ink : c.inkMid),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
