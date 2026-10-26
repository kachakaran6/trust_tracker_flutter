import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';

/// Design tokens for the liquid glass bottom navigation bar.
class _NavBarThemeTokens {
  final Color glassColor;
  final Color selectedColor;
  final Color unselectedIconColor;
  final Color unselectedLabelColor;
  final Color indicatorColor;
  final double blur;
  final double thickness;
  final double refractiveIndex;
  final double lightIntensity;
  final double ambientRim;

  const _NavBarThemeTokens({
    required this.glassColor,
    required this.selectedColor,
    required this.unselectedIconColor,
    required this.unselectedLabelColor,
    required this.indicatorColor,
    required this.blur,
    required this.thickness,
    required this.refractiveIndex,
    required this.lightIntensity,
    required this.ambientRim,
  });

  factory _NavBarThemeTokens.resolve(BuildContext context, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve selected accent color to ensure readability across all 5 accents
    final selectedColor = _resolveSelectedColor(cs.primary, isDark);

    // Dark Mode: Translucent neutral charcoal (approx #1E1E22 at ~85% opacity)
    // Light Mode: Translucent white (approx #FFFFFF at ~85% opacity)
    // The surface stays neutral and never becomes flooded by the accent color.
    final glassColor = isDark
        ? const Color(0xD91E1E22)
        : const Color(0xD9FFFFFF);

    // Restrained accent-tinted indicator background (12–16% opacity)
    final indicatorColor = cs.primary.withValues(alpha: isDark ? 0.16 : 0.12);

    // Unselected tabs: muted neutral grey (#A3A3A3 / #B0B0B0 in dark mode)
    final unselectedIconColor = isDark
        ? const Color(0xFFA3A3A3)
        : const Color(0xFF667085);

    final unselectedLabelColor = isDark
        ? const Color(0xFFB0B0B0)
        : const Color(0xFF667085);

    return _NavBarThemeTokens(
      glassColor: glassColor,
      selectedColor: selectedColor,
      unselectedIconColor: unselectedIconColor,
      unselectedLabelColor: unselectedLabelColor,
      indicatorColor: indicatorColor,
      blur: isDark ? 16.0 : 14.0,
      thickness: isDark ? 18.0 : 16.0,
      refractiveIndex: isDark ? 1.16 : 1.14,
      lightIntensity: isDark ? 0.40 : 0.35,
      ambientRim: isDark ? 0.25 : 0.20,
    );
  }

  static Color _resolveSelectedColor(Color primary, bool isDark) {
    if (isDark) {
      return primary;
    }
    // In light mode, yellow/amber accents need deeper contrast against white surfaces
    final hsv = HSVColor.fromColor(primary);
    if (hsv.hue >= 30 && hsv.hue <= 55 && hsv.value > 0.65) {
      return const Color(0xFFB45309); // Deep amber for WCAG readability
    }
    return primary;
  }
}

/// The crystal-clear liquid-glass bottom navigation bar for Trust Tracker
/// powered directly by `GlassTabBar.bottom` from `liquid_glass_widgets`.
///
/// Features:
/// - Visually neutral translucent charcoal glass surface in dark mode.
/// - Visually neutral translucent white glass surface in light mode.
/// - Restrained accent-tinted selected tab indicator with zero neon bloom.
/// - Precise dark-mode contrast hierarchy for icons, labels, and surfaces.
/// - Smooth animated transitions between all five destinations.
class LiquidGlassBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  final ColorScheme cs;
  final AppLocalizations l10n;
  final VoidCallback? onAddTap;

  const LiquidGlassBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.cs,
    required this.l10n,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = _NavBarThemeTokens.resolve(context, cs);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final effectiveBottom = bottomInset > 0 ? bottomInset : 8.0;

    // Neutral glass body settings: high clarity, zero neon saturation
    final barSettings = LiquidGlassSettings(
      glassColor: tokens.glassColor,
      bodyMode: GlassBodyMode.clear,
      frost: 0.0,
      thickness: tokens.thickness,
      blur: tokens.blur,
      refractiveIndex: tokens.refractiveIndex,
      chromaticAberration: 0.0,
      lightIntensity: tokens.lightIntensity,
      lightAngle: 0.75 * math.pi,
      specularSharpness: GlassSpecularSharpness.medium,
      ambientRim: tokens.ambientRim,
      ambientStrength: 0.08,
      saturation: 1.0,
      glowIntensity: 0.0,
    );

    // Subtle, restrained indicator settings
    final indicatorSettings = LiquidGlassSettings(
      glassColor: tokens.indicatorColor,
      bodyMode: GlassBodyMode.clear,
      frost: 0.0,
      thickness: 14.0,
      refractiveIndex: 1.15,
      chromaticAberration: 0.0,
      lightIntensity: 0.40,
      lightAngle: 0.75 * math.pi,
      specularSharpness: GlassSpecularSharpness.soft,
      ambientRim: 0.20,
      ambientStrength: 0.08,
      saturation: 1.0,
      glowIntensity: 0.0,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: effectiveBottom),
      child: GlassTabBar.bottom(
        selectedIndex: selectedIndex,
        onTabSelected: (index) {
          HapticFeedback.selectionClick();
          onTap(index);
        },
        barHeight: 64,
        barBorderRadius: 28,
        horizontalPadding: 16,
        verticalPadding: 8,
        tabPadding: const EdgeInsets.symmetric(horizontal: 4),
        quality: GlassQuality.premium,
        enableBlend: true,
        groupBackdrop: true,
        settings: barSettings,
        indicatorSettings: indicatorSettings,
        showIndicator: true,
        indicatorColor: tokens.indicatorColor,
        indicatorBorderRadius: 20,
        indicatorExpansion: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        magnification: 1.0,
        glowDuration: const Duration(milliseconds: 250),
        glowBlurRadius: 8.0,
        glowSpreadRadius: 0.0,
        glowOpacity: 0.0,
        interactionGlowColor: Colors.transparent,
        interactionGlowRadius: 0.0,
        pressScale: 1.02,
        selectedIconColor: tokens.selectedColor,
        selectedLabelColor: tokens.selectedColor,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.1,
          color: tokens.selectedColor,
        ),
        unselectedIconColor: tokens.unselectedIconColor,
        unselectedLabelColor: tokens.unselectedLabelColor,
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 10.5,
          color: tokens.unselectedLabelColor,
        ),
        extraButton: onAddTap != null
            ? GlassTabBarExtraButton(
                icon: const Icon(Icons.add_rounded, size: 28),
                label: 'Add',
                iconColor: tokens.selectedColor,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onAddTap!();
                },
              )
            : null,
        tabs: [
          GlassTab(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard_rounded),
            label: l10n.home,
          ),
          GlassTab(
            icon: const Icon(Icons.receipt_long_outlined),
            activeIcon: const Icon(Icons.receipt_long_rounded),
            label: l10n.activity,
          ),
          const GlassTab(
            icon: Icon(Icons.handshake_outlined),
            activeIcon: Icon(Icons.handshake_rounded),
            label: 'Debt / Lent',
          ),
          const GlassTab(
            icon: Icon(Icons.event_repeat_outlined),
            activeIcon: Icon(Icons.event_repeat_rounded),
            label: 'Subs',
          ),
          GlassTab(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings_rounded),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
