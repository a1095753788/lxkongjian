import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFFE2C55); // 抖音红
  static const Color backgroundColor = Colors.black;
  static const Color surfaceColor = Color(0xFF1A1A1A);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color dividerColor = Color(0xFF2A2A2A);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor,
        surface: surfaceColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: textPrimary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        labelLarge: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
