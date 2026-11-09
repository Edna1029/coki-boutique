import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../widgets/sync_refresh_mixin.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/display_names.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/credit_sale_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/services/excel_export_service.dart';
import '../../../data/services/sqlite_service.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/reports/sales_report.dart';

/// Reports (PRD §19): weekly & monthly sales, credit report, inventory report.
/// Every figure is computed from the local database — nothing is hard-coded.
class ReportsScreen extends StatefulWidget {
  final bool isAmharic;

  const ReportsScreen({super.key, required this.isAmharic});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin, SyncRefreshMixin {
  final SQLiteService _sqliteService = SQLiteService();
  late TabController _tabController;
  bool _isLoading = true;

  List<ProductModel> _products = [];
  List<SaleModel> _sales = [];
  List<CreditSaleModel> _credits = [];

  bool get _am => widget.isAmharic;
  String _money(double v) => CurrencyFormatter.format(v, isAmharic: _am);

  @override
  void onSyncedData() => _loadData();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final p = await _sqliteService.getAllProducts();
      final s = await _sqliteService.getAllSales();
      final c = await _sqliteService.getAllCreditSales();
      if (mounted) {
        setState(() {
          _products = p;
          _sales = s;
          _credits = c;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportExcel() async {
    try {
      await ExcelExportService.exportInventoryExcel(_products);
      await ExcelExportService.exportSalesExcel(_sales);
      await ExcelExportService.exportCreditSalesExcel(_credits);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _am
                  ? 'የExcel ፋይሎች በተሳካ ሁኔታ ተፈጥረዋል (Inventory.xlsx, Sales.xlsx, CreditSales.xlsx)'
                  : 'Excel files exported successfully (Inventory.xlsx, Sales.xlsx, CreditSales.xlsx)',
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_am ? 'ማውረድ አልተሳካም: $e' : 'Export error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navReports, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: l10n.exportExcel,
            icon: const Icon(Icons.table_chart_outlined, color: AppColors.primaryGreen),
            onPressed: _exportExcel,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGreen,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          isScrollable: true,
          tabs: [
            Tab(text: _am ? 'ሳምንታዊ ሽያጭ' : 'Weekly Sales'),
            Tab(text: _am ? 'ወርሃዊ ሽያጭ' : 'Monthly Sales'),
            Tab(text: _am ? 'የብድር ሪፖርት' : 'Credit Report'),
            Tab(text: _am ? 'የክምችት ሪፖርት' : 'Inventory Report'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : TabBarView(
              controller: _tabController,
              children: [
                _refreshable(_buildSalesTab(SalesReport.lastDays(_sales, 7), isDark, weekly: true)),
                _refreshable(_buildSalesTab(SalesReport.lastDays(_sales, 30), isDark, weekly: false)),
                _refreshable(_buildCreditTab(isDark)),
                _refreshable(_buildInventoryTab(isDark)),
              ],
            ),
    );
  }

  Widget _refreshable(Widget child) => RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _loadData,
        child: child,
      );

  // ===========================================================================
  // Sales (weekly = last 7 days, monthly = last 30 days)

  Widget _buildSalesTab(SalesReport r, bool isDark, {required bool weekly}) {
    final change = r.changePercent;
    final periodLabel = weekly
        ? (_am ? 'ያለፉት 7 ቀናት' : 'Last 7 days')
        : (_am ? 'ያለፉት 30 ቀናት' : 'Last 30 days');
    final rangeLabel =
        '${DateFormatter.formatDate(r.firstDay, isAmharic: _am)} – ${DateFormatter.formatDate(DateTime.now(), isAmharic: _am)}';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(periodLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(rangeLabel, style: TextStyle(fontSize: 12, color: _muted(isDark))),
        const SizedBox(height: 12),

        // Revenue (with change vs previous period)
        _buildSummaryBox(
          title: _am ? 'ጠቅላላ ገቢ' : 'Revenue',
          value: _money(r.revenue),
          icon: Icons.trending_up,
          color: AppColors.primaryGreen,
          isDark: isDark,
          trailing: change == null
              ? null
              : _changeChip(change, weekly
                  ? (_am ? 'ካለፈው ሳምንት' : 'vs previous week')
                  : (_am ? 'ካለፉት 30 ቀናት' : 'vs previous 30 days')),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _miniStat(_am ? 'ሽያጮች' : 'Transactions', '${r.transactions}', Icons.receipt_long, isDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _miniStat(_am ? 'የተሸጡ ዕቃዎች' : 'Units sold', '${r.units}', Icons.checkroom, isDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _miniStat(_am ? 'አማካይ ሽያጭ' : 'Avg. sale', _money(r.averageSale), Icons.calculate_outlined, isDark),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _buildChartContainer(
          title: _am ? 'ዕለታዊ ገቢ' : 'Daily revenue',
          isDark: isDark,
          child: r.revenue == 0
              ? _emptyNote(_am ? 'በዚህ ጊዜ ውስጥ ምንም ሽያጭ የለም' : 'No sales in this period', isDark)
              : SizedBox(height: 200, child: weekly ? _weeklyBarChart(r) : _monthlyLineChart(r)),
        ),
        const SizedBox(height: 20),

        _buildChartContainer(
          title: _am ? 'በብዛት የተሸጡ ምርቶች' : 'Top selling products',
          isDark: isDark,
          child: r.topProducts.isEmpty
              ? _emptyNote(_am ? 'ምንም የተሸጠ ምርት የለም' : 'No products sold yet', isDark)
              : Column(
                  children: [
                    for (var i = 0; i < r.topProducts.length; i++)
                      _topProductRow(i + 1, r.topProducts[i], isDark),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        _buildExportActionBar(),
      ],
    );
  }

  Widget _weeklyBarChart(SalesReport r) {
    const enDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const amDays = ['ሰኞ', 'ማክ', 'ረቡ', 'ሐሙ', 'ዓር', 'ቅዳ', 'እሁ'];
    final maxVal = r.dailyRevenue.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.25,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
              _money(rod.toY),
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final i = val.toInt();
                if (i < 0 || i >= r.days) return const SizedBox.shrink();
                final day = r.firstDay.add(Duration(days: i));
                return Text((_am ? amDays : enDays)[day.weekday - 1], style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < r.days; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: r.dailyRevenue[i],
                color: i == r.days - 1 ? AppColors.secondaryBrown : AppColors.primaryGreen,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _monthlyLineChart(SalesReport r) {
    final maxVal = r.dailyRevenue.reduce((a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxVal * 1.25,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (val, meta) {
                final i = val.toInt();
                // Only label the start, middle and today to keep it readable.
                if (i == 0) return Text(_am ? '30 ቀን በፊት' : '30d ago', style: const TextStyle(fontSize: 10));
                if (i == r.days ~/ 2) return Text(_am ? '15 ቀን በፊት' : '15d ago', style: const TextStyle(fontSize: 10));
                if (i == r.days - 1) return Text(_am ? 'ዛሬ' : 'Today', style: const TextStyle(fontSize: 10));
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${DateFormatter.formatDate(r.firstDay.add(Duration(days: s.x.toInt())), isAmharic: _am)}\n${_money(s.y)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < r.days; i++) FlSpot(i.toDouble(), r.dailyRevenue[i])],
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.primaryGreen,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: AppColors.primaryGreen.withValues(alpha: 0.15)),
          ),
        ],
      ),
    );
  }

  Widget _topProductRow(int rank, ProductSales p, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: rank == 1 ? AppColors.secondaryBrown : AppColors.primaryGreen.withValues(alpha: 0.15),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: rank == 1 ? Colors.white : AppColors.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.productName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  _am ? '${p.units} ተሸጧል' : '${p.units} sold',
                  style: TextStyle(fontSize: 11, color: _muted(isDark)),
                ),
              ],
            ),
          ),
          Text(_money(p.revenue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // ===========================================================================
  // Credit report: customer, balance, due date, status (PRD §19)

  Widget _buildCreditTab(bool isDark) {
    final now = DateTime.now();
    bool isOverdue(CreditSaleModel c) =>
        c.remainingBalance > 0 && (DateTime.tryParse(c.dueDate)?.toLocal().isBefore(now) ?? false);

    final open = _credits.where((c) => c.remainingBalance > 0).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate)); // soonest due first
    final collected = _credits.fold<double>(0, (s, c) => s + c.amountPaid);
    final outstanding = open.fold<double>(0, (s, c) => s + c.remainingBalance);
    final overdue = open.where(isOverdue).toList();
    final overdueAmount = overdue.fold<double>(0, (s, c) => s + c.remainingBalance);
    final settled = _credits.length - open.length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryBox(
                title: _am ? 'የተሰበሰበ' : 'Collected',
                value: _money(collected),
                icon: Icons.check_circle_outline,
                color: AppColors.primaryGreen,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryBox(
                title: _am ? 'ቀሪ ዕዳ' : 'Outstanding',
                value: _money(outstanding),
                icon: Icons.pending_actions,
                color: AppColors.creditPending,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSummaryBox(
          title: _am ? 'ጊዜው ያለፈበት ዕዳ (${overdue.length})' : 'Overdue (${overdue.length})',
          value: _money(overdueAmount),
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _buildChartContainer(
          title: _am ? 'ያልተከፈሉ ብድሮች (${open.length})' : 'Open credit accounts (${open.length})',
          isDark: isDark,
          child: open.isEmpty
              ? _emptyNote(_am ? 'ሁሉም ብድሮች ተከፍለዋል' : 'All credit accounts are settled', isDark)
              : Column(children: [for (final c in open) _creditRow(c, isOverdue(c), isDark)]),
        ),
        if (settled > 0) ...[
          const SizedBox(height: 8),
          Text(
            _am ? '$settled ሙሉ በሙሉ የተከፈሉ ብድሮች' : '$settled fully paid account${settled == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 12, color: _muted(isDark)),
          ),
        ],
        const SizedBox(height: 20),
        _buildExportActionBar(),
      ],
    );
  }

  Widget _creditRow(CreditSaleModel c, bool overdue, bool isDark) {
    final statusColor = overdue
        ? AppColors.error
        : (c.status == CreditStatus.partiallyPaid ? AppColors.creditPartial : AppColors.creditPending);
    final statusText = overdue
        ? (_am ? 'ጊዜው ያለፈ' : 'Overdue')
        : (c.status == CreditStatus.partiallyPaid
            ? (_am ? 'በከፊል የተከፈለ' : 'Partially paid')
            : (_am ? 'ያልተከፈለ' : 'Pending'));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${_am ? 'የሚከፈልበት' : 'Due'}: ${DateFormatter.formatIsoDate(c.dueDate, isAmharic: _am)}',
                  style: TextStyle(fontSize: 11, color: overdue ? AppColors.error : _muted(isDark)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_money(c.remainingBalance), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(10)),
                child: Text(statusText,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Inventory report

  Widget _buildInventoryTab(bool isDark) {
    final totalUnits = _products.fold<int>(0, (sum, p) => sum + p.totalStock);
    final totalValuation = _products.fold<double>(0.0, (sum, p) => sum + p.price * p.totalStock);

    // Per-category units and value, most valuable first.
    final byCategory = <String, (int, double)>{};
    for (final p in _products) {
      final cur = byCategory[p.category] ?? (0, 0.0);
      byCategory[p.category] = (cur.$1 + p.totalStock, cur.$2 + p.price * p.totalStock);
    }
    final categories = byCategory.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final lowStock = _products.where((p) => p.totalStock <= 5).toList()
      ..sort((a, b) => a.totalStock.compareTo(b.totalStock));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryBox(
          title: _am ? 'ጠቅላላ የክምችት ዋጋ' : 'Total inventory value',
          value: _money(totalValuation),
          icon: Icons.store,
          color: AppColors.secondaryBrown,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _miniStat(_am ? 'ምርቶች' : 'Products', '${_products.length}', Icons.checkroom, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _miniStat(_am ? 'ጠቅላላ ብዛት' : 'Units', '$totalUnits', Icons.inventory_2_outlined, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _miniStat(_am ? 'ምድቦች' : 'Categories', '${categories.length}', Icons.category_outlined, isDark)),
          ],
        ),
        const SizedBox(height: 20),
        _buildChartContainer(
          title: _am ? 'በምድብ' : 'By category',
          isDark: isDark,
          child: categories.isEmpty
              ? _emptyNote(_am ? 'ምንም ምርት የለም' : 'No products yet', isDark)
              : Column(
                  children: [
                    for (final e in categories)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                DisplayNames.category(e.key, isAmharic: _am),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(_am ? '${e.value.$1} ዕቃዎች' : '${e.value.$1} units',
                                style: TextStyle(fontSize: 12, color: _muted(isDark))),
                            const SizedBox(width: 12),
                            Text(_money(e.value.$2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        _buildChartContainer(
          title: _am ? 'አነስተኛ ክምችት (≤ 5)' : 'Low stock (≤ 5)',
          isDark: isDark,
          child: lowStock.isEmpty
              ? _emptyNote(_am ? 'ሁሉም ምርቶች በቂ ክምችት አላቸው' : 'All products are well stocked', isDark)
              : Column(
                  children: [
                    for (final p in lowStock)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(p.productName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text(
                              _am ? '${p.totalStock} ቀርቷል' : '${p.totalStock} left',
                              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        _buildExportActionBar(),
      ],
    );
  }

  // ===========================================================================
  // Shared building blocks

  Color _muted(bool isDark) => isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

  Widget _emptyNote(String text, bool isDark) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(text, style: TextStyle(color: _muted(isDark)))),
      );

  Widget _changeChip(double pct, String label) {
    final up = pct >= 0;
    final color = up ? AppColors.primaryGreen : AppColors.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
          child: Text(
            '${up ? '▲' : '▼'} ${pct.abs().toStringAsFixed(1)}%',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9)),
      ],
    );
  }

  Widget _miniStat(String title, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryGreen),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark ? AppDimensions.darkCardShadow : AppDimensions.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildChartContainer({required String title, required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark ? AppDimensions.darkCardShadow : AppDimensions.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildExportActionBar() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _exportExcel,
        icon: const Icon(Icons.file_download, size: 16),
        label: Text(_am ? 'Excel አውርድ (.xlsx)' : 'Export Excel (.xlsx)'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
      ),
    );
  }
}
