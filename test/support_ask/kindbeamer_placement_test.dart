// KindBeamer's own placement of the support ask (the shared module is tested by the synced *_test.dart files
// beside this one). A send starting is the moment of value: the strip appears under the contents while the
// document uploads. The window would normally close itself after a delivery; while the strip is up it waits,
// and once the strip is gone (Not now, Support, Don't ask again) it closes as it always did.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kindbeamer/src/state/app_state.dart';
import 'package:kindbeamer/src/state/credentials_store.dart';
import 'package:kindbeamer/src/support/support_controller.dart';
import 'package:kindbeamer/src/support/support_engine.dart';
import 'package:kindbeamer/src/support/support_launch.dart';
import 'package:kindbeamer/src/support/support_store.dart';
import 'package:kindbeamer/src/ui/home_page.dart';
import 'package:kindbeamer/src/ui/support_ask.dart';

import '../support/fake_client.dart';

class _Launcher implements SupportLauncher {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

void main() {
  late Directory tmp;
  late AppState state;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('stk_support');
  });

  tearDown(() async {
    for (var attempt = 0; ; attempt++) {
      try {
        await tmp.delete(recursive: true);
        return;
      } on FileSystemException {
        if (attempt == 4) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  /// Opens the label, queues a document and presses Enter: the send starts, uploads and is delivered.
  Future<void> send(
    WidgetTester tester,
    SupportController support, {
    required void Function() onClose,
  }) async {
    final client = FakeStkClient(devices: [device('Kindle', 'SERIAL0')]);
    state = AppState(
      supportDir: tmp,
      store: CredentialsStore(tmp),
      client: client,
    );
    await tester.runAsync(() async {
      await state.loadPrefs();
      await state.refreshDevices();
    });
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          state: state,
          support: support,
          onRequestClose: () async => onClose(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final file = File('${tmp.path}/doc.pdf')
      ..writeAsBytesSync(List.filled(4096, 0x42));
    state.addFiles([file.path]);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('1 document delivered to 1 device.'), findsOneWidget);
  }

  const askText =
      'KindBeamer is free and open source. Support it and get an e-book.';

  SupportController due({_Launcher? launcher, SupportState? from}) =>
      SupportController(
        config: kindBeamerSupport,
        // Three days of use and two sends already: this send is the third.
        store: MemorySupportStore(
          from ??
              const SupportState(
                activeDays: 3,
                lastActiveDay: '2026-11-01',
                actions: 2,
              ),
        ),
        launcher: launcher ?? _Launcher(),
      );

  testWidgets(
    'a reader who has used it enough sees the ask while it uploads, and the window waits',
    (tester) async {
      final support = due();
      var closes = 0;
      await send(tester, support, onClose: () => closes++);

      expect(find.text(askText), findsOneWidget);
      expect(
        find.textContaining('€'),
        findsNothing,
        reason: 'no price in the app',
      );
      expect(find.text("Don't ask again"), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(closes, 0, reason: 'the window waits for the ask');
    },
  );

  testWidgets('Not now, and the window closes as it always did', (
    tester,
  ) async {
    final support = due();
    var closes = 0;
    await send(tester, support, onClose: () => closes++);
    await tester.tap(find.text('NOT NOW'));
    await tester.pump();
    expect(find.text(askText), findsNothing);
    expect(support.state.asks, 1);
    expect(support.state.declined, isFalse);
    expect(closes, 0, reason: 'the stamp is seen to land first');
    await tester.pump(const Duration(seconds: 2));
    expect(closes, 1);
  });

  testWidgets(
    "Don't ask again works as before: it closes, and never asks again",
    (tester) async {
      final support = due();
      var closes = 0;
      await send(tester, support, onClose: () => closes++);
      await tester.tap(find.text("Don't ask again"));
      await tester.pump();
      expect(support.state.declined, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(closes, 1);
      expect(
        await support.evaluate(momentOfValue: true),
        isFalse,
        reason: 'nothing is ever shown again',
      );
    },
  );

  testWidgets('Support opens the checkout, and the window closes after it', (
    tester,
  ) async {
    final launcher = _Launcher();
    final support = due(launcher: launcher);
    var closes = 0;
    await send(tester, support, onClose: () => closes++);
    await tester.tap(find.text('SUPPORT'));
    await tester.pump();
    await tester.pump();
    expect(
      launcher.opened.single.toString(),
      'https://hackyourself.io/support/s/kindbeamer?theme=light&ref=after-delivery',
    );
    await tester.pump(const Duration(seconds: 2));
    expect(closes, 1);
  });

  testWidgets('a new reader sees nothing and the window closes as before', (
    tester,
  ) async {
    final support = SupportController(
      config: kindBeamerSupport,
      store: MemorySupportStore(),
      launcher: _Launcher(),
    );
    var closes = 0;
    await send(tester, support, onClose: () => closes++);

    expect(find.text(askText), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(closes, 1);
  });

  testWidgets(
    'Settings keeps a Support entry that still works after "don\'t ask again"',
    (tester) async {
      final launcher = _Launcher();
      final support = due(
        launcher: launcher,
        from: const SupportState(declined: true),
      );
      state = AppState(supportDir: tmp, store: CredentialsStore(tmp));
      await tester.runAsync(() => state.loadPrefs());
      tester.view.physicalSize = const Size(1024, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(state: state, support: support),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('SETTINGS'));
      await tester.pumpAndSettle();
      final entry = find.text('SUPPORT THE PROJECT');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pump();
      await tester.pump();
      expect(
        launcher.opened.single.toString(),
        'https://hackyourself.io/support/s/kindbeamer?theme=light&ref=menu',
      );
      expect(
        support.state.declined,
        isTrue,
        reason: 'opening it is not an ask',
      );
    },
  );
}
