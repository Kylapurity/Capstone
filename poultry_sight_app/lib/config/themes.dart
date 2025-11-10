import 'package:flutter/material.dart';

/// AppTheme class
/// This class defines the theme for the application.
/// It includes color schemes, text styles, and other theme-related configurations.
class AppTheme {
  // Primary color palette
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color darkGreen = Color(0xFF388E3C);
  static const Color lightGreen = Color(0xFF81C784);

  // Accent colors
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentBlue = Color(0xFF2196F3);

  // Neutral colors
  static const Color backgroundColor = Colors.white;
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Colors.black;
  static const Color textSecondary = Color(0xFF757575);

  // Theme data
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: accentOrange,
        surface: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textPrimary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textSecondary,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Lexend',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        labelStyle: const TextStyle(fontFamily: 'Lexend', color: textSecondary),
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: primaryGreen),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
