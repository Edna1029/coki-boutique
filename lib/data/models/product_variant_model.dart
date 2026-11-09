class ProductVariantModel {
  final String variantId;
  final String productId;
  final String size; // 'S', 'M', 'L', 'XL', 'XXL'
  final int quantity;
  final String lastUpdated;

  ProductVariantModel({
    required this.variantId,
    required this.productId,
    required this.size,
    required this.quantity,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'variant_id': variantId,
      'product_id': productId,
      'size': size,
      'quantity': quantity,
      'last_updated': lastUpdated,
    };
  }

  factory ProductVariantModel.fromMap(Map<String, dynamic> map) {
    return ProductVariantModel(
      variantId: map['variant_id'] ?? '',
      productId: map['product_id'] ?? '',
      size: map['size'] ?? 'M',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      lastUpdated: map['last_updated'] ?? DateTime.now().toUtc().toIso8601String(),
    );
  }

  ProductVariantModel copyWith({
    String? variantId,
    String? productId,
    String? size,
    int? quantity,
    String? lastUpdated,
  }) {
    return ProductVariantModel(
      variantId: variantId ?? this.variantId,
      productId: productId ?? this.productId,
      size: size ?? this.size,
      quantity: quantity ?? this.quantity,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
