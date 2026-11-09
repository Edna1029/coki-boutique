import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/sync_refresh_mixin.dart';
import '../../widgets/role_badge.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/credit_sale_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/sqlite_service.dart';
import '../../widgets/kpi_card.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel currentUser;
  final bool isAmharic;
  final Function(int) onNavigateTab;

  const DashboardScreen({
    super.key,
    required this.currentUser,
    required this.isAmharic,
    required this.onNavigateTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SyncRefreshMixin {
  final SQLiteService _sqliteService = SQLiteService();
  bool _isLoading = true;

  List<ProductModel> _products = [];
  List<SaleModel> _sales = [];
  List<CreditSaleModel> _credits = [];

  @override
  void onSyncedData() => _loadDashboardData();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _sqliteService.getAllProducts();
      final sales = await _sqliteService.getAllSales();
      final credits = await _sqliteService.getAllCreditSales();

      if (mounted) {
        setState(() {
          _products = products;
          _sales = sales;
          _credits = credits;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalInventoryQty =
        _products.fold<int>(0, (sum, p) => sum + p.totalStock);
    final totalSalesAmount =
        _sales.fold<double>(0.0, (sum, s) => sum + s.totalAmount);
    final outstandingCredit = _credits
        .where((c) => c.status.name != 'fullyPaid')
        .fold<double>(0.0, (sum, c) => sum + c.remainingBalance);

    final lowStockItems = _products.where((p) => p.totalStock <= 5).toList();

    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: AppColors.primaryGreen,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Area
                    _buildHeader(isDark, l10n),
                    const SizedBox(height: 20),

                    // KPI Cards Grid
                    _buildKpiGrid(l10n, totalInventoryQty, totalSalesAmount,
                        outstandingCredit),
                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildQuickActions(l10n, isDark),
                    const SizedBox(height: 24),

                    // Low Stock Alert Banner (if any)
                    if (lowStockItems.isNotEmpty) ...[
                      _buildLowStockBanner(lowStockItems, isDark, l10n),
                      const SizedBox(height: 24),
                    ],

                    // Sales Chart & Analytics
                    _buildWeeklySalesChart(isDark, l10n),
                    const SizedBox(height: 24),

                    // Best Selling Products & Recent Transactions
                    _buildRecentTransactions(isDark, l10n),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark, AppLocalizations l10n) {
    final now = DateTime.now();
    final formattedDate =
        DateFormatter.formatDate(now, isAmharic: widget.isAmharic);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow:
            isDark ? AppDimensions.darkCardShadow : AppDimensions.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${l10n.welcomeBack}, ',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      widget.currentUser.fullName.split(' ')[0],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isAmharic ? 'ኮኪ ቡቲክ - የሽያጭ ሥርዓት' : 'Coki Boutique - Retail POS',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 14,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          RoleBadge(role: widget.currentUser.role),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(
    AppLocalizations l10n,
    int totalInventoryQty,
    double totalSalesAmount,
    double outstandingCredit,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            KpiCard(
              title: l10n.totalProducts,
              value: '${_products.length}',
              icon: Icons.checkroom,
              iconColor: AppColors.primaryGreen,
              subtitle: _countLabel(
                _products.map((p) => p.category).toSet().length,
                en: ('category', 'categories'),
                am: 'ምድቦች',
              ),
              onTap: () => widget.onNavigateTab(1),
            ),
            KpiCard(
              title: l10n.inventoryCount,
              value: '$totalInventoryQty',
              icon: Icons.inventory_2_outlined,
              iconColor: AppColors.secondaryBrown,
              subtitle: widget.isAmharic ? 'በክምችት ያሉ ዕቃዎች' : 'Units in stock',
              onTap: () => widget.onNavigateTab(1),
            ),
            KpiCard(
              title: l10n.totalSales,
              value: CurrencyFormatter.format(totalSalesAmount,
                  isAmharic: widget.isAmharic),
              icon: Icons.point_of_sale,
              iconColor: AppColors.primaryGreen,
              subtitle:
                  _countLabel(_sales.length, en: ('sale', 'sales'), am: 'ሽያጮች'),
              onTap: () => widget.onNavigateTab(2),
            ),
            KpiCard(
              title: l10n.creditBalance,
              value: CurrencyFormatter.format(outstandingCredit,
                  isAmharic: widget.isAmharic),
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.creditPending,
              subtitle: _countLabel(
                _credits.where((c) => c.status.name != "fullyPaid").length,
                en: ('customer owes', 'customers owe'),
                am: 'ደንበኞች ዕዳ አለባቸው',
              ),
              onTap: () => widget.onNavigateTab(3),
            ),
          ],
        );
      },
    );
  }

  /// "1 sale" / "3 sales" in English; "3 ሽያጮች" in Amharic.
  String _countLabel(int n,
      {required (String, String) en, required String am}) {
    if (widget.isAmharic) return '$n $am';
    return '$n ${n == 1 ? en.$1 : en.$2}';
  }

  Widget _buildQuickActions(AppLocalizations l10n, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.quickActions,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildActionButton(
                label: l10n.newSale,
                icon: Icons.shopping_cart_checkout,
                color: AppColors.primaryGreen,
                onTap: () => widget.onNavigateTab(2), // POS
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                label: l10n.addProduct,
                icon: Icons.add_circle_outline,
                color: AppColors.secondaryBrown,
                onTap: () => widget.onNavigateTab(1), // Inventory
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                label: l10n.newCreditSale,
                icon: Icons.person_add_alt_1,
                color: AppColors.creditPending,
                onTap: () => widget.onNavigateTab(3), // Credit
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                label: l10n.generateReport,
                icon: Icons.bar_chart_outlined,
                color: AppColors.info,
                onTap: () => widget.onNavigateTab(4), // Reports
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockBanner(
      List<ProductModel> lowStock, bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lowStock.length} ${l10n.lowStockAlerts}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                ),
                Text(
                  lowStock.map((p) => p.productName).take(2).join(', ') +
                      (lowStock.length > 2 ? '...' : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => widget.onNavigateTab(1),
            child: Text(
              widget.isAmharic ? 'ተመልከት' : 'View',
              style: const TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySalesChart(bool isDark, AppLocalizations l10n) {
    // Real data: sales totals for the last 7 local days (oldest → today),
    // compared with the 7 days before that.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final totals = List<double>.filled(7, 0);
    double previousWeek = 0;
    for (final s in _sales) {
      final local = DateTime.tryParse(s.date)?.toLocal();
      if (local == null) continue;
      final day = DateTime(local.year, local.month, local.day);
      final daysAgo = today.difference(day).inDays;
      if (daysAgo >= 0 && daysAgo < 7) {
        totals[6 - daysAgo] += s.totalAmount;
      } else if (daysAgo >= 7 && daysAgo < 14) {
        previousWeek += s.totalAmount;
      }
    }
    final weekTotal = totals.fold<double>(0, (a, b) => a + b);
    final maxVal = totals.fold<double>(0, (a, b) => a > b ? a : b);
    final changePct = previousWeek > 0
        ? (weekTotal - previousWeek) / previousWeek * 100
        : null;

    const enDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const amDays = ['ሰኞ', 'ማክ', 'ረቡ', 'ሐሙ', 'ዓር', 'ቅዳ', 'እሁ'];
    String dayLabel(DateTime d) =>
        (widget.isAmharic ? amDays : enDays)[d.weekday - 1];

    final badgeText = changePct == null
        ? CurrencyFormatter.format(weekTotal, isAmharic: widget.isAmharic)
        : '${CurrencyFormatter.format(weekTotal, isAmharic: widget.isAmharic)}  '
            '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow:
            isDark ? AppDimensions.darkCardShadow : AppDimensions.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.weeklySales,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      widget.isAmharic ? 'ያለፉት 7 ቀናት' : 'Last 7 days',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (changePct != null && changePct < 0
                          ? AppColors.error
                          : AppColors.primaryGreen)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: changePct != null && changePct < 0
                        ? AppColors.error
                        : AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (weekTotal == 0)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  widget.isAmharic
                      ? 'ባለፉት 7 ቀናት ምንም ሽያጭ የለም'
                      : 'No sales in the last 7 days',
                  style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted),
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.25,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                        CurrencyFormatter.format(rod.toY,
                            isAmharic: widget.isAmharic),
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < days.length) {
                            return Text(dayLabel(days[idx]),
                                style: const TextStyle(fontSize: 10));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < 7; i++)
                      // Today's bar in brown, earlier days in green.
                      _makeBarGroup(
                          i,
                          totals[i],
                          i == 6
                              ? AppColors.secondaryBrown
                              : AppColors.primaryGreen),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions(bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow:
            isDark ? AppDimensions.darkCardShadow : AppDimensions.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.recentTransactions,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              TextButton(
                onPressed: () => widget.onNavigateTab(2),
                child: Text(
                  widget.isAmharic ? 'ሁሉንም' : 'View All',
                  style: const TextStyle(
                      color: AppColors.primaryGreen, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_sales.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  widget.isAmharic
                      ? 'ምንም የሽያጭ ዝውውር የለም'
                      : 'No sales recorded yet',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ),
            )
          else
            ..._sales.take(4).map((sale) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryGreen.withOpacity(0.12),
                  child: const Icon(Icons.receipt_long,
                      color: AppColors.primaryGreen, size: 20),
                ),
                title: Text(
                  sale.customerName ?? (widget.isAmharic ? 'ተራ ደንበኛ' : 'Walk-in Customer'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: Text(
                  '${_countLabel(sale.totalItemCount, en: ('item', 'items'), am: 'ዕቃዎች')} | '
                  '${DateFormatter.formatIsoDate(sale.date, isAmharic: widget.isAmharic)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                trailing: Text(
                  CurrencyFormatter.format(sale.totalAmount,
                      isAmharic: widget.isAmharic),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primaryGreen,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
