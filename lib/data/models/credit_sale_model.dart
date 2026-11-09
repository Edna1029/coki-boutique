import '../../domain/entities/enums.dart';
import 'payment_model.dart';

class CreditSaleModel {
  final String creditId;
  final String customerName;
  final String phoneNumber;
  final String productsDescription;
  final int totalQuantity;
  final double totalAmountOwed;
  final double amountPaid;
  final double remainingBalance;
  final String dueDate; // UTC ISO 8601
  final String dateCreated; // UTC ISO 8601
  final CreditStatus status;
  final List<PaymentModel> payments;

  CreditSaleModel({
    required this.creditId,
    required this.customerName,
    required this.phoneNumber,
    required this.productsDescription,
    required this.totalQuantity,
    required this.totalAmountOwed,
    required this.amountPaid,
    required this.remainingBalance,
    required this.dueDate,
    required this.dateCreated,
    required this.status,
    this.payments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'credit_id': creditId,
      'customer_name': customerName,
      'phone_number': phoneNumber,
      'products_description': productsDescription,
      'total_quantity': totalQuantity,
      'total_amount_owed': totalAmountOwed,
      'amount_paid': amountPaid,
      'remaining_balance': remainingBalance,
      'due_date': dueDate,
      'date_created': dateCreated,
      'status': status.name,
    };
  }

  factory CreditSaleModel.fromMap(
    Map<String, dynamic> map, {
    List<PaymentModel> payments = const [],
  }) {
    final owed = (map['total_amount_owed'] as num?)?.toDouble() ?? 0.0;
    final paid = (map['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final remaining = (map['remaining_balance'] as num?)?.toDouble() ?? (owed - paid);

    CreditStatus calcStatus;
    if (remaining <= 0) {
      calcStatus = CreditStatus.fullyPaid;
    } else if (paid > 0) {
      calcStatus = CreditStatus.partiallyPaid;
    } else {
      calcStatus = CreditStatus.fromString(map['status'] ?? 'pending');
    }

    return CreditSaleModel(
      creditId: map['credit_id'] ?? '',
      customerName: map['customer_name'] ?? '',
      phoneNumber: map['phone_number'] ?? '',
      productsDescription: map['products_description'] ?? '',
      totalQuantity: (map['total_quantity'] as num?)?.toInt() ?? 1,
      totalAmountOwed: owed,
      amountPaid: paid,
      remainingBalance: remaining,
      dueDate: map['due_date'] ?? DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String(),
      dateCreated: map['date_created'] ?? DateTime.now().toUtc().toIso8601String(),
      status: calcStatus,
      payments: payments,
    );
  }

  CreditSaleModel copyWith({
    String? creditId,
    String? customerName,
    String? phoneNumber,
    String? productsDescription,
    int? totalQuantity,
    double? totalAmountOwed,
    double? amountPaid,
    double? remainingBalance,
    String? dueDate,
    String? dateCreated,
    CreditStatus? status,
    List<PaymentModel>? payments,
  }) {
    return CreditSaleModel(
      creditId: creditId ?? this.creditId,
      customerName: customerName ?? this.customerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      productsDescription: productsDescription ?? this.productsDescription,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      totalAmountOwed: totalAmountOwed ?? this.totalAmountOwed,
      amountPaid: amountPaid ?? this.amountPaid,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      dueDate: dueDate ?? this.dueDate,
      dateCreated: dateCreated ?? this.dateCreated,
      status: status ?? this.status,
      payments: payments ?? this.payments,
    );
  }
}
