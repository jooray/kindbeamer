import 'package:flutter/material.dart';

class StkColors {
  static const background = Color(0xFF2B2B2B);
  static const headerTop = Color(0xFF3D3D3D);
  static const headerBottom = Color(0xFF2E2E2E);
  static const panel = Color(0xFF242424);
  static const field = Color(0xFF1F1F1F);
  static const border = Color(0xFF4D4D4D);
  static const borderLight = Color(0xFF6A6A6A);
  static const textPrimary = Color(0xFFE9E9E9);
  static const textSecondary = Color(0xFF9C9C9C);
  static const textFaint = Color(0xFF7C7C7C);
  static const orange = Color(0xFFF7941E);
  static const blue = Color(0xFF0A84FF);
  static const link = Color(0xFF2E7CF6);
  static const footer = Color(0xFF262626);
}

TextStyle heading([double size = 26]) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w300,
      color: StkColors.textSecondary,
      letterSpacing: 0.5,
    );

ThemeData stkTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: StkColors.background,
      colorScheme: const ColorScheme.dark(
        surface: StkColors.background,
        primary: StkColors.blue,
        secondary: StkColors.orange,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? StkColors.borderLight
              : StkColors.field,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: StkColors.borderLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StkColors.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          borderSide: const BorderSide(color: StkColors.borderLight),
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: StkColors.textPrimary),
      ),
    );
