import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_to_kindle_next/src/state/app_state.dart';
import 'package:send_to_kindle_next/src/state/credentials_store.dart';
import 'package:send_to_kindle_next/src/ui/home_page.dart';

void main() {
  late Directory tmp;
  late AppState state;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('stk_ui');
    state = AppState(
      supportDir: tmp,
      store: CredentialsStore(tmp),
    );
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

  testWidgets('window is a drop target and shows empty state', (tester) async {
    await pump(tester);
    expect(find.byType(DropTarget), findsOneWidget);
    expect(find.text('No valid document is selected to send.'), findsOneWidget);
    expect(find.text('Your document'), findsOneWidget);
    expect(find.text('Delivery options'), findsOneWidget);
    expect(
      find.text('Archive document in your Kindle Library'),
      findsOneWidget,
    );
  });

  testWidgets('dropped pdf and epub appear and drive the status strip',
      (tester) async {
    final pdf = write('bluehat.pdf', 9680 * 1024 ~/ 1000 * 1000);
    final epub = write('novel.epub', 2 * 1024 * 1024);

    await pump(tester);
    state.addFiles([pdf.path, epub.path]);
    await tester.pumpAndSettle();

    expect(find.text('bluehat.pdf'), findsOneWidget);
    expect(find.text('novel.epub'), findsOneWidget);
    expect(find.text('Your document will be sent in PDF format.'), findsOneWidget);

    await tester.tap(find.text('novel.epub'));
    await tester.pumpAndSettle();
    expect(find.text('Your document will be sent in EPUB format.'), findsOneWidget);
    expect(find.text('2.00 MB'), findsNWidgets(2));
  });

  testWidgets('title and author fields edit the selected document',
      (tester) async {
    final pdf = write('doc.pdf', 100);
    await pump(tester);
    state.addFiles([pdf.path]);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('title-field')), 'My Title');
    await tester.enterText(find.byKey(const ValueKey('author-field')), 'Me');
    await tester.pump();

    expect(state.docs.single.title, 'My Title');
    expect(state.docs.single.author, 'Me');
  });

  testWidgets('send button stays disabled without login and devices',
      (tester) async {
    final pdf = write('doc.pdf', 100);
    await pump(tester);
    state.addFiles([pdf.path]);
    await tester.pumpAndSettle();
    expect(state.canSend, isFalse);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('removing a document clears the queue', (tester) async {
    final pdf = write('doc.pdf', 100);
    await pump(tester);
    state.addFiles([pdf.path]);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(state.docs, isEmpty);
    expect(find.text('No valid document is selected to send.'), findsOneWidget);
  });
}
