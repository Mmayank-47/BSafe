import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Color Palette inspired by modern soft-gradient glassmorphism
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color primaryViolet = Color(0xFFC084FC);
  static const Color accentNeonPurple = Color(0xFFA855F7);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentPink = Color(0xFFFB7185);
  static const Color accentMint = Color(0xFF34D399);
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color accentAmber = Color(0xFFFBBF24);

  static const Color textDark = Color(0xFF1E1B4B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color bgLight = Color(0xFFF8FAFC);

  // Background Gradient for main screens
  static const LinearGradient pageBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF3E8FF), // Soft lavender
      Color(0xFFEFF6FF), // Soft sky blue
      Color(0xFFF0FDF4), // Soft mint hint
    ],
  );

  // Hero Card Purple Gradient (like the reference UI)
  static const LinearGradient purpleHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF8B5CF6),
      Color(0xFFA855F7),
      Color(0xFFD8B4F8),
    ],
  );

  // Glassmorphic Card Decoration
  static BoxDecoration glassCardDecoration({
    Color? color,
    double borderRadius = 24.0,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.9),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // Theme Data definition
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.outfitTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        primary: primaryPurple,
        secondary: accentCyan,
        surface: Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: textDark,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: textDark,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: textDark,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: textDark,
          fontSize: 16,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: textMuted,
          fontSize: 14,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
    );
  }
}
