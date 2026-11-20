import 'package:flutter/material.dart';

/// Representation of an accent color pair (Light & Dark variant) for TrustTracker.
class AppAccentColor {
  final String name;
  final Color lightColor;
  final Color darkColor;

  const AppAccentColor(this.name, this.lightColor, this.darkColor);
}

/// Curated, accessible accent palette for TrustTracker.
class AppAccentColors {
  const AppAccentColors._();

  static const blue = AppAccentColor('Blue', Color(0xFF3B82F6), Color(0xFF60A5FA));
  static const green = AppAccentColor('Green', Color(0xFF10B981), Color(0xFF34D399));
  static const pink = AppAccentColor('Pink', Color(0xFFEC4899), Color(0xFFF472B6));
  static const orange = AppAccentColor('Orange', Color(0xFFF59E0B), Color(0xFFFBBF24));
  static const teal = AppAccentColor('Teal', Color(0xFF14B8A6), Color(0xFF2DD4BF));

  static const List<AppAccentColor> all = [
    blue,
    green,
    pink,
    orange,
    teal,
  ];

  static AppAccentColor fromLightColor(Color color) {
    return all.firstWhere(
      (c) => c.lightColor.value == color.value,
      orElse: () => blue,
    );
  }

  static AppAccentColor fromHex(String hex) {
    try {
      final colorValue =
          int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000;

      return all.firstWhere(
        (c) => c.lightColor.value == colorValue || c.darkColor.value == colorValue,
        orElse: () => blue,
      );
    } catch (_) {
      return blue;
    }
  }
}

/// Centralized color tokens for TrustTracker.
///
/// Follows disciplined fintech design standards:
/// - Slate & neutral palette with high WCAG AA/AAA contrast ratios.
/// - Unambiguous semantic colors for financial transactions (Income, Expense, Debt, Lent).
/// - Zero decorative neon or multi-color gradients.
class AppColors {
  const AppColors._();

  // =========================
  // LIGHT MODE (Crisp Slate)
  // =========================
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFF1F5F9);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF94A3B8);
  static const Color lightTextDisabled = Color(0xFFCBD5E1);

  // =========================
  // DARK MODE (Deep Obsidian)
  // =========================
  static const Color darkBg = Color(0xFF0B0F17);
  static const Color darkSurface = Color(0xFF131926);
  static const Color darkSurfaceElevated = Color(0xFF1E293B);
  static const Color darkSurfaceHover = Color(0xFF263345);
  static const Color darkBorder = Color(0xFF1E293B);
  static const Color darkDivider = Color(0xFF1E293B);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);
  static const Color darkTextDisabled = Color(0xFF475569);

  // =========================
  // FINANCIAL SEMANTIC COLORS
  // =========================
  static Color getSuccess(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF34D399)
          : const Color(0xFF10B981);

  static Color getError(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFF87171)
          : const Color(0xFFEF4444);

  static Color getWarning(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFFBBF24)
          : const Color(0xFFF59E0B);

  static Color getInfo(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF60A5FA)
          : const Color(0xFF3B82F6);

  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Convenient Aliases
  static const Color primary = Color(0xFF3B82F6);
  static const Color cardDark = darkSurface;
  static const Color cardLight = lightSurface;
  static const Color backgroundDark = darkBg;
  static const Color backgroundLight = lightBg;
  static const Color surfaceDark = darkSurface;
  static const Color borderDark = darkBorder;
  static const Color borderLight = lightBorder;
  static const Color textPrimaryDark = darkTextPrimary;
  static const Color textPrimaryLight = lightTextPrimary;
  static const Color textSecondaryDark = darkTextSecondary;
  static const Color textSecondaryLight = lightTextSecondary;
}
