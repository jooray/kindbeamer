import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kindbeamer/src/amazon/models.dart';
import 'package:kindbeamer/src/convert/markdown.dart';
import 'package:kindbeamer/src/state/app_state.dart';
import 'package:kindbeamer/src/state/documents.dart';
import 'package:kindbeamer/src/state/credentials_store.dart';
import 'package:kindbeamer/src/ui/home_page.dart';
import 'package:kindbeamer/src/ui/label_parts.dart';

import 'support/fake_client.dart';

void main() {
  late Directory tmp;
  late AppState state;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('stk_ui');
    state = AppState(supportDir: tmp, store: CredentialsStore(tmp));
    await state.loadPrefs();
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  File write(String name, int size) {
    final f = File('${tmp.path}/$name');
    f.writeAsBytesSync(List.filled(size, 0x42));
    return f;
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: HomePage(state: state)));
    await tester.pumpAndSettle();
  }

  /// A signed-in state with a fake account behind it, so a whole send can run
  /// without a network.
  Future<FakeStkClient> signIn(
    WidgetTester tester, {
    List<String> deviceNames = const ['Juraj\'s Kindle', 'Kindle Scribe'],
    Object? failWith,
  }) async {
    final client = FakeStkClient(
      devices: [
        for (var i = 0; i < deviceNames.length; i++)
          device(deviceNames[i], 'SERIAL$i'),
      ],
      failWith: failWith,
    );
    state = AppState(
      supportDir: tmp,
      store: CredentialsStore(tmp),
      client: client,
    );
    await tester.runAsync(() async {
      await state.loadPrefs();
      await state.refreshDevices();
    });
    return client;
  }

  testWidgets('the label prints its sections and takes drops', (tester) async {
    await pump(tester);
    expect(find.byType(DropTarget), findsOneWidget);
    expect(find.text('CONTENTS'), findsOneWidget);
    expect(find.text('DESCRIPTION'), findsOneWidget);
    expect(find.text('DELIVER TO'), findsOneWidget);
    expect(find.text('Nothing to send yet.'), findsOneWidget);
  });

  testWidgets('a dropped markdown file reports its conversion', (tester) async {
    final converted = File('${tmp.path}/notes.html')
      ..writeAsStringSync('<p>x</p>');
    final gate = Completer<ConvertedDoc>();
    state = AppState(
      supportDir: tmp,
      store: CredentialsStore(tmp),
      convertMarkdown: (_, _) => gate.future,
    );
    // loadPrefs touches the filesystem, so it needs the real event loop too.
    await tester.runAsync(() => state.loadPrefs());
    await pump(tester);

    final md = File('${tmp.path}/notes.md')..writeAsStringSync('# Hello');
    state.addFiles([md.path]);
    await tester.pump();
    expect(find.textContaining('Converting notes.md'), findsOneWidget);

    // The state layer stats the converted file, which is real I/O: it only
    // completes if the test lets the real event loop run.
    await tester.runAsync(() async {
      gate.complete(
        ConvertedDoc(
          path: converted.path,
          format: DocFormat.forExtension('html')!,
          note: 'converted to HTML',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.text('converted to HTML'), findsOneWidget);
    expect(find.text('HTML'), findsOneWidget, reason: 'the row says what goes');
  });

  testWidgets('clear empties the queue, then closes the window', (
    tester,
  ) async {
    var closeRequests = 0;
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          state: state,
          onRequestClose: () async => closeRequests++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    state.addFiles([write('queued.pdf', 16).path]);
    await tester.pumpAndSettle();
    expect(state.docs, hasLength(1));

    await tester.tap(find.text('CLEAR'));
    await tester.pumpAndSettle();
    expect(state.docs, isEmpty, reason: 'first press clears the queue');
    expect(closeRequests, 0, reason: 'and does not close the window');

    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();
    expect(closeRequests, 1, reason: 'with nothing queued, it closes');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(closeRequests, 2, reason: 'escape does the same thing');
  });

  testWidgets('documents are listed and the franking line counts them', (
    tester,
  ) async {
    final pdf = write('bluehat.pdf', 2 * 1024 * 1024);
    final epub = write('novel.epub', 1024 * 1024);

    await pump(tester);
    state.addFiles([pdf.path, epub.path]);
    await tester.pumpAndSettle();

    expect(find.text('bluehat.pdf'), findsOneWidget);
    expect(find.text('novel.epub'), findsOneWidget);
    expect(find.text('2.00 MB'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('EPUB'), findsOneWidget);
    // Not signed in, so the label says what is missing rather than a size.
    expect(find.text('Not signed in.'), findsOneWidget);
  });

  testWidgets('title and author edit the marked document', (tester) async {
    final pdf = write('doc.pdf', 100);
    await pump(tester);
    state.addFiles([pdf.path]);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('title-field')),
      'My Title',
    );
    await tester.enterText(find.byKey(const ValueKey('author-field')), 'Me');
    await tester.pump();

    expect(state.docs.single.title, 'My Title');
    expect(state.docs.single.author, 'Me');
  });

  testWidgets('sending is refused until an account is signed in', (
    tester,
  ) async {
    final pdf = write('doc.pdf', 100);
    await pump(tester);
    state.addFiles([pdf.path]);
    await tester.pumpAndSettle();
    expect(state.canSend, isFalse);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('PRESS ENTER TO SIGN IN'), findsOneWidget);
  });

  testWidgets('number keys tick the device on that line', (tester) async {
    await signIn(tester);
    await pump(tester);
    state.addFiles([write('doc.pdf', 100).path]);
    await tester.pumpAndSettle();

    // Signing in ticks the first device, which is what the last send would
    // have left behind.
    expect(state.selectedSerials, {'SERIAL0'});
    expect(find.text('1 OF 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(state.selectedSerials, {'SERIAL0', 'SERIAL1'});
    expect(find.text('2 OF 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pumpAndSettle();
    expect(state.selectedSerials, {'SERIAL1'});

    // A clears the whole field, and fills it again.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();
    expect(state.selectedSerials, {'SERIAL0', 'SERIAL1'});
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();
    expect(state.selectedSerials, isEmpty);
    expect(find.text('No device ticked.'), findsOneWidget);
  });

  testWidgets('E turns the library copy on and off', (tester) async {
    await signIn(tester);
    await pump(tester);
    expect(
      find.text('Also keep a copy in your Kindle Library'),
      findsOneWidget,
    );
    expect(state.archive, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pumpAndSettle();
    expect(state.archive, isFalse);
  });

  testWidgets('a digit typed into a field stays in the field', (tester) async {
    await signIn(tester);
    await pump(tester);
    state.addFiles([write('doc.pdf', 100).path]);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('title-field')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('title-field')), '2001');
    await tester.pumpAndSettle();

    expect(state.docs.single.title, '2001');
    expect(state.selectedSerials, {
      'SERIAL0',
    }, reason: 'typing a year must not re-address the label');
  });

  testWidgets('a delivered send strikes the postmark and closes the window', (
    tester,
  ) async {
    final client = await signIn(tester);
    var closeRequests = 0;
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          state: state,
          onRequestClose: () async => closeRequests++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    state.addFiles([write('doc.pdf', 4096).path]);
    await tester.pumpAndSettle();
    expect(find.text('Ready to send.'), findsOneWidget);
    expect(find.textContaining('TO 1 DEVICE'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(client.sent, ['doc']);
    expect(find.text('1 document delivered to 1 device.'), findsOneWidget);
    expect(
      tester.widget<Postmark>(find.byType(Postmark)).state,
      Frank.delivered,
    );

    expect(closeRequests, 0, reason: 'the stamp is seen to land first');
    await tester.pump(const Duration(seconds: 2));
    expect(closeRequests, 1);
  });

  testWidgets('a failed send keeps the window and offers a retry', (
    tester,
  ) async {
    await signIn(tester, failWith: StateError('no route to host'));
    await pump(tester);
    state.addFiles([write('doc.pdf', 4096).path]);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.textContaining('no route to host'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('PRESS ENTER TO TRY AGAIN'), findsOneWidget);
    expect(tester.widget<Postmark>(find.byType(Postmark)).state, Frank.held);
    expect(state.docs, hasLength(1), reason: 'nothing is thrown away');
  });

  testWidgets('the keys sheet opens and any key closes it', (tester) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '?');
    await tester.pumpAndSettle();
    expect(find.text('KEYS'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('KEYS'), findsNothing);
  });

  /// The screen the user actually met: a session Amazon has stopped accepting,
  /// which used to leave three grey skeleton bars and a raw 403 on the label.
  Future<({int pairs, FakeStkClient client})> failingList(
    WidgetTester tester,
    Object failure,
  ) async {
    final client = FakeStkClient(
      devices: [device('Juraj\'s Paperwhite', 'S0')],
      listFailure: failure,
    );
    state = AppState(
      supportDir: tmp,
      store: CredentialsStore(tmp),
      client: client,
    );
    await tester.runAsync(() async {
      await state.loadPrefs();
      await state.refreshDevices();
    });
    return (pairs: 0, client: client);
  }

  testWidgets('a rejected registration pairs again without being asked', (
    tester,
  ) async {
    final setup = await failingList(
      tester,
      ApiError(
        'HTTP 403 for /GetListOfOwnedDevices',
        '{"Message":"Failed to validate DeviceInfoToken."}',
        403,
      ),
    );
    var pairs = 0;
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(state: state, onPair: () async => pairs++),
      ),
    );
    await tester.pumpAndSettle();

    expect(pairs, 1, reason: 'the only way on is a fresh pairing');
    expect(
      find.textContaining('no longer accepts this installation'),
      findsOneWidget,
    );
    expect(find.text('SIGN IN AGAIN'), findsOneWidget);
    expect(
      find.textContaining('Failed to validate DeviceInfoToken'),
      findsNothing,
      reason: 'the raw answer waits behind DETAILS',
    );

    await tester.tap(find.text('DETAILS'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Failed to validate DeviceInfoToken'),
      findsOneWidget,
    );
    expect(setup.client.listCalls, 1);
  });

  testWidgets('a service failure offers another attempt, not a pairing', (
    tester,
  ) async {
    final setup = await failingList(
      tester,
      const SocketException('Connection refused'),
    );
    var pairs = 0;
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(state: state, onPair: () async => pairs++),
      ),
    );
    await tester.pumpAndSettle();

    expect(pairs, 0);
    expect(find.text('TRY AGAIN'), findsOneWidget);
    expect(find.textContaining('Could not reach Amazon'), findsOneWidget);

    setup.client.listFailure = null;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(setup.client.listCalls, 2, reason: 'enter tries the list again');
    expect(find.text('Juraj\'s Paperwhite'), findsOneWidget);
  });

  testWidgets('removing a document empties the label', (tester) async {
    final pdf = write('doc.pdf', 100);
    await pump(tester);
    state.addFiles([pdf.path]);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CrossMark).first);
    await tester.pumpAndSettle();
    expect(state.docs, isEmpty);
    expect(find.text('Nothing to send yet.'), findsOneWidget);
  });
}
