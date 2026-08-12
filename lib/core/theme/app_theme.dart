import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Core palette - Najiz / Absher Inspired
  static const Color primaryNavy = Color(0xFF0F172A);
  static const Color royalEmerald = Color(0xFF0F382C);
  static const Color secondaryGold = Color(0xFFC5A880);
  static const Color accentGoldLight = Color(0xFFE6D7BD);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF121824);
  static const Color surfaceDark = Color(0xFF1E293B);

  // Warm "appointment card" palette
  static const Color cardCream = Color(0xFFF6EEDD);
  static const Color chipCream = Color(0xFFEFE3C9);
  static const Color goldText = Color(0xFFB08D3F);
  static const Color mutedText = Color(0xFF8A8478);

  static BoxDecoration cardDecoration({
    Color backgroundColor = Colors.white,
    Color borderColor = const Color(0xFFE2E8F0),
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryNavy,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNavy,
        primary: primaryNavy,
        secondary: secondaryGold,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryNavy,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: primaryNavy,
        primary: secondaryGold,
        secondary: primaryNavy,
        surface: surfaceDark,
      ),
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
