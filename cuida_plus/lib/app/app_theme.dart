import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1565C0);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFEF6C00);
  static const danger = Color(0xFFC62828);
  static const background = Color(0xFFF5F7FA);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary);
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
        backgroundColor: Colors.white, foregroundColor: scheme.onSurface, elevation: 0, scrolledUnderElevation: 1),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.black12)),
    ),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: border, enabledBorder: border),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48))),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, height: 68),
  );
}
