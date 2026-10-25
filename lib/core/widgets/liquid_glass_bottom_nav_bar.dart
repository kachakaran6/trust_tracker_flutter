import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';

/// The crystal-clear liquid-glass bottom navigation bar for Trust Tracker
/// powered directly by `GlassTabBar.bottom` from `liquid_glass_widgets`.
///
/// Features:
/// - Crystal-clear non-dull glass body (`GlassBodyMode.clear`, 0.0 frost).
/// - Super-vibrant glowing neon pink accent in dark mode.
/// - Crisp specular rim highlights (`GlassSpecularSharpness.sharp`).
/// - Real-time background refraction and magnification.
/// - Dynamic liquid spring indicator that morphs and slides between tabs.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final effectiveBottom = bottomInset > 0 ? bottomInset : 8.0;

    // Crystal-clear main bar surface settings (high clarity, zero milkiness/cloudiness)
    final barSettings = LiquidGlassSettings(
      glassColor: isDark
          ? const Color(0x14101018) // Ultra-clear tinted dark obsidian glass
          : const Color(0x10FFFFFF), // Ultra-clear bright crystal glass
      bodyMode: GlassBodyMode.clear,
      frost: 0.0,
      thickness: isDark ? 28.0 : 25.0,
      blur: isDark ? 18.0 : 14.0,
      refractiveIndex: isDark ? 1.34 : 1.28,
      chromaticAberration: 0.035,
      lightIntensity: isDark ? 0.85 : 0.70,
      lightAngle: 0.75 * math.pi,
      specularSharpness: GlassSpecularSharpness.sharp,
      ambientRim: isDark ? 0.75 : 0.55,
      ambientStrength: 0.25,
      saturation: isDark ? 1.6 : 1.35,
      glowIntensity: isDark ? 1.0 : 0.75,
    );

    // Glowing vibrant liquid-spring indicator settings with super vivid accent
    final indicatorSettings = LiquidGlassSettings(
      glassColor: isDark
          ? cs.primary.withValues(alpha: 0.42) // Rich luminous pink in dark mode
          : cs.primary.withValues(alpha: 0.22),
      bodyMode: GlassBodyMode.clear,
      frost: 0.0,
      thickness: 22.0,
      refractiveIndex: 1.35,
      chromaticAberration: 0.045,
      lightIntensity: 0.95,
      lightAngle: 0.75 * math.pi,
      specularSharpness: GlassSpecularSharpness.sharp,
      ambientRim: isDark ? 0.95 : 0.70,
      ambientStrength: 0.35,
      saturation: isDark ? 2.2 : 1.6,
      glowIntensity: 1.0,
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
        quality: GlassQuality.premium,
        enableBlend: true,
        groupBackdrop: true,
        settings: barSettings,
        indicatorSettings: indicatorSettings,
        showIndicator: true,
        indicatorColor: cs.primary.withValues(alpha: isDark ? 0.45 : 0.25),
        magnification: 1.12,
        glowDuration: const Duration(milliseconds: 280),
        glowBlurRadius: isDark ? 36.0 : 24.0,
        glowSpreadRadius: isDark ? 6.0 : 4.0,
        glowOpacity: isDark ? 0.85 : 0.45,
        interactionGlowColor: cs.primary,
        interactionGlowRadius: isDark ? 36.0 : 24.0,
        selectedIconColor: cs.primary,
        selectedLabelColor: cs.primary,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.2,
          color: cs.primary,
          shadows: isDark
              ? [
                  Shadow(
                    color: cs.primary.withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        unselectedIconColor: isDark
            ? Colors.white.withValues(alpha: 0.75)
            : cs.onSurface.withValues(alpha: 0.65),
        unselectedLabelColor: isDark
            ? Colors.white.withValues(alpha: 0.75)
            : cs.onSurface.withValues(alpha: 0.65),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 10.5,
        ),
        extraButton: onAddTap != null
            ? GlassTabBarExtraButton(
                icon: const Icon(Icons.add_rounded, size: 28),
                label: 'Add',
                iconColor: cs.primary,
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
