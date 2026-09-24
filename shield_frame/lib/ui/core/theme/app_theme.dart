import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      primaryColor: const Color(0xFF0A1128),
      scaffoldBackgroundColor: const Color(0xFF0A1128),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF1282A2),
        secondary: Color(0xFFFFC857),
        error: Color(0xFFE63946),
        surface: Color(0xFF1B2838),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A1128),
        elevation: 0,
      ),
    );
  }
}\n