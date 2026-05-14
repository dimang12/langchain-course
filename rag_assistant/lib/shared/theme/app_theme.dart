import 'package:flutter/material.dart';
import 'glass_theme.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: GlassTheme.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: GlassTheme.accent,
        brightness: Brightness.light,
        primary: GlassTheme.accent,
        surface: const Color(0xFFFCFBFF),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GlassTheme.inputRadius),
          borderSide: BorderSide(color: GlassTheme.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GlassTheme.inputRadius),
          borderSide: BorderSide(color: GlassTheme.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GlassTheme.inputRadius),
          borderSide: const BorderSide(color: GlassTheme.accent),
        ),
        filled: true,
        fillColor: const Color(0xCCFFFFFF),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GlassTheme.buttonRadius),
          ),
          backgroundColor: GlassTheme.accent,
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlassTheme.cardRadius),
        ),
        elevation: 0,
        color: GlassTheme.glassBg,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlassTheme.cardRadius),
        ),
        backgroundColor: const Color(0xF5FCFBFF),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: const Color(0xF5FCFBFF),
      ),
      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: GlassTheme.accent,
        brightness: Brightness.dark,
        primary: GlassTheme.accent,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GlassTheme.inputRadius),
        ),
        filled: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GlassTheme.buttonRadius),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlassTheme.cardRadius),
        ),
        elevation: 0,
      ),
    );
  }
}
