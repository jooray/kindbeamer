// A screenshot harness: the real app, real window and real fonts, driven by a
// stand-in account so a capture never depends on — or exposes — a real Amazon
// session. Every device name and document below is invented for the picture.
//
//   flutter build macos --debug -t tool/demo_main.dart
//   build/macos/Build/Products/Debug/KindBeamer.app/Contents/MacOS/KindBeamer \
//     <scene> [night]
//
// Scenes: empty · signedout · ready · queue · sending · delivered · error ·
//         drop · keys · settings · rejected · offline
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:kindbeamer/src/amazon/models.dart';
import 'package:kindbeamer/src/state/app_state.dart';
import 'package:kindbeamer/src/state/credentials_store.dart';
import 'package:kindbeamer/src/ui/home_page.dart';
import 'package:kindbeamer/src/ui/theme.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fake_client.dart';

final GlobalKey _frame = GlobalKey();

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  const defined = String.fromEnvironment('SCENE');
  final scene = args.isNotEmpty
      ? args.first
      : (defined.isEmpty ? 'ready' : defined);
  const appearance = String.fromEnvironment('APPEARANCE');
  final night = args.contains('night') || appearance == 'night';
  // On a phone the system setting is what a screenshot pass flips.
  final follow = args.contains('auto') || appearance == 'auto';
  // macOS denies this process the screen-recording right, so the harness
  // captures its own frame when it is told where to put it.
  final out = args
      .where((a) => a.startsWith('out='))
      .map((a) => a.substring(4))
      .firstOrNull;
  final size = args
      .where((a) => a.startsWith('size='))
      .map((a) => a.substring(5).split('x'))
      .map((p) => Size(double.parse(p[0]), double.parse(p[1])))
      .firstOrNull;

  final support = Directory.systemTemp.createTempSync('kindbeamer_demo');
  final state = AppState(
    supportDir: support,
    store: CredentialsStore(support),
    client: scene == 'signedout'
        ? null
        : FakeStkClient(
            listFailure: scene == 'rejected'
                ? ApiError(
                    'HTTP 403 for /GetListOfOwnedDevices',
                    '{"Message":"Failed to validate DeviceInfoToken."}',
                    403,
                  )
                : scene == 'offline'
                ? const SocketException(
                    'Failed host lookup: stkservice.amazon.com',
                  )
                : null,
            devices: [
              device('Juraj’s Paperwhite', 'S0'),
              device('Kindle Scribe', 'S1'),
              device('Kindle for Mac', 'S2'),
              device('Kindle Oasis', 'S3'),
              device('Kindle for Android', 'S4'),
              device('Reading room Kindle', 'S5'),
              device('Kindle for iPhone', 'S6'),
            ],
          ),
  );
  state.appearance = night ? Appearance.night : Appearance.paper;
  if (scene != 'signedout') {
    await state.refreshDevices();
    state.selectedSerials = {'S0', 'S1', 'S4'};
  }

  File doc(String name, int kb) {
    final f = File('${support.path}/$name')
      ..writeAsBytesSync(List.filled(kb * 1024, 0x42));
    return f;
  }

  if (scene == 'signedout') {
    state.addFiles([doc('river-of-gods.epub', 2410).path]);
  } else if (scene == 'queue') {
    state.addFiles([
      doc('the-selfish-gene.pdf', 4310).path,
      doc('river-of-gods.epub', 2410).path,
      doc('field-notes-2026.md', 38).path,
    ]);
  } else if (scene == 'sending') {
    state.addFiles([doc('the-selfish-gene.pdf', 4310).path]);
    state.phase = SendPhase.sending;
    state.progress = 0.62;
    state.statusMessage = 'Sending the-selfish-gene.pdf (1 of 1) — 62%';
  } else if (scene == 'delivered') {
    state.phase = SendPhase.done;
    state.progress = 1;
    state.statusMessage = '1 document delivered to 3 devices.';
    state.closeOnSuccess = false;
  } else if (scene == 'error') {
    state.addFiles([doc('the-selfish-gene.pdf', 4310).path]);
    state.phase = SendPhase.error;
    state.statusMessage =
        'Failed: SocketException: Connection reset by peer (uploading)';
  } else if (scene != 'empty' &&
      scene != 'keys' &&
      scene != 'rejected' &&
      scene != 'offline') {
    state.addFiles([doc('the-selfish-gene.pdf', 4310).path]);
  }

  // window_manager is desktop-only; on a phone the app owns the whole screen.
  final desktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
  if (desktop) {
    await windowManager.ensureInitialized();
    final options = WindowOptions(
      size: size ?? const Size(720, 585),
      minimumSize: const Size(460, 430),
      title: 'KindBeamer',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    RepaintBoundary(
      key: _frame,
      child: MaterialApp(
        title: 'KindBeamer',
        debugShowCheckedModeBanner: false,
        theme: einkTheme(Brightness.light),
        darkTheme: einkTheme(Brightness.dark),
        themeMode: night
            ? ThemeMode.dark
            : follow
            ? ThemeMode.system
            : ThemeMode.light,
        home: HomePage(
          state: state,
          onRequestClose: () async {},
          // The capture wants the label behind the pairing flow, not the
          // webview the real app opens here.
          onPair: () async {},
          openOverlay: const {'drop', 'keys', 'settings'}.contains(scene)
              ? scene
              : null,
        ),
      ),
    ),
  );

  if (out != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Long enough for the bundled faces to land and the postmark to settle.
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      final boundary =
          _frame.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      // The macOS bundle is sandboxed, so it can only write inside its own
      // container; the caller copies the file out.
      final file = File('${Directory.systemTemp.path}/$out')
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
      stdout.writeln('CAPTURE: ${file.path}');
      exit(0);
    });
  }
}
