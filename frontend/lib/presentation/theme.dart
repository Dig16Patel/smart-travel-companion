import 'package:flutter/material.dart';

class AppTheme {
  static const Color darkBackground = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color primaryVibrant = Color(0xFF00E676);
  static const Color secondaryVibrant = Color(0xFF2979FF);
  static const Color accentVibrant = Color(0xFFFF3D00);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: primaryVibrant,
      secondary: secondaryVibrant,
      tertiary: accentVibrant,
      surface: surfaceDark,
      onPrimary: darkBackground,
      onSecondary: darkBackground,
      onSurface: textPrimary,
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        color: primaryVibrant,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: textSecondary),
      prefixIconColor: secondaryVibrant,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryVibrant,
        foregroundColor: darkBackground,
        shape: RoundedCornerShape(12),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: primaryVibrant,
      secondary: secondaryVibrant,
      tertiary: accentVibrant,
      surface: Color(0xFFF5F5F5),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black87,
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        color: primaryVibrant,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF0F0F0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      labelStyle: TextStyle(color: Colors.grey[700]),
      prefixIconColor: secondaryVibrant,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryVibrant,
        foregroundColor: Colors.white,
        shape: RoundedCornerShape(12),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ),
  );
}

class RoundedCornerShape extends RoundedRectangleBorder {
  RoundedCornerShape(double radius) : super(borderRadius: BorderRadius.circular(radius));
}
