import '../../domain/entities/enums.dart';
import 'product_variant_model.dart';

class ProductModel {
  final String productId;
  final String productName;
  final String sku;
  final String barcode;
  final String qrCode;
  final String category;
  final String brand;
  final String color;
  final Gender gender;
  final double price;
  final String productImage;
  final String dateAdded;
  final String lastUpdated;
  final List<ProductVariantModel> variants;

  ProductModel({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.barcode,
    required this.qrCode,
    required this.category,
    required this.brand,
    required this.color,
    required this.gender,
    required this.price,
    required this.productImage,
    required this.dateAdded,
    required this.lastUpdated,
    this.variants = const [],
  });

  /// Units on the shelf. A size can go below zero when two offline devices
  /// both sold its last unit; that counts as 0 here (see [oversoldUnits]),
  /// so it doesn't hide stock of the other sizes.
  int get totalStock => variants.fold(0, (sum, v) => sum + (v.quantity > 0 ? v.quantity : 0));

  /// How many units were sold beyond what was in stock (0 normally).
  /// When above 0 the shelf must be recounted and the stock corrected.
  int get oversoldUnits => variants.fold(0, (sum, v) => sum + (v.quantity < 0 ? -v.quantity : 0));

  int stockForSize(String size) {
    final v = variants.firstWhere(
      (element) => element.size.toUpperCase() == size.toUpperCase(),
      orElse: () => ProductVariantModel(
        variantId: '',
        productId: productId,
        size: size,
        quantity: 0,
        lastUpdated: '',
      ),
    );
    return v.quantity;
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'sku': sku,
      'barcode': barcode,
      'qr_code': qrCode,
      'category': category,
      'brand': brand,
      'color': color,
      'gender': gender.name,
      'price': price,
      'product_image': productImage,
      'date_added': dateAdded,
      'last_updated': lastUpdated,
    };
  }

  factory ProductModel.fromMap(
    Map<String, dynamic> map, {
    List<ProductVariantModel> variants = const [],
  }) {
    return ProductModel(
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? '',
      sku: map['sku'] ?? '',
      barcode: map['barcode'] ?? '',
      qrCode: map['qr_code'] ?? '',
      category: map['category'] ?? '',
      brand: map['brand'] ?? '',
      color: map['color'] ?? '',
      gender: Gender.fromString(map['gender'] ?? 'unisex'),
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      productImage: map['product_image'] ?? '',
      dateAdded: map['date_added'] ?? DateTime.now().toUtc().toIso8601String(),
      lastUpdated: map['last_updated'] ?? DateTime.now().toUtc().toIso8601String(),
      variants: sortedBySize(variants),
    );
  }

  static const _sizeOrder = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];

  /// Sizes in shop order (S, M, L, XL, XXL), whatever order they were stored
  /// or synced in; unknown sizes go last, alphabetically.
  static List<ProductVariantModel> sortedBySize(List<ProductVariantModel> list) {
    int rank(String s) {
      final i = _sizeOrder.indexOf(s.toUpperCase());
      return i == -1 ? _sizeOrder.length : i;
    }

    return [...list]..sort((a, b) {
        final r = rank(a.size).compareTo(rank(b.size));
        return r != 0 ? r : a.size.compareTo(b.size);
      });
  }

  ProductModel copyWith({
    String? productId,
    String? productName,
    String? sku,
    String? barcode,
    String? qrCode,
    String? category,
    String? brand,
    String? color,
    Gender? gender,
    double? price,
    String? productImage,
    String? dateAdded,
    String? lastUpdated,
    List<ProductVariantModel>? variants,
  }) {
    return ProductModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      qrCode: qrCode ?? this.qrCode,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      color: color ?? this.color,
      gender: gender ?? this.gender,
      price: price ?? this.price,
      productImage: productImage ?? this.productImage,
      dateAdded: dateAdded ?? this.dateAdded,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      variants: variants ?? this.variants,
    );
  }
}
