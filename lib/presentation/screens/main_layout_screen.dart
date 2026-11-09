import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/role_badge.dart';
import '../../data/sync/sync_service.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/models/user_model.dart';
import 'dashboard/dashboard_screen.dart';
import 'inventory/inventory_screen.dart';
import 'sales/pos_screen.dart';
import 'credit/credit_sales_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  final UserModel currentUser;
  final Function(Locale) onLanguageChanged;
  final Function(bool) onThemeChanged;

  const MainLayoutScreen({
    super.key,
    required this.currentUser,
    required this.onLanguageChanged,
    required this.onThemeChanged,
  });

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;

  // Two-way cloud sync runs while a user is signed in (this screen exists
  // only then). Logging out replaces this screen, which stops sync.
  @override
  void initState() {
    super.initState();
    SyncService.instance.start();
  }

  @override
  void dispose() {
    SyncService.instance.stop();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Read live values from context so this rebuilds when they change.
    final isAmharic = Localizations.localeOf(context).languageCode == 'am';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> screens = [
      DashboardScreen(
        currentUser: widget.currentUser,
        isAmharic: isAmharic,
        onNavigateTab: _onTabTapped,
      ),
      InventoryScreen(
        isAmharic: isAmharic,
        userRole: widget.currentUser.role,
      ),
      PosScreen(
        currentUser: widget.currentUser,
        isAmharic: isAmharic,
        onGoToInventory: () => _onTabTapped(1),
      ),
      CreditSalesScreen(
        currentUser: widget.currentUser,
        isAmharic: isAmharic,
      ),
      ReportsScreen(
        isAmharic: isAmharic,
      ),
      SettingsScreen(
        currentUser: widget.currentUser,
        onLanguageChanged: widget.onLanguageChanged,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 768;

        if (isTablet) {
          // Tablet Layout: Collapsible Sidebar Navigation per design spec
          return Scaffold(
            body: Row(
              children: [
                _buildTabletSidebar(l10n, isDark),
                Expanded(
                  child: screens[_currentIndex],
                ),
              ],
            ),
          );
        } else {
          // Mobile Layout: Bottom Navigation Bar per design spec
          return Scaffold(
            body: screens[_currentIndex],
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                boxShadow: isDark ? AppDimensions.darkCardShadow : AppDimensions.softShadow,
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _onTabTapped,
                selectedItemColor: AppColors.primaryGreen,
                unselectedItemColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                unselectedLabelStyle: const TextStyle(fontSize: 10),
                type: BottomNavigationBarType.fixed,
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.dashboard_outlined),
                    activeIcon: const Icon(Icons.dashboard),
                    label: l10n.navDashboard,
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.inventory_2_outlined),
                    activeIcon: const Icon(Icons.inventory_2),
                    label: l10n.navInventory,
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.point_of_sale_outlined),
                    activeIcon: const Icon(Icons.point_of_sale),
                    label: l10n.navSales,
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    activeIcon: const Icon(Icons.account_balance_wallet),
                    label: l10n.navCredit,
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.bar_chart_outlined),
                    activeIcon: const Icon(Icons.bar_chart),
                    label: l10n.navReports,
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.settings_outlined),
                    activeIcon: const Icon(Icons.settings),
                    label: l10n.navSettings,
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildTabletSidebar(AppLocalizations l10n, bool isDark) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(right: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Column(
        children: [
          // Boutique Branding Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storefront, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        Localizations.localeOf(context).languageCode == 'am' ? 'የሽያጭ ሥርዓት' : 'POS & Retail',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Sidebar Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildSidebarItem(0, Icons.dashboard_outlined, Icons.dashboard, l10n.navDashboard),
                _buildSidebarItem(1, Icons.inventory_2_outlined, Icons.inventory_2, l10n.navInventory),
                _buildSidebarItem(2, Icons.point_of_sale_outlined, Icons.point_of_sale, l10n.navSales),
                _buildSidebarItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, l10n.navCredit),
                _buildSidebarItem(4, Icons.bar_chart_outlined, Icons.bar_chart, l10n.navReports),
                _buildSidebarItem(5, Icons.settings_outlined, Icons.settings, l10n.navSettings),
              ],
            ),
          ),

          // Logged In User Pill
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.grey[100])?.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primaryGreen,
                    child: Text(
                      widget.currentUser.fullName[0],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentUser.fullName.split(' ')[0],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          RoleStyle.label(
                            widget.currentUser.role,
                            isAmharic: Localizations.localeOf(context).languageCode == 'am',
                          ),
                          style: TextStyle(fontSize: 9, color: RoleStyle.color(widget.currentUser.role)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryGreen.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? AppColors.primaryGreen : null,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primaryGreen : null,
            fontSize: 13,
          ),
        ),
        onTap: () => _onTabTapped(index),
      ),
    );
  }
}
