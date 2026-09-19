import 'package:flutter/material.dart';

class StkColors {
  static const background = Color(0xFF1F2630);
  static const headerTop = Color(0xFF2B3442);
  static const headerBottom = Color(0xFF222A36);
  static const panel = Color(0xFF1A202A);
  static const field = Color(0xFF131922);
  static const border = Color(0xFF3B4657);
  static const borderLight = Color(0xFF5C6B84);
  static const textPrimary = Color(0xFFE8EDF4);
  static const textSecondary = Color(0xFFA7B4C4);
  static const textFaint = Color(0xFF6E7E92);
  static const accent = Color(0xFF38C7B4);
  static const accentDark = Color(0xFF1FA392);
  static const link = Color(0xFF7FB5FF);
  static const footer = Color(0xFF1B222C);
  static const statusStrip = Color(0xFF232B37);
}

TextStyle heading([double size = 20]) => TextStyle(
  fontSize: size,
  fontWeight: FontWeight.w400,
  color: StkColors.textSecondary,
  letterSpacing: 0.3,
);

ThemeData stkTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: StkColors.background,
  colorScheme: const ColorScheme.dark(
    surface: StkColors.background,
    primary: StkColors.accent,
    secondary: StkColors.accent,
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? StkColors.accentDark
          : StkColors.field,
    ),
    checkColor: WidgetStateProperty.all(Colors.white),
    side: const BorderSide(color: StkColors.borderLight),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: StkColors.field,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: StkColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: StkColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: StkColors.accent),
    ),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: StkColors.textPrimary),
  ),
);
