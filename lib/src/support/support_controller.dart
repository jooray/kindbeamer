// SYNCED COPY of support-widget/flutter/lib/support/support_controller.dart. Do not edit here:
// change the canonical file and run support-widget/flutter/sync.sh <this repo>.
// Support ask: the one object an app talks to. It owns the engine state, persists it, and opens the checkout.
// Canonical source: support-widget/flutter/lib/support/support_controller.dart (copied to apps by flutter/sync.sh).
//
// An app does four things with it:
//   launch()        when the app comes to the foreground
//   recordAction()  after each successful core action
//   evaluate(...)   at a moment of value, on the surface that shows the result; true means "show the strip"
//   (the strip itself calls support / hide / declineForever)
//   openCheckout()  for a permanent Support entry in a menu: opens the checkout, changes nothing else

import 'package:flutter/foundation.dart';

import 'support_engine.dart';
import 'support_launch.dart';
import 'support_store.dart';

class SupportConfig {
  const SupportConfig({
    required this.appId,
    required this.ref,
    this.book,
    this.trigger = const SupportTrigger(),
  });

  /// The app's key in server/config/apps.json (and the path of its checkout page).
  final String appId;

  /// The placement, the only statistic the server keeps (sales by placement).
  final String ref;

  /// Optional book id; the server defaults to the app's own.
  final String? book;

  final SupportTrigger trigger;
}

class SupportController extends ChangeNotifier {
  SupportController({
    required this.config,
    this.store = const PrefsSupportStore(),
    this.launcher = const SystemSupportLauncher(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _ready = _load();
  }

  final SupportConfig config;
  final SupportStore store;
  final SupportLauncher launcher;
  final DateTime Function() _clock;

  SupportState _state = const SupportState();
  bool _visible = false;
  late final Future<void> _ready;

  /// Completes when the stored state has been read. Every method waits for it, so an early call can
  /// never overwrite what was saved.
  Future<void> get ready => _ready;

  SupportState get state => _state;

  /// Whether the strip is on screen right now.
  bool get visible => _visible;

  String get _today => isoDay(_clock());

  Future<void> _load() async {
    _state = await store.load();
    notifyListeners();
  }

  Future<void> _update(SupportState next) async {
    _state = next;
    notifyListeners();
    await store.save(next);
  }

  /// The app came to the foreground.
  Future<void> launch() async {
    await _ready;
    await _update(onLaunch(_state, _today));
  }

  /// One successful core action.
  Future<void> recordAction() async {
    await _ready;
    await _update(onAction(_state));
  }

  /// Call at a moment of value. Returns true when the strip is (now) visible.
  Future<bool> evaluate({
    required bool momentOfValue,
    bool busy = false,
    bool isSupporter = false,
  }) async {
    await _ready;
    if (_visible) return true;
    final ok = shouldAsk(
      _state,
      SupportContext(
        today: _today,
        momentOfValue: momentOfValue,
        busy: busy,
        isSupporter: isSupporter,
      ),
      config.trigger,
    );
    if (!ok) return false;
    _visible = true;
    await _update(onShown(_state, _today));
    return true;
  }

  /// "Not now" (and the Escape key). The ask stays counted, the cooldown runs.
  void hide() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }

  /// The surface that hosted the strip went away (a new job started, the screen changed).
  void surfaceGone() => hide();

  /// "Support": opens the checkout in the browser and ends the asking. If the browser cannot be
  /// opened the strip stays, so nothing is lost.
  Future<bool> support({String? lang, required bool dark}) async {
    await _ready;
    final uri = supportUri(
      appId: config.appId,
      ref: config.ref,
      book: config.book,
      lang: lang,
      dark: dark,
    );
    final opened = await launcher.open(uri);
    if (!opened) return false;
    _visible = false;
    await _update(onSupportTapped(_state));
    return true;
  }

  /// "Don't ask again": ends the asking for good and opens nothing. A menu entry (see [openCheckout])
  /// keeps working.
  Future<void> declineForever() async {
    await _ready;
    _visible = false;
    await _update(onDeclined(_state));
  }

  /// The permanent Support entry in a menu: opens the checkout and changes nothing about the asking, so a
  /// reader who said "don't ask again" can still support whenever they like.
  Future<bool> openCheckout({
    String ref = 'menu',
    String? lang,
    required bool dark,
  }) async {
    await _ready;
    return launcher.open(
      supportUri(
        appId: config.appId,
        ref: ref,
        book: config.book,
        lang: lang,
        dark: dark,
      ),
    );
  }
}
