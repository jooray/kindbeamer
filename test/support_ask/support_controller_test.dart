import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kindbeamer/src/support/support_controller.dart';
import 'package:kindbeamer/src/support/support_engine.dart';
import 'package:kindbeamer/src/support/support_launch.dart';
import 'package:kindbeamer/src/support/support_store.dart';

class FakeLauncher implements SupportLauncher {
  FakeLauncher({this.works = true});

  final bool works;
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return works;
  }
}

/// A clock the test moves by whole days.
class Clock {
  DateTime now = DateTime(2026, 11, 1, 10);
  DateTime call() => now;
  void advance(int days) => now = now.add(Duration(days: days));
}

const config = SupportConfig(appId: 'kindbeamer', ref: 'after-delivery');

Future<SupportController> eligible(
  Clock clock,
  FakeLauncher launcher, [
  SupportStore? store,
]) async {
  final c = SupportController(
    config: config,
    store: store ?? MemorySupportStore(),
    launcher: launcher,
    clock: clock.call,
  );
  await c.launch();
  clock.advance(1);
  await c.launch();
  clock.advance(1);
  await c.launch();
  for (var i = 0; i < 3; i++) {
    await c.recordAction();
  }
  return c;
}

void main() {
  test('asks at a moment of value once the user has used the app', () async {
    final clock = Clock();
    final c = await eligible(clock, FakeLauncher());
    expect(await c.evaluate(momentOfValue: false), isFalse);
    expect(c.visible, isFalse);
    expect(await c.evaluate(momentOfValue: true), isTrue);
    expect(c.visible, isTrue);
    expect(c.state.asks, 1);
  });

  test('never while busy, never for a supporter', () async {
    final c = await eligible(Clock(), FakeLauncher());
    expect(await c.evaluate(momentOfValue: true, busy: true), isFalse);
    expect(await c.evaluate(momentOfValue: true, isSupporter: true), isFalse);
    expect(c.state.asks, 0);
  });

  test('Not now keeps the ask counted and the cooldown runs', () async {
    final clock = Clock();
    final c = await eligible(clock, FakeLauncher());
    await c.evaluate(momentOfValue: true);
    c.hide();
    expect(c.visible, isFalse);
    clock.advance(13);
    expect(await c.evaluate(momentOfValue: true), isFalse);
    clock.advance(1);
    expect(await c.evaluate(momentOfValue: true), isTrue);
    expect(c.state.asks, 2);
  });

  test(
    'Support opens the contract URL, ends the asking and nothing else is sent',
    () async {
      final launcher = FakeLauncher();
      final c = await eligible(Clock(), launcher);
      await c.evaluate(momentOfValue: true);
      expect(await c.support(dark: true), isTrue);
      expect(
        launcher.opened.single.toString(),
        'https://hackyourself.io/support/s/kindbeamer?theme=dark&ref=after-delivery',
      );
      expect(c.visible, isFalse);
      expect(c.state.supporter, isTrue);
      expect(await c.evaluate(momentOfValue: true), isFalse);
    },
  );

  test('lang and book go along only when given', () async {
    final launcher = FakeLauncher();
    final c = SupportController(
      config: const SupportConfig(
        appId: 'qrencoder',
        ref: 'after-export',
        book: 'cypherpunk-visions',
      ),
      store: MemorySupportStore(const SupportState(activeDays: 9, actions: 9)),
      launcher: launcher,
    );
    await c.evaluate(momentOfValue: true);
    await c.support(lang: 'sk', dark: false);
    expect(launcher.opened.single.queryParameters, {
      'lang': 'sk',
      'theme': 'light',
      'ref': 'after-export',
      'book': 'cypherpunk-visions',
    });
  });

  test(
    'if the browser cannot be opened the strip stays and nothing is lost',
    () async {
      final c = await eligible(Clock(), FakeLauncher(works: false));
      await c.evaluate(momentOfValue: true);
      expect(await c.support(dark: false), isFalse);
      expect(c.visible, isTrue);
      expect(c.state.supporter, isFalse);
    },
  );

  test("Don't ask again ends the asking for good and opens nothing", () async {
    final launcher = FakeLauncher();
    final clock = Clock();
    final c = await eligible(clock, launcher);
    await c.evaluate(momentOfValue: true);
    await c.declineForever();
    expect(launcher.opened, isEmpty);
    expect(c.visible, isFalse);
    expect(c.state.declined, isTrue);
    clock.advance(400);
    expect(await c.evaluate(momentOfValue: true), isFalse);
  });

  test(
    'a permanent menu entry opens the checkout and changes nothing about the asking',
    () async {
      final launcher = FakeLauncher();
      final c = await eligible(Clock(), launcher);
      await c.declineForever();
      final before = c.state.toJson();
      expect(await c.openCheckout(dark: false), isTrue);
      expect(
        launcher.opened.single.toString(),
        'https://hackyourself.io/support/s/kindbeamer?theme=light&ref=menu',
      );
      expect(c.state.toJson(), before, reason: 'a menu entry is not an ask');
      expect(c.state.supporter, isFalse);
    },
  );

  test('state survives a restart, and an early call cannot wipe it', () async {
    SharedPreferences.setMockInitialValues({
      PrefsSupportStore.key: jsonEncode(
        const SupportState(
          activeDays: 5,
          lastActiveDay: '2026-10-30',
          actions: 8,
          asks: 1,
          lastAskDay: '2026-10-30',
        ).toJson(),
      ),
    });
    final clock = Clock();
    final c = SupportController(config: config, clock: clock.call);
    // Called before the stored state has been read.
    await c.launch();
    expect(c.state.activeDays, 6);
    expect(c.state.asks, 1);

    final again = SupportController(config: config, clock: clock.call);
    await again.ready;
    expect(again.state.activeDays, 6);
    expect(again.state.actions, 8);
  });

  test('a corrupt stored value is a fresh start, not a crash', () async {
    SharedPreferences.setMockInitialValues({
      PrefsSupportStore.key: '{not json',
    });
    final c = SupportController(config: config);
    await c.ready;
    expect(c.state.asks, 0);
    expect(await c.evaluate(momentOfValue: true), isFalse);
  });
}
