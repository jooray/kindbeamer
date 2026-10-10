import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kindbeamer/src/amazon/models.dart';
import 'package:kindbeamer/src/platform/auto_send.dart';
import 'package:kindbeamer/src/state/app_state.dart';
import 'package:kindbeamer/src/state/credentials_store.dart';

import 'support/fake_client.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kb_send');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  String pdf(String name) {
    final f = File('${tmp.path}/$name')..writeAsBytesSync(List.filled(64, 1));
    return f.path;
  }

  final kindles = [device('Paperwhite', 'S1'), device('Daylight', 'S2')];

  Future<AppState> signedIn(FakeStkClient client, {Set<String>? last}) async {
    final state = AppState(
      supportDir: tmp,
      store: CredentialsStore(tmp),
      client: client,
    );
    await state.loadPrefs();
    if (last != null) state.selectedSerials = last;
    await state.refreshDevices();
    return state;
  }

  Future<(int, String, String)> run(SendRequest req, AppState state) async {
    state.addFiles(req.paths);
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await req.run(state, out: out, err: err);
    return (code, '$out', '$err');
  }

  group('parse', () {
    test('an ordinary launch is not a send', () {
      expect(SendRequest.parse(['book.pdf']), isNull);
    });

    test('reads the options and the files', () {
      final r = SendRequest.parse([
        '--send',
        '--device',
        'Daylight',
        '--title',
        'Guide',
        '--dry-run',
        'a.pdf',
      ])!;
      expect(r.paths, ['a.pdf']);
      expect(r.devices, ['Daylight']);
      expect(r.title, 'Guide');
      expect(r.dryRun, isTrue);
      expect(r.allDevices, isFalse);
    });

    test('refuses what it cannot make sense of', () {
      for (final args in [
        ['--send', '--bogus', 'a.pdf'],
        ['--send', '--device'],
        ['--send', '--all-devices', '--device', 'X', 'a.pdf'],
        ['--send', '--title', 'T', 'a.pdf', 'b.pdf'],
      ]) {
        expect(() => SendRequest.parse(args), throwsFormatException);
      }
    });
  });

  test('sends to the devices ticked last time by default', () async {
    final client = FakeStkClient(devices: kindles);
    final state = await signedIn(client, last: {'S2'});
    final req = SendRequest.parse(['--send', pdf('guide.pdf')])!;
    final (code, out, _) = await run(req, state);
    expect(code, SendRequest.ok);
    expect(client.sent, ['guide']);
    expect(out, contains('sent "guide" to Daylight'));
  });

  test('--all-devices and --device pick the targets', () async {
    final client = FakeStkClient(devices: kindles);
    var state = await signedIn(client, last: {'S2'});
    var (code, out, _) = await run(
      SendRequest.parse(['--send', '--all-devices', pdf('a.pdf')])!,
      state,
    );
    expect(code, SendRequest.ok);
    expect(out, contains('to Paperwhite, Daylight'));

    state = await signedIn(client, last: {'S2'});
    (code, out, _) = await run(
      SendRequest.parse(['--send', '--device', 'paperwhite', pdf('b.pdf')])!,
      state,
    );
    expect(code, SendRequest.ok);
    expect(out, contains('to Paperwhite'));
    expect(out, isNot(contains('Daylight')));
  });

  test('a dry run resolves everything and uploads nothing', () async {
    final client = FakeStkClient(devices: kindles);
    final state = await signedIn(client);
    final (code, out, _) = await run(
      SendRequest.parse(['--send', '--dry-run', '--title', 'T', pdf('a.pdf')])!,
      state,
    );
    expect(code, SendRequest.ok);
    expect(client.sent, isEmpty);
    expect(out, contains('dry run, would send "T" to Paperwhite'));
  });

  test('fails with a status a script can test', () async {
    final noClient = AppState(supportDir: tmp, store: CredentialsStore(tmp));
    var (code, _, err) = await run(
      SendRequest.parse(['--send', pdf('a.pdf')])!,
      noClient,
    );
    expect(code, SendRequest.notSignedIn);
    expect(err, contains('not signed in'));

    final client = FakeStkClient(devices: kindles);
    (code, _, err) = await run(
      SendRequest.parse(['--send', '--device', 'Oasis', pdf('b.pdf')])!,
      await signedIn(client),
    );
    expect(code, SendRequest.badUsage);
    expect(err, contains('no device named "Oasis"'));

    (code, _, err) = await run(
      SendRequest.parse(['--send', '${tmp.path}/missing.pdf'])!,
      await signedIn(client),
    );
    expect(code, SendRequest.failed);

    final failing = FakeStkClient(devices: kindles, failWith: ApiError('boom'));
    (code, _, err) = await run(
      SendRequest.parse(['--send', pdf('c.pdf')])!,
      await signedIn(failing),
    );
    expect(code, SendRequest.failed);
    expect(err, contains('did not go through'));
    expect(failing.sent, isEmpty);
  });
}
