import 'package:flutter/material.dart';

/// Centralized gradient tokens for TrustTracker.
///
/// Strictly enforces the "no gradients, no AI-generated look" design mandate
/// by keeping all gradients visually flat and monochromatic (uniform color throughout).
class AppGradients {
  const AppGradients._();

  static LinearGradient primary(Color primaryColor) {
    return LinearGradient(
      colors: [primaryColor, primaryColor],
    );
  }

  static LinearGradient card(Color color) {
    return LinearGradient(
      colors: [color, color],
    );
  }

  static const LinearGradient success = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF10B981)],
  );

  static const LinearGradient error = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFEF4444)],
  );

  static const LinearGradient warning = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFF59E0B)],
  );

  static const LinearGradient info = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF3B82F6)],
  );

  static const LinearGradient darkSurface = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF111827)],
  );
}
