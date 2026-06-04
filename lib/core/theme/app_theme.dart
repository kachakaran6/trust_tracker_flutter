import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

export 'app_colors.dart';
export 'app_gradients.dart';
export 'app_text_styles.dart';
export 'app_shadows.dart';
export 'app_dimensions.dart';
export 'app_animations.dart';

import 'app_colors.dart';
import 'app_gradients.dart';
import 'app_text_styles.dart';
import 'app_shadows.dart';
import 'app_dimensions.dart';
import 'app_animations.dart';

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
        color: colorScheme.outline.withOpacity(0.1),
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
        backgroundColor: (isDark ? AppColors.darkBg : AppColors.lightBg).withOpacity(0.8),
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
          borderRadius: BorderRadius.circular(AppDimensions.rXl),
          side: BorderSide(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: (isDark ? AppColors.darkBg : AppColors.lightSurface).withOpacity(0.95),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.lg),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.rLg),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.rLg),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.rLg),
          borderSide: BorderSide(color: colorScheme.primary.withOpacity(0.5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.rLg),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: GoogleFonts.inter(
          color: isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.rLg)),
          textStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline.withOpacity(0.2), width: 1.5),
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.rLg)),
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
        backgroundColor: Color.alphaBlend(colorScheme.primary.withOpacity(isDark ? 0.03 : 0.05), isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.r3Xl)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Color.alphaBlend(colorScheme.primary.withOpacity(isDark ? 0.03 : 0.05), isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.r3Xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurfaceElevated : const Color(0xFF111827),
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.rMd)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return isDark ? Colors.grey.shade800 : Colors.grey.shade400;
          }
          if (states.contains(WidgetState.selected)) {
            return isDark ? AppColors.darkBg : Colors.white;
          }
          return isDark ? Colors.grey.shade400 : Colors.grey.shade500;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return isDark ? Colors.grey.shade900 : Colors.grey.shade200;
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return isDark ? const Color(0xFF2C2C35) : Colors.grey.shade300;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return isDark ? Colors.grey.shade600 : Colors.grey.shade400;
        }),
      ),
    );
  }

  static ColorScheme _buildColorScheme(Color seed, Brightness brightness) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    if (brightness == Brightness.light) {
      return baseScheme.copyWith(
        primary: seed,
        onPrimary: Colors.white,
        primaryContainer: seed.withOpacity(0.08),
        onPrimaryContainer: seed,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        secondary: seed,
        onSecondary: Colors.white,
        outline: AppColors.lightBorder,
        error: AppColors.error,
        surfaceVariant: AppColors.lightBg,
      );
    } else {
      return baseScheme.copyWith(
        primary: seed,
        onPrimary: Colors.white,
        primaryContainer: seed.withOpacity(0.12),
        onPrimaryContainer: seed,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        secondary: seed,
        onSecondary: Colors.white,
        surfaceVariant: AppColors.darkSurfaceElevated,
        outline: AppColors.darkBorder,
        error: AppColors.error,
      );
    }
  }

  static TextTheme _buildTextTheme(TextTheme base, Color primary, Color secondary) {
    return TextTheme(
      displayLarge: AppTextStyles.displayLarge(primary),
      displayMedium: AppTextStyles.displayMedium(primary),
      displaySmall: AppTextStyles.displaySmall(primary),
      headlineMedium: AppTextStyles.headlineMedium(primary),
      headlineSmall: AppTextStyles.headlineSmall(primary),
      titleLarge: AppTextStyles.titleLarge(primary),
      titleMedium: AppTextStyles.titleMedium(primary),
      titleSmall: AppTextStyles.titleSmall(primary),
      bodyLarge: AppTextStyles.bodyLarge(secondary),
      bodyMedium: AppTextStyles.bodyMedium(secondary),
      bodySmall: AppTextStyles.bodySmall(secondary),
      labelLarge: AppTextStyles.labelLarge(primary),
      labelMedium: AppTextStyles.labelMedium(primary),
      labelSmall: AppTextStyles.labelSmall(secondary),
    );
  }
}

extension FintechTypography on TextTheme {
  TextStyle get heroAmount => AppTextStyles.displayLarge(displayLarge!.color!).copyWith(height: 1.1);
  TextStyle get balanceAmount => AppTextStyles.displayMedium(displayMedium!.color!).copyWith(letterSpacing: -0.5);
  TextStyle get positiveAmount => AppTextStyles.titleSmall(titleSmall!.color!).copyWith(color: AppColors.success, fontWeight: FontWeight.w800);
  TextStyle get negativeAmount => AppTextStyles.titleSmall(titleSmall!.color!).copyWith(color: AppColors.error, fontWeight: FontWeight.w800);
  TextStyle get sectionLabel => AppTextStyles.labelMedium(labelMedium!.color!).copyWith(
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: labelSmall!.color,
  );
}
