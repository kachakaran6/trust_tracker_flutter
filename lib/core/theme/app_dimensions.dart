/// Centralized dimension, spacing, and radius tokens for TrustTracker.
///
/// Designed on a strict 4pt/8pt grid for consistent mobile spacing,
/// touch targets, and visual rhythm across all screen sizes.
class AppDimensions {
  const AppDimensions._();

  // Spacing & Padding Scale
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;

  // Border Radius Scale
  static const double rXs = 4.0;
  static const double rSm = 8.0;
  static const double rMd = 12.0;
  static const double rLg = 14.0;
  static const double rXl = 16.0;
  static const double rXxl = 18.0;
  static const double r3Xl = 24.0;
  static const double rFull = 9999.0;

  // Icon Sizes Scale
  static const double iconXs = 14.0;
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;
  static const double iconHub = 48.0;

  // Layout & Shell Heights
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 64.0;
  static const double buttonHeight = 52.0;
  static const double minTouchTarget = 44.0;
}
