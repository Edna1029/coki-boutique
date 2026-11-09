import 'package:flutter/material.dart';

/// App color system as defined in the UI/UX design specification.
/// Primary: Emerald Green (#10B981)
/// Secondary: Warm Brown (#8B5E3C)
class AppColors {
  // Brand Colors
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color primaryGreenDark = Color(0xFF059669);
  static const Color primaryGreenLight = Color(0xFFD1FAE5);

  static const Color secondaryBrown = Color(0xFF8B5E3C);
  static const Color secondaryBrownDark = Color(0xFF6B4423);
  static const Color secondaryBrownLight = Color(0xFFF7EFE8);
  static const Color secondaryBrownDarkTheme = Color(0xFFA47551);

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF1F2937);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextMuted = Color(0xFF9CA3AF);

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF2A2A2A);
  static const Color darkCard = Color(0xFF2D2D2D);
  static const Color darkBorder = Color(0xFF3F3F46);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextMuted = Color(0xFF71717A);

  // Status & Utility Colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Credit Status Badges
  static const Color creditPending = Color(0xFFF59E0B);     // Orange
  static const Color creditPartial = Color(0xFF3B82F6);     // Blue
  static const Color creditPaid = Color(0xFF10B981);        // Green
}
