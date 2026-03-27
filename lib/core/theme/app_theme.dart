import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppAccentColor {
  final String name;
  final Color color;

  const AppAccentColor(this.name, this.color);
}

class AppAccentColors {
  static const blue = AppAccentColor('Blue', Color(0xFF3B82F6));
  static const green = AppAccentColor('Green', Color(0xFF10B981));
  static const pink = AppAccentColor('Pink', Color(0xFFEC4899));
  static const orange = AppAccentColor('Orange', Color(0xFFF97316));
  static const teal = AppAccentColor('Teal', Color(0xFF14B8A6));

  static const List<AppAccentColor> all = [
    blue,
    green,
    pink,
    orange,
    teal,
  ];

  static AppAccentColor fromColor(Color color) {
    return all.firstWhere(
      (c) => c.color.value == color.value,
      orElse: () => blue,
    );
  }

  static AppAccentColor fromHex(String hex) {
    try {
      final colorValue = int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000;
      return all.firstWhere(
        (c) => c.color.value == colorValue,
        orElse: () => blue,
      );
    } catch (_) {
      return blue;
    }
  }
}

class AppColors {
  // Brand Neutrals - Light
  static const Color lightBg = Color(0xFFF8F9FA);
  static const Color lightSurface = Colors.white;
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF4B5563);

  // Brand Neutrals - Dark (Premium Meta/Stripe Dark)
  static const Color darkBg = Color(0xFF121212); // Deep obsidian
  static const Color darkSurface = Color(0xFF1E1E1E); // Slightly elevated
  static const Color darkBorder = Color(0x1FFFFFFF); // 12% white
  static const Color darkTextPrimary = Color(0xDEFFFFFF); // 87% opacity
  static const Color darkTextSecondary = Color(0x99FFFFFF); // 60% opacity
  static const Color darkTextDisabled = Color(0x61FFFFFF); // 38% opacity

  // Functional Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

class AppTheme {
  static ThemeData getTheme(Color seedColor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = _buildColorScheme(seedColor, brightness);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
    );

    return base.copyWith(
      textTheme: _buildTextTheme(
        base.textTheme,
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightSurface,
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightSurface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: GoogleFonts.inter(
          color: isDark ? AppColors.darkTextDisabled : AppColors.lightTextSecondary.withOpacity(0.5),
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? colorScheme.primaryContainer : AppColors.lightTextPrimary,
        contentTextStyle: GoogleFonts.inter(color: isDark ? colorScheme.onPrimaryContainer : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ColorScheme _buildColorScheme(Color seed, Brightness brightness) {
    if (brightness == Brightness.light) {
      return ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
        primary: seed,
        onPrimary: Colors.white,
        primaryContainer: seed.withOpacity(0.12),
        onPrimaryContainer: seed,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        surfaceVariant: Color.lerp(seed, Colors.white, 0.95),
        outline: AppColors.lightBorder,
        error: AppColors.error,
      );
    } else {
      // Dark mode needs more vibrant accents for visibility
      final primaryColor = Color.lerp(seed, Colors.white, 0.15)!;
      return ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
        primary: primaryColor,
        onPrimary: AppColors.darkBg,
        primaryContainer: primaryColor.withOpacity(0.15),
        onPrimaryContainer: primaryColor,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        surfaceVariant: Color(0xFF1C2128),
        outline: AppColors.darkBorder,
        error: AppColors.error,
      );
    }
  }

  static TextTheme _buildTextTheme(TextTheme base, Color primary, Color secondary) {
    return TextTheme(
      displayLarge: GoogleFonts.manrope(fontSize: 40, fontWeight: FontWeight.w800, color: primary, letterSpacing: -1.5),
      displayMedium: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.w800, color: primary, letterSpacing: -1.0),
      displaySmall: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w800, color: primary),
      headlineMedium: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w700, color: primary),
      headlineSmall: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
      titleLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: primary),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: secondary),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: secondary),
      bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: secondary.withOpacity(0.7)),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: primary),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: primary),
      labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: secondary, letterSpacing: 0.5),
    );
  }
}

extension FintechTypography on TextTheme {
  TextStyle get heroAmount => displayLarge!.copyWith(height: 1.1);
  TextStyle get balanceAmount => displayMedium!.copyWith(letterSpacing: -0.5);
  TextStyle get positiveAmount => titleSmall!.copyWith(color: AppColors.success, fontWeight: FontWeight.w800);
  TextStyle get negativeAmount => titleSmall!.copyWith(color: AppColors.error, fontWeight: FontWeight.w800);
  TextStyle get sectionLabel => labelMedium!.copyWith(
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: labelSmall!.color,
  );
}
