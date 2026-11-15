// Replays spec/engine-vectors.json against the Dart port. The same file is replayed by spec/engine.test.mjs.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kindbeamer/src/support/support_engine.dart';

/// In this package the vectors live in ../spec; in an app, sync.sh copies them to test/support_ask/.
File _vectors() {
  for (final path in const [
    'test/support_ask/engine_vectors.json',
    '../spec/engine-vectors.json',
  ]) {
    final f = File(path);
    if (f.existsSync()) return f;
  }
  throw StateError('engine vectors not found');
}

void main() {
  final data =
      jsonDecode(_vectors().readAsStringSync()) as Map<String, Object?>;
  final t = data['trigger'] as Map<String, Object?>;
  final trigger = SupportTrigger(
    minDays: t['minDays'] as int,
    minActions: t['minActions'] as int,
    cooldownDays: (t['cooldownDays'] as List).cast<int>(),
    maxAsks: t['maxAsks'] as int,
  );

  for (final c in (data['cases'] as List).cast<Map<String, Object?>>()) {
    test(c['name'] as String, () {
      var s = const SupportState();
      for (final step in (c['steps'] as List).cast<List<Object?>>()) {
        switch (step[0]) {
          case 'launch':
            s = onLaunch(s, step[1] as String);
          case 'action':
            for (var i = 0; i < (step[1] as int); i++) {
              s = onAction(s);
            }
          case 'shown':
            s = onShown(s, step[1] as String);
          case 'tapped':
            s = onSupportTapped(s);
          case 'declined':
            s = onDeclined(s);
          case 'ask':
            final ctx = step[1] as Map<String, Object?>;
            expect(
              shouldAsk(
                s,
                SupportContext(
                  today: ctx['today'] as String,
                  momentOfValue: ctx['momentOfValue'] as bool,
                  busy: ctx['busy'] == true,
                  isSupporter: ctx['isSupporter'] == true,
                ),
                trigger,
              ),
              step[2],
              reason: 'at ${ctx['today']}',
            );
          default:
            fail('unknown step ${step[0]}');
        }
      }
    });
  }

  group('state persistence format', () {
    test('round trips', () {
      const s = SupportState(
        activeDays: 4,
        lastActiveDay: '2026-11-03',
        actions: 7,
        asks: 2,
        lastAskDay: '2026-11-17',
        supporter: true,
        declined: true,
      );
      final back = SupportState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(back.toJson(), s.toJson());
    });

    test('anything corrupt is a fresh start', () {
      for (final bad in <Object?>[
        null,
        42,
        'text',
        [1, 2],
        {
          'activeDays': -5,
          'asks': 'many',
          'lastAskDay': '14 Nov',
          'supporter': 'yes',
        },
      ]) {
        final s = SupportState.fromJson(bad);
        expect(s.activeDays, 0);
        expect(s.asks, 0);
        expect(s.lastAskDay, isNull);
        expect(s.supporter, isFalse);
      }
    });
  });
}
