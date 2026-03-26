import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary palette — from Tailwind config primary (Blue)
  static const Color primary50 = Color(0xFFEFF6FF);
  static const Color primary100 = Color(0xFFDBEAFE);
  static const Color primary400 = Color(0xFF60A5FA);
  static const Color primary500 = Color(0xFF3B82F6);
  static const Color primary600 = Color(0xFF2563EB);
  static const Color primary700 = Color(0xFF1D4ED8);

  // Success — from Tailwind success (Emerald/Green)
  static const Color success50 = Color(0xFFECFDF5);
  static const Color success500 = Color(0xFF10B981);
  static const Color success600 = Color(0xFF059669);

  // Warning — from Tailwind warning (Amber)
  static const Color warning50 = Color(0xFFFFFBEB);
  static const Color warning500 = Color(0xFFF59E0B);
  static const Color warning600 = Color(0xFFD97706);

  // Danger — from Tailwind danger (Red)
  static const Color danger50 = Color(0xFFFEF2F2);
  static const Color danger500 = Color(0xFFEF4444);
  static const Color danger600 = Color(0xFFDC2626);
  static const Color danger700 = Color(0xFFB91C1C);

  // Secondary / Accent — Indigo/Violet
  static const Color secondary50 = Color(0xFFEEF2FF);
  static const Color secondary500 = Color(0xFF6366F1);
  static const Color secondary600 = Color(0xFF4F46E5);

  // Neutrals
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  // Dark mode surfaces
  static const Color darkSurface = Color(0xFF1F2937);
  static const Color darkBackground = Color(0xFF111827);
  static const Color darkCard = Color(0xFF1E2A3B);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary500,
        brightness: Brightness.light,
        primary: AppColors.primary500,
        primaryContainer: AppColors.primary50,
        secondary: AppColors.success500,
        secondaryContainer: AppColors.success50,
        error: AppColors.danger500,
        errorContainer: AppColors.danger50,
        surface: Colors.white,
        onSurface: AppColors.gray900,
      ),
    );
    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme, AppColors.gray900, AppColors.gray700),
      scaffoldBackgroundColor: AppColors.gray50,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.gray900,
        ),
        iconTheme: const IconThemeData(color: AppColors.gray900),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.gray200, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary500,
        unselectedItemColor: AppColors.gray400,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.gray50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gray200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gray200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger500),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.gray400, fontSize: 14, fontWeight: FontWeight.w400),
        labelStyle: GoogleFonts.inter(color: AppColors.gray500, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary500,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary500,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary500,
        brightness: Brightness.dark,
        primary: AppColors.primary400,
        primaryContainer: AppColors.primary700,
        secondary: AppColors.success500,
        error: AppColors.danger500,
        surface: AppColors.darkSurface,
        onSurface: Colors.white,
      ),
    );
    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme, Colors.white, Colors.white.withOpacity(0.85)),
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2D3748), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primary400,
        unselectedItemColor: AppColors.gray500,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D3748)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D3748)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary400, width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.gray500, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary500,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, Color displayColor, Color bodyColor) {
    return TextTheme(
      // --- Display (Manrope) ---
      displayLarge: GoogleFonts.manrope(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        color: displayColor,
        letterSpacing: -1.0,
      ),
      displayMedium: GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: displayColor,
      ),
      displaySmall: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: displayColor,
      ),

      // --- Headline (Manrope) ---
      headlineMedium: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: displayColor,
      ),
      headlineSmall: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: displayColor,
      ),

      // --- Title (Inter) ---
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: displayColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: displayColor,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: displayColor,
      ),

      // --- Body (Inter) ---
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: bodyColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: bodyColor,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.gray500,
      ),

      // --- Label (Inter) ---
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: displayColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: displayColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.gray500,
        letterSpacing: 0.5,
      ),
    );
  }
}

extension FintechTypography on TextTheme {
  TextStyle get heroAmount => displayLarge!.copyWith(height: 1.1);
  TextStyle get balanceAmount => displayMedium!.copyWith(letterSpacing: -0.5);
  TextStyle get sectionLabel => labelSmall!.copyWith(
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );
  
  TextStyle get positiveAmount => titleSmall!.copyWith(color: AppColors.success500, fontWeight: FontWeight.w700);
  TextStyle get negativeAmount => titleSmall!.copyWith(color: AppColors.danger500, fontWeight: FontWeight.w700);
}
