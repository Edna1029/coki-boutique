import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/entities/enums.dart';

/// Translated role name + color, shared by every screen that shows a role.
class RoleStyle {
  static String label(UserRole role, {required bool isAmharic}) {
    switch (role) {
      case UserRole.owner:
        return isAmharic ? 'ባለቤት' : 'Owner';
      case UserRole.admin:
        return isAmharic ? 'አስተዳዳሪ' : 'Admin';
      case UserRole.employee:
        return isAmharic ? 'ሰራተኛ' : 'Employee';
    }
  }

  static Color color(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return AppColors.secondaryBrown;
      case UserRole.admin:
        return AppColors.primaryGreen;
      case UserRole.employee:
        return Colors.blueGrey;
    }
  }
}

/// Solid pill with white text: readable on light AND dark backgrounds
/// (the old tinted badges were brown-on-brown in dark mode).
class RoleBadge extends StatelessWidget {
  final UserRole role;
  final double fontSize;

  const RoleBadge({super.key, required this.role, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final isAmharic = Localizations.localeOf(context).languageCode == 'am';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: RoleStyle.color(role),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        RoleStyle.label(role, isAmharic: isAmharic),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fontSize),
      ),
    );
  }
}
