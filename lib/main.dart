import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'src/platform/intake.dart';
import 'src/state/app_state.dart';
import 'src/state/credentials_store.dart';
import 'src/ui/home_page.dart';
import 'src/ui/theme.dart';

bool get isDesktop =>
    Platform.isMacOS || Platform.isLinux || Platform.isWindows;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final supportDir = await getApplicationSupportDirectory();
  final state = AppState(
    supportDir: supportDir,
    store: CredentialsStore(supportDir),
  );
  await state.loadPrefs();
  await state.restoreSession();

  final initial = await Intake.initial(args);
  state.addFiles(initial);
  Intake.listen(state.addFiles);

  if (isDesktop) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1024, 860),
      minimumSize: Size(720, 560),
      title: 'Send to Kindle',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(SendToKindleNextApp(state: state));
}

class SendToKindleNextApp extends StatelessWidget {
  const SendToKindleNextApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Send to Kindle Next',
      debugShowCheckedModeBanner: false,
      theme: stkTheme(),
      home: HomePage(state: state),
    );
  }
}
