import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {

  static const Color primaryBlack = Color(0xFF121212);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color lightGray = Color(0xFFF5F5F5);

  static ThemeData get luxuryTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryBlack,
      scaffoldBackgroundColor: pureWhite,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(
            fontSize: 32, fontWeight: FontWeight.bold, color: primaryBlack, letterSpacing: 1.5),
        bodyLarge: GoogleFonts.montserrat(
            fontSize: 16, color: primaryBlack, fontWeight: FontWeight.w300),
        labelLarge: GoogleFonts.montserrat(
            fontSize: 14, fontWeight: FontWeight.w600, color: pureWhite, letterSpacing: 2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlack,
          foregroundColor: pureWhite,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Góc vuông tạo vẻ cứng cáp
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: primaryBlack)),
        labelStyle: GoogleFonts.montserrat(color: Colors.black54),
      ),
    );
  }
}