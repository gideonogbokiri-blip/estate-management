import 'package:flutter/material.dart';

abstract final class EstateColors {
  static const forest = Color(0xFF0E503D);
  static const forestDeep = Color(0xFF093C2F);
  static const leaf = Color(0xFF258565);
  static const canvas = Color(0xFFF5F7F5);
  static const ink = Color(0xFF17231E);
  static const muted = Color(0xFF6D7B74);
  static const line = Color(0xFFE4EAE6);
  static const amber = Color(0xFFB87518);
  static const amberWash = Color(0xFFFFF5E5);
  static const red = Color(0xFFB84B43);
}

abstract final class EstateTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: EstateColors.forest,
      brightness: Brightness.light,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: EstateColors.forest),
      scaffoldBackgroundColor: EstateColors.canvas,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: EstateColors.ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: EstateColors.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: EstateColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: EstateColors.ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: EstateColors.ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          height: 1.45,
          color: EstateColors.muted,
        ),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: EstateColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EstateColors.canvas,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EstateColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EstateColors.leaf, width: 1.5),
        ),
      ),
    );
  }
}
