import 'package:flutter/material.dart';

/// Protiti (প্রতীতি) Design System & Brand Palette
///
/// Derived from brand handoff specs:
/// - Primary: Deep Amethyst (#4A154B) - Strength & Dignity
/// - Secondary: Teal (#008080) - Growth & Clarity
/// - Danger/Alert: Crimson Red (#D32F2F) - Urgency
/// - Accent: Warm Gold (#FFC107) - Hope & Focus
/// - Dark Mode: Soft Charcoal (#121212) with elevated cards (#1E1E1E)
/// - Light Mode: Alabaster (#F8F9FA) with cards (#FFFFFF)
class AppTheme {
  // Brand Color Constants
  static const Color deepAmethyst = Color(0xFF4A154B);
  static const Color amethystLight = Color(0xFF722774);
  static const Color teal = Color(0xFF008080);
  static const Color tealLight = Color(0xFF26A69A);
  static const Color crimson = Color(0xFFD32F2F);
  static const Color warmGold = Color(0xFFFFC107);

  // Surface & Neutral Colors
  static const Color charcoalDark = Color(0xFF121212);
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color surfaceElevatedDark = Color(0xFF2A2A2A);
  static const Color textPrimaryDark = Color(0xFFF1F1F1);
  static const Color textSecondaryDark = Color(0xFFA0A0A0);

  static const Color alabasterLight = Color(0xFFF8F9FA);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF666666);

  /// Dark Theme (Default for Protiti secure sessions)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: deepAmethyst,
      scaffoldBackgroundColor: charcoalDark,
      colorScheme: const ColorScheme.dark(
        primary: deepAmethyst,
        onPrimary: Colors.white,
        primaryContainer: amethystLight,
        secondary: teal,
        onSecondary: Colors.white,
        secondaryContainer: tealLight,
        error: crimson,
        onError: Colors.white,
        tertiary: warmGold,
        onTertiary: Colors.black,
        surface: cardDark,
        onSurface: textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardDark,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: deepAmethyst,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: teal,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardDark,
        selectedItemColor: warmGold,
        unselectedItemColor: textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevatedDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondaryDark),
      ),
    );
  }

  /// Light Theme (Optional for readability under sunlight)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: deepAmethyst,
      scaffoldBackgroundColor: alabasterLight,
      colorScheme: const ColorScheme.light(
        primary: deepAmethyst,
        onPrimary: Colors.white,
        primaryContainer: amethystLight,
        secondary: teal,
        onSecondary: Colors.white,
        error: crimson,
        onError: Colors.white,
        tertiary: warmGold,
        surface: cardLight,
        onSurface: textPrimaryLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: deepAmethyst,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: deepAmethyst,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardLight,
        selectedItemColor: deepAmethyst,
        unselectedItemColor: textSecondaryLight,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
