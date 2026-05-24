import 'package:flutter/material.dart';

class AppShadows {
  static List<BoxShadow> primary(Color primaryColor) => [
        BoxShadow(
          color: primaryColor.withOpacity(0.3),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ];

  static final List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> button(Color primaryColor) => [
        BoxShadow(
          color: primaryColor.withOpacity(0.24),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.15),
          blurRadius: 20,
          offset: const Offset(0, 4),
          spreadRadius: 2,
        ),
      ];
}
