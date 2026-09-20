import 'dart:io';

import 'package:flutter/material.dart';

/// The app is drawn as a dispatch label printed on e-paper: one ink, one
/// ground, and nothing else. Every state — selected, focused, sending, failed —
/// is carried by fill, stroke or inversion, never by a hue, so the window reads
/// the same on a colour laptop screen and in a screenshot someone prints.
class Ink0 {
  const Ink0({
    required this.ground,
    required this.well,
    required this.ink,
    required this.inkMid,
    required this.inkFaint,
    required this.mark,
    required this.rule,
    required this.ruleFaint,
    required this.onInk,
    required this.scrim,
  });

  /// The paper the label is printed on.
  final Color ground;

  /// One step into the paper: boxes that hold typed content.
  final Color well;

  /// The press ink. Primary text, ticks, the franking block.
  final Color ink;

  /// Printed legends and anything said a second time.
  final Color inkMid;

  /// Hints, lane numbers at rest, notes under a box: the third and last step
  /// of text, still held at 4.5:1 on both surfaces.
  final Color inkFaint;

  /// Drawn marks rather than words — an empty tick box, the dormant postmark's
  /// ring, a remove cross. Held at 3:1, the floor for a control's outline.
  final Color mark;

  /// Hairlines between fields.
  final Color rule;

  /// Hairlines inside a field.
  final Color ruleFaint;

  /// What sits on top of an ink fill — the ground colour, knocked out.
  final Color onInk;

  /// The drop and help overlays: the whole window, inverted.
  final Color scrim;

  static const paper = Ink0(
    ground: Color(0xFFF2F1EC),
    well: Color(0xFFE9E8E2),
    ink: Color(0xFF16171A),
    inkMid: Color(0xFF52545A),
    inkFaint: Color(0xFF646669),
    mark: Color(0xFF7D7F84),
    rule: Color(0xFFC2C1BB),
    ruleFaint: Color(0xFFD8D7D1),
    onInk: Color(0xFFF2F1EC),
    scrim: Color(0xFF16171A),
  );

  /// Night is a true inversion, the way an e-reader inverts: the ink becomes
  /// the ground. Nothing is tinted on the way across.
  static const night = Ink0(
    ground: Color(0xFF101113),
    well: Color(0xFF191A1D),
    ink: Color(0xFFE9E8E3),
    inkMid: Color(0xFF9B9DA2),
    inkFaint: Color(0xFF85878C),
    mark: Color(0xFF6C6E73),
    rule: Color(0xFF3B3D41),
    ruleFaint: Color(0xFF2A2C2F),
    onInk: Color(0xFF101113),
    scrim: Color(0xFFE9E8E3),
  );

  static Ink0 of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? night : paper;
}

/// The press: legends, buttons, wayfinding. Uppercase and tracked, the voice of
/// something printed before the document existed.
const String pressFamily = 'LibreFranklin';

/// The typewriter: everything filled into the form — file names, sizes, titles,
/// device names, the state sentence.
const String typedFamily = 'CourierPrime';

/// Libre Franklin ships as a variable face, so weight travels on the axis
/// rather than as a separate file.
TextStyle press({
  double size = 10.5,
  FontWeight weight = FontWeight.w600,
  Color? color,
  double tracking = 1.4,
  double? height,
}) => TextStyle(
  fontFamily: pressFamily,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
  fontWeight: weight,
  fontSize: size,
  letterSpacing: tracking,
  color: color,
  height: height,
);

TextStyle typed({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
  double tracking = -0.2,
}) => TextStyle(
  fontFamily: typedFamily,
  fontWeight: weight,
  fontSize: size,
  color: color,
  height: height,
  letterSpacing: tracking,
);

/// Metrics the whole label is set on. Rows share one height so the eye counts
/// documents and devices without measuring either.
class Metrics {
  static const double gutter = 22;
  static const double row = 26;
  static const double sectionGap = 13;
  static const double legendGap = 7;
  static const double barredEdge = 7;
  static const double labelMaxWidth = 900;
  static const double tick = 15;
  static const double hairline = 1;
}

/// macOS prints the command glyph; everything else spells the modifier out.
String get modKey => Platform.isMacOS ? '⌘' : 'CTRL+';

ThemeData einkTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? Ink0.night : Ink0.paper;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: c.ground,
    fontFamily: pressFamily,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.onInk,
      secondary: c.ink,
      onSecondary: c.onInk,
      error: c.ink,
      onError: c.onInk,
      surface: c.ground,
      onSurface: c.ink,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.ink,
      selectionColor: c.ink.withValues(alpha: 0.22),
      selectionHandleColor: c.ink,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(3),
      radius: Radius.zero,
      thumbColor: WidgetStatePropertyAll(c.inkFaint),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    textTheme: TextTheme(bodyMedium: typed(color: c.ink)),
    dialogTheme: DialogThemeData(
      backgroundColor: c.ground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: c.ink, width: 1.2),
        borderRadius: BorderRadius.zero,
      ),
    ),
  );
}
