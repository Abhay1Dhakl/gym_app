import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData adminTheme() {
    const seed = Color(0xFFB35C2E);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF6EFE6),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Color(0xFFFFFBF6),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFFFFBF6),
        border: OutlineInputBorder(),
      ),
    );
  }

  static ThemeData clientTheme() {
    const seed = Color(0xFF2F6B58);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF3F1EB),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(),
      ),
    );
  }
}
