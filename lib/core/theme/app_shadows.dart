import 'package:flutter/material.dart';

/// Centralized elevation and shadow tokens for TrustTracker.
///
/// Strictly adheres to calm, clean, non-neon mobile design:
/// - No multi-color glow shadows or saturated bloom.
/// - Neutral, subtle ambient shadows for depth hierarchy.
class AppShadows {
  const AppShadows._();

  /// Zero shadow for flat, border-delineated surfaces.
  static const List<BoxShadow> none = [];

  /// Extremely subtle elevation for cards and list items.
  static final List<BoxShadow> subtle = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  /// Standard card elevation.
  static final List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Soft elevation for modals and floating elements.
  static final List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Elevated floating action buttons and sheets.
  static final List<BoxShadow> floating = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  /// Legacy helper aliases mapped to calm neutral shadows (no colored glow).
  static List<BoxShadow> primary(Color _) => card;
  static List<BoxShadow> button(Color _) => subtle;
  static List<BoxShadow> glow(Color _) => card;
}
