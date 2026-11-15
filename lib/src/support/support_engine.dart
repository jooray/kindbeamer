// SYNCED COPY of support-widget/flutter/lib/support/support_engine.dart. Do not edit here:
// change the canonical file and run support-widget/flutter/sync.sh <this repo>.
// Support ask: the rules. Pure functions, no I/O, no network, no clock of its own.
//
// Canonical source: support-widget/flutter/lib/support/support_engine.dart
// Port of support-widget/spec/engine.mjs; must pass spec/engine-vectors.json.
// Apps hold a copy made by flutter/sync.sh: never edit the copy, edit the canonical file and sync.

/// When an app may ask. The numbers are per app; the shape is the same everywhere.
class SupportTrigger {
  const SupportTrigger({
    this.minDays = 3,
    this.minActions = 3,
    this.cooldownDays = const [14, 45],
    this.maxAsks = 3,
  });

  /// Days of use (not calendar days) before the first ask.
  final int minDays;

  /// Successful core actions before the first ask.
  final int minActions;

  /// Quiet days after the first, then every later ask.
  final List<int> cooldownDays;

  /// Asks in a lifetime, then never again.
  final int maxAsks;
}

/// Everything the engine remembers. Persisted locally by a [SupportStore] under one key.
class SupportState {
  const SupportState({
    this.activeDays = 0,
    this.lastActiveDay,
    this.actions = 0,
    this.asks = 0,
    this.lastAskDay,
    this.supporter = false,
    this.declined = false,
  });

  final int activeDays;
  final String? lastActiveDay;
  final int actions;
  final int asks;
  final String? lastAskDay;
  final bool supporter;

  /// "Don't ask again": nothing is ever shown again.
  final bool declined;

  SupportState copyWith({
    int? activeDays,
    String? lastActiveDay,
    int? actions,
    int? asks,
    String? lastAskDay,
    bool? supporter,
    bool? declined,
  }) => SupportState(
    activeDays: activeDays ?? this.activeDays,
    lastActiveDay: lastActiveDay ?? this.lastActiveDay,
    actions: actions ?? this.actions,
    asks: asks ?? this.asks,
    lastAskDay: lastAskDay ?? this.lastAskDay,
    supporter: supporter ?? this.supporter,
    declined: declined ?? this.declined,
  );

  Map<String, Object?> toJson() => {
    'activeDays': activeDays,
    'lastActiveDay': lastActiveDay,
    'actions': actions,
    'asks': asks,
    'lastAskDay': lastAskDay,
    'supporter': supporter,
    'declined': declined,
  };

  /// Tolerant on purpose: anything missing or corrupt means a fresh start, never a crash and never an early ask.
  factory SupportState.fromJson(Object? json) {
    if (json is! Map) return const SupportState();
    int count(Object? v) => v is int && v >= 0 ? v : 0;
    String? day(Object? v) =>
        v is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v) ? v : null;
    return SupportState(
      activeDays: count(json['activeDays']),
      lastActiveDay: day(json['lastActiveDay']),
      actions: count(json['actions']),
      asks: count(json['asks']),
      lastAskDay: day(json['lastAskDay']),
      supporter: json['supporter'] == true,
      declined: json['declined'] == true,
    );
  }
}

/// What is true at the call site, right now.
class SupportContext {
  const SupportContext({
    required this.today,
    required this.momentOfValue,
    this.busy = false,
    this.isSupporter = false,
  });

  /// Local calendar day, "YYYY-MM-DD".
  final String today;

  /// Right after a successful action, on the surface that shows its result.
  final bool momentOfValue;

  /// The user is in the middle of something (recording, a session, driving, typing).
  final bool busy;

  /// The app's own knowledge: a hosted plan, a paid account.
  final bool isSupporter;
}

/// "YYYY-MM-DD" in the user's local calendar.
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _dayNumber(String iso) {
  final p = iso.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]).millisecondsSinceEpoch ~/ 86400000;
}

int daysBetween(String fromIso, String toIso) =>
    _dayNumber(toIso) - _dayNumber(fromIso);

/// The app came to the foreground. Counts one day of use per calendar day, never per launch.
SupportState onLaunch(SupportState s, String today) => s.lastActiveDay == today
    ? s
    : s.copyWith(activeDays: s.activeDays + 1, lastActiveDay: today);

/// One successful core action (delivered, exported, recorded, published...).
SupportState onAction(SupportState s) => s.copyWith(actions: s.actions + 1);

/// The ask was put on screen. Counted when shown, so a dismissal needs no extra bookkeeping.
SupportState onShown(SupportState s, String today) =>
    s.copyWith(asks: s.asks + 1, lastAskDay: today);

/// The user tapped Support. The checkout opens in the browser; nobody asks again.
SupportState onSupportTapped(SupportState s) => s.copyWith(supporter: true);

/// The user said "don't ask again". The app keeps a plain Support link in a menu.
SupportState onDeclined(SupportState s) => s.copyWith(declined: true);

bool shouldAsk(
  SupportState s,
  SupportContext ctx, [
  SupportTrigger trigger = const SupportTrigger(),
]) {
  if (s.supporter || s.declined || ctx.isSupporter) return false;
  if (!ctx.momentOfValue || ctx.busy) return false;
  if (s.activeDays < trigger.minDays || s.actions < trigger.minActions) {
    return false;
  }
  if (s.asks >= trigger.maxAsks) return false;
  if (s.asks > 0) {
    final last = s.lastAskDay;
    final i = s.asks - 1 < trigger.cooldownDays.length
        ? s.asks - 1
        : trigger.cooldownDays.length - 1;
    if (last == null ||
        daysBetween(last, ctx.today) < trigger.cooldownDays[i]) {
      return false;
    }
  }
  return true;
}
