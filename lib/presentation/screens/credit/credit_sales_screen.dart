import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/credit_sale_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/sqlite_service.dart';
import '../../widgets/sync_refresh_mixin.dart';
import '../../widgets/customer_credit_card.dart';

class CreditSalesScreen extends StatefulWidget {
  final UserModel currentUser;
  final bool isAmharic;

  /// Switches to the POS tab. New credit sales are made there (cart → "Credit")
  /// so the goods are taken out of stock like any other sale.
  final VoidCallback? onGoToPos;

  const CreditSalesScreen({
    super.key,
    required this.currentUser,
    required this.isAmharic,
    this.onGoToPos,
  });

  @override
  State<CreditSalesScreen> createState() => _CreditSalesScreenState();
}

class _CreditSalesScreenState extends State<CreditSalesScreen> with SyncRefreshMixin {
  final SQLiteService _sqliteService = SQLiteService();
  bool _isLoading = true;
  String _filter = 'All'; // 'All', 'pending', 'partiallyPaid', 'fullyPaid'

  List<CreditSaleModel> _credits = [];

  @override
  void onSyncedData() => _loadCreditAccounts();

  @override
  void initState() {
    super.initState();
    _loadCreditAccounts();
  }

  Future<void> _loadCreditAccounts() async {
    setState(() => _isLoading = true);
    try {
      final records = await _sqliteService.getAllCreditSales();
      if (mounted) {
        setState(() {
          _credits = records;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<CreditSaleModel> get _filteredCredits {
    if (_filter == 'All') return _credits;
    return _credits.where((c) => c.status.name == _filter).toList();
  }

  /// Parses an amount typed by the cashier; accepts "6,500" and "6500.50".
  double? _parseAmount(String text) => double.tryParse(text.replaceAll(',', '').trim());

  String _paymentErrorMessage(InvalidPaymentException e) {
    final max = CurrencyFormatter.format(e.maxAllowed, isAmharic: widget.isAmharic);
    switch (e.reason) {
      case PaymentRejection.notPositive:
        return widget.isAmharic ? 'እባክዎ ከዜሮ በላይ የሆነ መጠን ያስገቡ።' : 'Please enter an amount greater than zero.';
      case PaymentRejection.exceedsBalance:
        return widget.isAmharic
            ? 'ክፍያው ከቀሪ ዕዳው በላይ ነው። ከፍተኛው: $max'
            : 'Payment is more than the remaining balance. Maximum: $max';
      case PaymentRejection.alreadyPaid:
        return widget.isAmharic ? 'ይህ ዕዳ ሙሉ በሙሉ ተከፍሏል።' : 'This credit is already fully paid.';
      case PaymentRejection.depositExceedsTotal:
        return widget.isAmharic
            ? 'ቅድመ ክፍያው ከጠቅላላ ዕዳው በላይ ሊሆን አይችልም። ከፍተኛው: $max'
            : 'Down payment cannot be more than the total owed. Maximum: $max';
    }
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 12)),
    );
  }

  void _showRecordPaymentDialog(CreditSaleModel credit) {
    final amountController = TextEditingController(text: credit.remainingBalance.toStringAsFixed(2));
    final noteController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusDialog)),
          title: Text(
            '${l10n.recordPayment} - ${credit.customerName}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (errorText != null) _errorBanner(errorText!),
              Text(
                '${widget.isAmharic ? "ቀሪ ዕዳ:" : "Remaining Balance:"} ${CurrencyFormatter.format(credit.remainingBalance, isAmharic: widget.isAmharic)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: widget.isAmharic ? 'የሚከፈል መጠን (ETB)' : 'Payment Amount (ETB)',
                  prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.primaryGreen),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: widget.isAmharic ? 'ማስታወሻ' : 'Notes / Transaction ID',
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final paymentVal = _parseAmount(amountController.text) ?? 0.0;

                try {
                  // The service validates against the live balance (> 0, ≤ remaining).
                  await _sqliteService.recordCreditPayment(
                    creditId: credit.creditId,
                    paymentAmount: paymentVal,
                    employeeId: widget.currentUser.userId,
                    employeeName: widget.currentUser.fullName,
                    note: noteController.text.isNotEmpty ? noteController.text : null,
                  );
                } on InvalidPaymentException catch (e) {
                  setDialogState(() => errorText = _paymentErrorMessage(e));
                  return;
                }

                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                _loadCreditAccounts();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.isAmharic
                          ? 'ክፍያው ተመዝግቧል! ቀሪ ዕዳ ተዘምኗል።'
                          : 'Payment recorded! Balance updated.',
                    ),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
              },
              child: Text(l10n.save),
            ),
          ],
        );
      }),
    );
  }

  void _showPaymentHistoryDialog(CreditSaleModel credit) {
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(context);
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusDialog)),
          title: Text(
            '${l10n.paymentHistory} - ${credit.customerName}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SizedBox(
            width: 400,
            child: credit.payments.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        widget.isAmharic ? 'ምንም የክፍያ ታሪክ አልተገኘም' : 'No payments recorded yet',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: credit.payments.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (ctx, idx) {
                      final p = credit.payments[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primaryGreenLight,
                          child: Icon(Icons.check, color: AppColors.primaryGreen, size: 18),
                        ),
                        title: Text(
                          CurrencyFormatter.format(p.amountPaid, isAmharic: widget.isAmharic),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${DateFormatter.formatIsoDate(p.paymentDate, isAmharic: widget.isAmharic)} | ${p.employeeName}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(widget.isAmharic ? 'ዝጋ' : 'Close'),
            ),
          ],
        );
      },
    );
  }

  /// New credit sales go through the POS so the goods leave stock.
  void _startNewCreditSale() {
    widget.onGoToPos?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(widget.isAmharic
            ? 'ዕቃዎቹን ወደ ጋሪ ይጨምሩ፣ ከዚያ "ብድር"ን ይምረጡ።'
            : 'Add the items to the cart, then choose "Credit" as the payment.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredCredits;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.navCredit,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: l10n.newCreditSale,
            icon: const Icon(Icons.add_shopping_cart, color: AppColors.primaryGreen, size: 26),
            onPressed: _startNewCreditSale,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All', widget.isAmharic ? 'ሁሉም' : 'All Accounts'),
                _buildFilterChip('pending', l10n.pending),
                _buildFilterChip('partiallyPaid', l10n.partiallyPaid),
                _buildFilterChip('fullyPaid', l10n.fullyPaid),
              ],
            ),
          ),

          // Customer Credit Cards List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          widget.isAmharic ? 'ምንም የብድር መዝገብ የለም' : 'No credit accounts found',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCreditAccounts,
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) {
                            final credit = filtered[idx];
                            return CustomerCreditCard(
                              credit: credit,
                              isAmharic: widget.isAmharic,
                              onRecordPayment: () => _showRecordPaymentDialog(credit),
                              onViewHistory: () => _showPaymentHistoryDialog(credit),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primaryGreen,
        onSelected: (_) => setState(() => _filter = key),
      ),
    );
  }
}
