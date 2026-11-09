import 'package:flutter/material.dart';

class AppDimensions {
  // Spacing
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;
  static const double space2XL = 48.0;

  // Corner Radii (Design Specification: Buttons 12-16, Cards 16-20, Inputs 12, Dialogs 20)
  static const double radiusInput = 12.0;
  static const double radiusButton = 14.0;
  static const double radiusCard = 18.0;
  static const double radiusDialog = 20.0;
  static const double radiusBadge = 8.0;

  // Shadows
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> darkCardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
