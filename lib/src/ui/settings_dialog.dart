import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'theme.dart';

Future<void> showSettingsDialog(BuildContext context, AppState state) async {
  await showDialog<void>(
    context: context,
    builder: (_) => SettingsDialog(state: state),
  );
}

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Dialog(
        backgroundColor: StkColors.background,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(color: StkColors.textPrimary, fontSize: 18),
                ),
                const SizedBox(height: 18),
                Text(
                  state.signedIn
                      ? 'Signed in as ${state.accountName}'
                      : 'Not signed in',
                  style: const TextStyle(
                    color: StkColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (state.signedIn) ...[
                      OutlinedButton(
                        onPressed: () => state.refreshDevices(),
                        child: const Text('Refresh devices'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await state.signOut();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: const Text('Sign out'),
                      ),
                    ],
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  state.credentialsBackend.description,
                  style: const TextStyle(
                    color: StkColors.textFaint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
