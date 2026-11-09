import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/role_badge.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/backup_restore_service.dart';
import '../../../data/services/firebase_auth_service.dart';
import '../../../data/sync/sync_service.dart';
import '../../../domain/entities/enums.dart';
import '../auth/login_screen.dart';
import 'user_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel currentUser;
  final Function(Locale) onLanguageChanged;
  final Function(bool) onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.currentUser,
    required this.onLanguageChanged,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// One-line summary of the live sync state, in the current language.
  String _syncSummary(SyncStatus s, bool am) {
    final parts = <String>[
      s.online ? (am ? 'በመስመር ላይ' : 'Online') : (am ? 'ከመስመር ውጭ' : 'Offline'),
      s.pending == 0
          ? (am ? 'ሁሉም ተልኳል' : 'All changes uploaded')
          : (am ? '${s.pending} ለውጦች ይጠብቃሉ' : '${s.pending} change${s.pending == 1 ? '' : 's'} waiting to upload'),
    ];
    if (s.lastSuccess != null) {
      final t = s.lastSuccess!;
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      parts.add(am ? 'መጨረሻ: $hh:$mm' : 'Last sync $hh:$mm');
    }
    return parts.join(' · ');
  }

  Future<void> _handleBackup() async {
    try {
      final file = await BackupRestoreService.createBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'am'
                  ? 'ምትኬ በተሳካ ሁኔታ ተፈጥሯል: ${file.path.split("/").last}'
                  : 'Backup created: ${file.path.split("/").last}',
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Localizations.localeOf(context).languageCode == 'am'
              ? 'ምትኬ መፍጠር አልተሳካም: $e'
              : 'Backup error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Live values from context: the switch, dropdown and card colors always
    // match what the app is actually showing.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageCode = Localizations.localeOf(context).languageCode;
    final isAmharic = languageCode == 'am';
    final isOwner = widget.currentUser.role == UserRole.owner;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.navSettings,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // User Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              boxShadow: isDark ? AppDimensions.darkCardShadow : AppDimensions.softShadow,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryGreen,
                  child: Text(
                    widget.currentUser.fullName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.currentUser.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        widget.currentUser.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RoleBadge(role: widget.currentUser.role, fontSize: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Preferences Section
          Text(
            isAmharic ? 'ምርጫዎች እና ገጽታ' : 'Appearance & Localization',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language, color: AppColors.primaryGreen),
                  title: Text(l10n.selectLanguage),
                  subtitle: Text(isAmharic ? 'አማርኛ' : 'English'),
                  trailing: DropdownButton<String>(
                    value: languageCode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'am', child: Text('አማርኛ')),
                    ],
                    onChanged: (val) {
                      if (val != null) widget.onLanguageChanged(Locale(val));
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.secondaryBrown),
                  title: Text(l10n.themeMode),
                  subtitle: Text(isDark ? l10n.dark : l10n.light),
                  value: isDark,
                  activeColor: AppColors.primaryGreen,
                  onChanged: (val) => widget.onThemeChanged(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Cloud Sync & Storage
          Text(
            isAmharic ? 'የደመና ማመሳሰል እና ዳታቤዝ' : 'Cloud Sync & Database',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                // Live sync status (updates by itself; sync also runs automatically).
                ValueListenableBuilder<SyncStatus>(
                  valueListenable: SyncService.instance.status,
                  builder: (context, s, _) => ListTile(
                    leading: Icon(
                      s.online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      color: s.online ? AppColors.primaryGreen : AppColors.creditPending,
                    ),
                    title: Text(l10n.syncStatus),
                    subtitle: Text(_syncSummary(s, isAmharic), style: const TextStyle(fontSize: 11)),
                    trailing: ElevatedButton(
                      onPressed: s.syncing ? null : SyncService.instance.syncNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: s.syncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(isAmharic ? 'አመሳስል' : 'Sync', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                if (isOwner) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.manage_accounts_outlined, color: AppColors.primaryGreen),
                    title: Text(isAmharic ? 'ተጠቃሚዎች' : 'Users'),
                    subtitle: Text(isAmharic
                        ? 'ሰራተኞችን ጨምር፣ ሚና ቀይር ወይም መዳረሻ አስወግድ'
                        : 'Add staff, change roles, remove access'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserManagementScreen(currentUser: widget.currentUser),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.backup_outlined, color: AppColors.secondaryBrown),
                    title: Text(isAmharic ? 'ሙሉ ምትኬ ፍጠር (ባለቤት)' : 'Create System Backup (Owner)'),
                    subtitle: Text(isAmharic ? 'ሁሉንም ዳታ ወደ JSON ያስቀምጣል' : 'Saves full database to JSON archive'),
                    onTap: _handleBackup,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Logout Button
          OutlinedButton.icon(
            onPressed: () async {
              // Really end the Firebase session, or "Remember Me" would log
              // the same user straight back in on next launch.
              await FirebaseAuthService().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(
                    onLanguageChanged: widget.onLanguageChanged,
                    onThemeChanged: widget.onThemeChanged,
                  ),
                ),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: Text(
              l10n.logout,
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
