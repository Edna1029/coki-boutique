import 'package:flutter/material.dart';
import 'app_fonts.dart';

/// Text style helpers using the bundled fonts (no runtime downloads).
class AppTypography {
  static TextStyle getHeading({
    required BuildContext context,
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    bool isAmharic = false,
  }) {
    return TextStyle(
      fontFamily: AppFonts.primary(isAmharic: isAmharic),
      fontFamilyFallback: AppFonts.fallback(isAmharic: isAmharic),
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle getBody({
    required BuildContext context,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    bool isAmharic = false,
  }) {
    return TextStyle(
      fontFamily: AppFonts.primary(isAmharic: isAmharic),
      fontFamilyFallback: AppFonts.fallback(isAmharic: isAmharic),
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}
