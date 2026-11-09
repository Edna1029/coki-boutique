class SaleItemModel {
  final String saleItemId;
  final String saleId;
  final String productId;
  final String productName;
  final String size;
  final int quantity;
  final double unitPrice;
  final double totalAmount;

  SaleItemModel({
    required this.saleItemId,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.size,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'sale_item_id': saleItemId,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'size': size,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
    };
  }

  factory SaleItemModel.fromMap(Map<String, dynamic> map) {
    return SaleItemModel(
      saleItemId: map['sale_item_id'] ?? '',
      saleId: map['sale_id'] ?? '',
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? '',
      size: map['size'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SaleModel {
  final String saleId;
  final List<SaleItemModel> items;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final String employeeId;
  final String employeeName;
  final String? customerName;
  final String? customerPhone;
  final String date; // UTC ISO 8601
  final String paymentMethod; // 'cash', 'mobile_transfer', 'credit'

  SaleModel({
    required this.saleId,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.employeeId,
    required this.employeeName,
    this.customerName,
    this.customerPhone,
    required this.date,
    this.paymentMethod = 'cash',
  });

  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toMap() {
    return {
      'sale_id': saleId,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'date': date,
      'payment_method': paymentMethod,
    };
  }

  factory SaleModel.fromMap(
    Map<String, dynamic> map, {
    List<SaleItemModel> items = const [],
  }) {
    return SaleModel(
      saleId: map['sale_id'] ?? '',
      items: items,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      employeeId: map['employee_id'] ?? '',
      employeeName: map['employee_name'] ?? 'Staff',
      customerName: map['customer_name'],
      customerPhone: map['customer_phone'],
      date: map['date'] ?? DateTime.now().toUtc().toIso8601String(),
      paymentMethod: map['payment_method'] ?? 'cash',
    );
  }
}
