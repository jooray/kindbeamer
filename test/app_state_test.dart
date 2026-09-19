import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kindbeamer/src/state/app_state.dart';
import 'package:kindbeamer/src/state/credentials_store.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kb_state');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  AppState newState() =>
      AppState(supportDir: tmp, store: CredentialsStore(tmp));

  File write(String name) {
    final f = File('${tmp.path}/$name');
    f.writeAsBytesSync(List.filled(64, 0x43));
    return f;
  }

  test('archive flag and device selection survive a restart', () async {
    final first = newState();
    await first.loadPrefs();
    first.setArchive(false);
    first.toggleDevice('SERIAL1', true);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final second = newState();
    await second.loadPrefs();
    expect(second.archive, isFalse);
    expect(second.selectedSerials, {'SERIAL1'});
  });

  test(
    'removing a document keeps the selection on the same document',
    () async {
      final state = newState();
      await state.loadPrefs();
      state.addFiles([
        write('a.pdf').path,
        write('b.pdf').path,
        write('c.pdf').path,
      ]);
      state.selectDoc(2);
      expect(state.selectedDoc!.name, 'c.pdf');

      state.removeDoc(0);
      expect(state.selectedDoc!.name, 'c.pdf');

      state.removeDoc(1);
      expect(state.docs, hasLength(1));
      expect(state.selectedDoc!.name, 'b.pdf');
    },
  );

  test('mixed drops report the files that were skipped', () async {
    final state = newState();
    await state.loadPrefs();
    state.addFiles([write('good.pdf').path, write('bad.exe').path]);
    expect(state.docs, hasLength(1));
    expect(state.notice, contains('Skipped 1 file'));
  });

  test('duplicate drops are ignored without a complaint', () async {
    final state = newState();
    await state.loadPrefs();
    final pdf = write('dup.pdf').path;
    state.addFiles([pdf]);
    state.clearNotice();
    state.addFiles([pdf]);
    expect(state.docs, hasLength(1));
    expect(state.notice, isNull);
  });

  test('send is gated on a session, documents and a target device', () async {
    final state = newState();
    await state.loadPrefs();
    expect(state.canSend, isFalse);
    state.addFiles([write('x.pdf').path]);
    state.toggleDevice('SERIAL1', true);
    expect(state.signedIn, isFalse);
    expect(state.canSend, isFalse);
  });
}
