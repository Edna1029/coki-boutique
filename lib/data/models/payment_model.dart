class PaymentModel {
  final String paymentId;
  final String creditId;
  final String paymentDate; // UTC ISO 8601
  final double amountPaid;
  final String employeeId;
  final String employeeName;
  final String? note;

  PaymentModel({
    required this.paymentId,
    required this.creditId,
    required this.paymentDate,
    required this.amountPaid,
    required this.employeeId,
    required this.employeeName,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'payment_id': paymentId,
      'credit_id': creditId,
      'payment_date': paymentDate,
      'amount_paid': amountPaid,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'note': note,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      paymentId: map['payment_id'] ?? '',
      creditId: map['credit_id'] ?? '',
      paymentDate: map['payment_date'] ?? DateTime.now().toUtc().toIso8601String(),
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0.0,
      employeeId: map['employee_id'] ?? '',
      employeeName: map['employee_name'] ?? 'Staff',
      note: map['note'],
    );
  }
}
