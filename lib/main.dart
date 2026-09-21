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
    // The label is all there is, so the window is sized to it rather than to a
    // workspace: enough for the form, and no empty desk around it.
    const options = WindowOptions(
      size: Size(880, 700),
      minimumSize: Size(620, 520),
      title: 'KindBeamer',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(KindBeamerApp(state: state));
}

class KindBeamerApp extends StatelessWidget {
  const KindBeamerApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        title: 'KindBeamer',
        debugShowCheckedModeBanner: false,
        theme: einkTheme(Brightness.light),
        darkTheme: einkTheme(Brightness.dark),
        themeMode: switch (state.appearance) {
          Appearance.auto => ThemeMode.system,
          Appearance.paper => ThemeMode.light,
          Appearance.night => ThemeMode.dark,
        },
        home: HomePage(state: state),
      ),
    );
  }
}
