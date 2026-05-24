import 'package:flutter/material.dart';

class AppAccentColor {
  final String name;
  final Color color;

  const AppAccentColor(this.name, this.color);
}

class AppAccentColors {
  static const blue = AppAccentColor('Blue', Color(0xFF3B82F6));
  static const green = AppAccentColor('Green', Color(0xFF16A34A));
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
  static const Color lightBg = Color(0xFFF8F9FA); // Soft gray background
  static const Color lightSurface = Colors.white;
  static const Color lightBorder = Color(0xFFEDEDED); // Subtle border
  static const Color lightTextPrimary = Color(0xDE000000); // 87% opacity
  static const Color lightTextSecondary = Color(0x99000000); // 60% opacity
  static const Color lightTextDisabled = Color(0x61000000); // 38% opacity

  // Brand Neutrals - Dark (Premium Fintech Dark)
  static const Color darkBg = Color(0xFF0F0F11); // Sleek deep charcoal instead of plain 121212
  static const Color darkSurface = Color(0xFF18181C); // Solid obsidian elevated surface
  static const Color darkSurfaceVariant = Color(0xFF222228); // High elevation surface
  static const Color darkBorder = Color(0x1FFFFFFF); // 12% white
  static const Color darkTextPrimary = Color(0xDEFFFFFF); // 87% opacity
  static const Color darkTextSecondary = Color(0x99FFFFFF); // 60% opacity
  static const Color darkTextDisabled = Color(0x61FFFFFF); // 38% opacity

  // Functional Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color error = Color(0xFFEF4444); // Red Rose
  static const Color warning = Color(0xFFF59E0B); // Amber Yellow
  static const Color info = Color(0xFF3B82F6); // Blue Sky
}
