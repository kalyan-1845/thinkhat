import 'package:flutter/material.dart';

class AppTheme {
  // Core Color System
  static const Color background = Color(0xFF0B0C10); // Deep charcoal
  static const Color surfaceColor = Color(0xFF1A1C23); // Cards
  static const Color surfaceHighlight = Color(0xFF262933);

  // States
  static const Color aiAvailableBlue = Color(0xFF3B82F6); // Blue -> AI available
  static const Color aiUsedGreen = Color(0xFF10B981); // Green -> AI used
  static const Color normalGray = Color(0xFF4B5563); // Gray -> normal
  static const Color importantYellow = Color(0xFFF59E0B); // Yellow -> important

  // Text
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: aiAvailableBlue,
      cardColor: surfaceColor,
      useMaterial3: true,
      fontFamily: 'Roboto', // Default material sans-serif
      iconTheme: const IconThemeData(
        color: textPrimary,
        size: 24,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
        labelSmall: TextStyle(color: textSecondary, fontSize: 12),
      ),
    );
  }
}
