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
  // Soft, comforting palette based on prototype
  static const Color primaryWhite = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF7F9FC);
  static const Color textPrimary = Color(0xFF2D3748);
  static const Color textSecondary = Color(0xFF718096);
  static const Color accentSoft = Color(0xFFA0AEC0);
  static const Color brandSecondary = Color(0xFF4A5568);
  static const Color panicRed = Color(0xFFC53030);

  /// Default Light Theme (Comforting & Clean)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: brandSecondary,
      scaffoldBackgroundColor: surfaceLight,
      colorScheme: const ColorScheme.light(
        primary: brandSecondary,
        onPrimary: Colors.white,
        secondary: accentSoft,
        onSecondary: Colors.white,
        error: panicRed,
        onError: Colors.white,
        surface: primaryWhite,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: primaryWhite,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandSecondary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandSecondary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: primaryWhite,
        selectedItemColor: brandSecondary,
        unselectedItemColor: accentSoft,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: primaryWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentSoft.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentSoft.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandSecondary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
      ),
    );
  }

  /// Keep dark theme for completeness, but make it softer
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: brandSecondary,
      scaffoldBackgroundColor: const Color(0xFF1A202C),
      colorScheme: const ColorScheme.dark(
        primary: accentSoft,
        onPrimary: Colors.black,
        secondary: brandSecondary,
        surface: Color(0xFF2D3748),
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A202C),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF2D3748),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF2D3748),
        selectedItemColor: Colors.white,
        unselectedItemColor: accentSoft,
      ),
    );
  }
}
