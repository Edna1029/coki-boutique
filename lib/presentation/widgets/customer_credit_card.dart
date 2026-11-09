import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/credit_sale_model.dart';
import '../../domain/entities/enums.dart';

class CustomerCreditCard extends StatelessWidget {
  final CreditSaleModel credit;
  final bool isAmharic;
  final VoidCallback onRecordPayment;
  final VoidCallback onViewHistory;

  const CustomerCreditCard({
    super.key,
    required this.credit,
    this.isAmharic = false,
    required this.onRecordPayment,
    required this.onViewHistory,
  });

  Color _getStatusColor(CreditStatus status) {
    switch (status) {
      case CreditStatus.pending:
        return AppColors.creditPending;
      case CreditStatus.partiallyPaid:
        return AppColors.creditPartial;
      case CreditStatus.fullyPaid:
        return AppColors.creditPaid;
    }
  }

  String _getStatusLabel(CreditStatus status) {
    if (isAmharic) {
      switch (status) {
        case CreditStatus.pending:
          return 'ያልተከፈለ';
        case CreditStatus.partiallyPaid:
          return 'በከፊል የተከፈለ';
        case CreditStatus.fullyPaid:
          return 'ሙሉ በሙሉ የተከፈለ';
      }
    } else {
      switch (status) {
        case CreditStatus.pending:
          return 'Pending';
        case CreditStatus.partiallyPaid:
          return 'Partially Paid';
        case CreditStatus.fullyPaid:
          return 'Fully Paid';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(credit.status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: isDark ? AppDimensions.darkCardShadow : AppDimensions.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Header and Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.secondaryBrown.withOpacity(0.15),
                      child: Text(
                        credit.customerName.isNotEmpty
                            ? credit.customerName[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: AppColors.secondaryBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          credit.customerName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          credit.phoneNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getStatusLabel(credit.status),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              credit.productsDescription,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),

            // Financial Summary Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.grey[100])?.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAmharic ? 'ጠቅላላ ዕዳ' : 'Total Owed',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(credit.totalAmountOwed, isAmharic: isAmharic),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAmharic ? 'የተከፈለ' : 'Paid',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(credit.amountPaid, isAmharic: isAmharic),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isAmharic ? 'ቀሪ ዕዳ' : 'Balance',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(credit.remainingBalance, isAmharic: isAmharic),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: credit.remainingBalance > 0 ? AppColors.error : AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Due Date & Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isAmharic ? "መክፈያ:" : "Due:"} ${DateFormatter.formatIsoDate(credit.dueDate, isAmharic: isAmharic)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onViewHistory,
                      icon: const Icon(Icons.history, size: 16),
                      label: Text(
                        isAmharic ? 'ታሪክ' : 'History',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.secondaryBrown,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    if (credit.remainingBalance > 0) ...[
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: onRecordPayment,
                        icon: const Icon(Icons.payment, size: 14),
                        label: Text(
                          isAmharic ? 'ክፍያ' : 'Pay',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
