// SYNCED COPY of support-widget/flutter/lib/support/support_store.dart. Do not edit here:
// change the canonical file and run support-widget/flutter/sync.sh <this repo>.
// Support ask: local persistence. One JSON value under one key, stored where the app keeps its preferences.
// Canonical source: support-widget/flutter/lib/support/support_store.dart (copied to apps by flutter/sync.sh).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'support_engine.dart';

abstract interface class SupportStore {
  Future<SupportState> load();
  Future<void> save(SupportState state);
}

/// Production store. Failures are swallowed: the ask is a convenience, the app must work without it.
class PrefsSupportStore implements SupportStore {
  const PrefsSupportStore();

  static const key = 'support.v1';

  @override
  Future<SupportState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return const SupportState();
      return SupportState.fromJson(jsonDecode(raw));
    } catch (_) {
      return const SupportState();
    }
  }

  @override
  Future<void> save(SupportState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(state.toJson()));
    } catch (_) {
      // Nothing to do: the worst outcome is one extra ask later.
    }
  }
}

/// For tests.
class MemorySupportStore implements SupportStore {
  MemorySupportStore([this.state = const SupportState()]);

  SupportState state;

  @override
  Future<SupportState> load() async => state;

  @override
  Future<void> save(SupportState s) async => state = s;
}
