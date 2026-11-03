import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MewmerTheme {
  static const Color background = Color(0xFF0B0F17);
  static const Color cardSurface = Color(0xFF131B2E);
  static const Color cardHover = Color(0xFF1A243D);
  static const Color border = Color(0xFF1F2B48);
  static const Color muted = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textPrimary = Color(0xFFF8FAFC);

  static const Color brandViolet = Color(0xFF8B5CF6);
  static const Color brandVioletDark = Color(0xFF7C3AED);
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color whatsappGreenHover = Color(0xFF1EBE5D);
  static const Color amber = Color(0xFFF59E0B);
  static const Color rose = Color(0xFFF43F5E);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: brandViolet,
        secondary: amber,
        surface: cardSurface,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: textPrimary),
        bodyMedium: GoogleFonts.inter(color: textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandViolet, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandViolet,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardHover,
        contentTextStyle: GoogleFonts.inter(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
