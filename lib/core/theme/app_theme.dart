import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  const AppTheme._();

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
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.rLg),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.rMd),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.rMd),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.rMd),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.rMd),
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
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.rMd)),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.rMd)),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.rXl),
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.rXl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurfaceElevated : const Color(0xFF1E293B),
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.rSm)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return isDark ? Colors.grey.shade700 : Colors.grey.shade400;
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return isDark ? const Color(0xFFE2E8F0) : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return isDark ? Colors.grey.shade900 : Colors.grey.shade200;
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return isDark ? const Color(0xFF1E293B) : Colors.grey.shade300;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return isDark ? const Color(0xFF334155) : Colors.grey.shade400;
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
        outlineVariant: AppColors.lightDivider,
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
        outlineVariant: AppColors.darkDivider,
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
  TextStyle get positiveAmount => AppTextStyles.titleSmall(titleSmall!.color!).copyWith(color: AppColors.success, fontWeight: FontWeight.w700);
  TextStyle get negativeAmount => AppTextStyles.titleSmall(titleSmall!.color!).copyWith(color: AppColors.error, fontWeight: FontWeight.w700);
  TextStyle get sectionLabel => AppTextStyles.labelMedium(labelMedium!.color!).copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: labelSmall!.color,
  );
}
