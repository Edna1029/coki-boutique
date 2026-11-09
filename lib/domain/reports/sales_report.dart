import '../../data/models/sale_model.dart';

/// Sales totals for one product within a report period.
class ProductSales {
  final String productName;
  final int units;
  final double revenue;

  const ProductSales({required this.productName, required this.units, required this.revenue});
}

/// Pure calculation of a sales report over the last [days] local days
/// (today included). No Flutter imports, so it can be tested on its own.
///
/// Sale dates are stored as UTC ISO-8601 strings; they are bucketed by the
/// device's LOCAL calendar day, which is what the shop owner thinks in.
class SalesReport {
  final int days;
  final DateTime firstDay; // local midnight of the oldest day in the period
  final double revenue;
  final int transactions;
  final int units;

  /// Revenue per day, oldest first; length == [days]; last entry is today.
  final List<double> dailyRevenue;

  /// Best sellers by units sold (ties broken by revenue), at most 5.
  final List<ProductSales> topProducts;

  /// Revenue of the [days] days immediately before this period.
  final double previousRevenue;

  const SalesReport._({
    required this.days,
    required this.firstDay,
    required this.revenue,
    required this.transactions,
    required this.units,
    required this.dailyRevenue,
    required this.topProducts,
    required this.previousRevenue,
  });

  /// Average revenue per transaction (0 when there were no sales).
  double get averageSale => transactions == 0 ? 0 : revenue / transactions;

  /// % change vs the previous period, or null when there is nothing to compare.
  double? get changePercent =>
      previousRevenue > 0 ? (revenue - previousRevenue) / previousRevenue * 100 : null;

  factory SalesReport.lastDays(List<SaleModel> sales, int days, {DateTime? now}) {
    assert(days > 0);
    final n = (now ?? DateTime.now());
    final today = DateTime(n.year, n.month, n.day);
    final firstDay = today.subtract(Duration(days: days - 1));

    final daily = List<double>.filled(days, 0);
    var revenue = 0.0;
    var previous = 0.0;
    var transactions = 0;
    var units = 0;
    final byProduct = <String, ProductSales>{};

    for (final sale in sales) {
      final local = DateTime.tryParse(sale.date)?.toLocal();
      if (local == null) continue;
      final day = DateTime(local.year, local.month, local.day);
      final daysAgo = today.difference(day).inDays;

      if (daysAgo >= 0 && daysAgo < days) {
        daily[days - 1 - daysAgo] += sale.totalAmount;
        revenue += sale.totalAmount;
        transactions++;
        for (final item in sale.items) {
          units += item.quantity;
          final current = byProduct[item.productId];
          byProduct[item.productId] = ProductSales(
            productName: item.productName,
            units: (current?.units ?? 0) + item.quantity,
            revenue: (current?.revenue ?? 0) + item.totalAmount,
          );
        }
      } else if (daysAgo >= days && daysAgo < days * 2) {
        previous += sale.totalAmount;
      }
    }

    final top = byProduct.values.toList()
      ..sort((a, b) {
        final byUnits = b.units.compareTo(a.units);
        return byUnits != 0 ? byUnits : b.revenue.compareTo(a.revenue);
      });

    return SalesReport._(
      days: days,
      firstDay: firstDay,
      revenue: revenue,
      transactions: transactions,
      units: units,
      dailyRevenue: daily,
      topProducts: top.take(5).toList(),
      previousRevenue: previous,
    );
  }
}
