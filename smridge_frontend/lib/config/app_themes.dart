import 'package:flutter/material.dart';

class AppThemes {
  // 1. DEFAULT THEME (Futuristic glassmorphism, Deep Blue/Teal)
  static final ThemeData defaultTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF0F2027),
    scaffoldBackgroundColor: const Color(0xFF071A2F), // Dark Space Blue
    colorScheme: const ColorScheme.dark(
      primary: Colors.tealAccent,
      secondary: Color(0xFF0D2B4D), // Panel background
      surface: Color(0xFF203A43),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );

  // 2. DARK THEME (Pure OLED Black & Grey)
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.black,
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      secondary: Color(0xFF1A1A1A), // Panel background
      surface: Color(0xFF2A2A2A),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );

  // 3. LIGHT THEME (Clean White & Soft Blue)
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.blueAccent,
    scaffoldBackgroundColor: const Color(0xFFF3F6F8), // Soft off-white
    colorScheme: const ColorScheme.light(
      primary: Colors.blueAccent,
      secondary: Colors.white, // Panel background
      surface: Color(0xFFE2E8F0),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black87),
      titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
    ),
  );
}
