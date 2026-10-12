import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'src/platform/auto_send.dart';
import 'src/platform/intake.dart';
import 'src/state/app_state.dart';
import 'src/state/credentials_store.dart';
import 'src/ui/home_page.dart';
import 'src/ui/theme.dart';

bool get isDesktop =>
    Platform.isMacOS || Platform.isLinux || Platform.isWindows;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  SendRequest? request;
  try {
    request = SendRequest.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('KindBeamer: error: ${e.message}\n${SendRequest.usage}');
    exit(SendRequest.badUsage);
  }

  final supportDir = await getApplicationSupportDirectory();
  final state = AppState(
    supportDir: supportDir,
    store: CredentialsStore(supportDir),
  );
  await state.loadPrefs();
  await state.restoreSession();

  final initial = await Intake.initial(request?.paths ?? args);
  state.addFiles(initial);
  Intake.listen(state.addFiles);

  if (request != null) {
    // No window to answer: send, say how it went, and leave with a status a
    // script can test.
    final code = await request.run(
      state,
      awaitFiles: () => _filesArrive(state, const Duration(seconds: 5)),
    );
    await stdout.flush();
    await stderr.flush();
    exit(code);
  }

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

/// Android: the print service's background send. `PrintToKindleService`
/// starts a headless engine on this entry point when "send printed pages right
/// away" is on, asks for the job, and gets back how it went. The send itself
/// is `--send`'s: the stored sign-in, the devices ticked last time, the
/// library copy and the PDF layout, with no window to answer.
@pragma('vm:entry-point')
Future<void> printSendMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.stkn.kindbeamer/print');
  final job = await channel.invokeMapMethod<String, Object?>('job');
  final path = job?['path'] as String? ?? '';
  final out = StringBuffer();
  final err = StringBuffer();
  var code = SendRequest.failed;
  try {
    final supportDir = await getApplicationSupportDirectory();
    final state = AppState(
      supportDir: supportDir,
      store: CredentialsStore(supportDir),
    );
    await state.loadPrefs();
    await state.restoreSession();
    state.addFiles([path]);
    code = await SendRequest(paths: [path]).run(
      state,
      out: out,
      err: err,
      awaitFiles: () => _filesArrive(state, const Duration(seconds: 5)),
    );
  } catch (e) {
    err.write('KindBeamer: error: $e');
  }
  String clean(StringBuffer b) {
    final t = b.toString().trim().replaceFirst(
      RegExp(r'^KindBeamer: (error: )?'),
      '',
    );
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }

  await channel.invokeMethod('done', {
    'ok': code == SendRequest.ok,
    'signIn': code == SendRequest.notSignedIn,
    'message': code == SendRequest.ok ? clean(out) : clean(err),
  });
}

/// Documents opened through Launch Services come by Apple Event, which can
/// trail the launch by a moment.
Future<void> _filesArrive(AppState state, Duration limit) async {
  final deadline = DateTime.now().add(limit);
  while (state.docs.isEmpty && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await state.refreshFromPlatform();
  }
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
