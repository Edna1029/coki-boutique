import '../models/product_model.dart';
import '../services/sqlite_service.dart';
import '../../domain/entities/enums.dart';

class InventoryRepository {
  final SQLiteService _sqliteService;

  InventoryRepository({SQLiteService? sqliteService})
      : _sqliteService = sqliteService ?? SQLiteService();

  Future<List<ProductModel>> getProducts() async {
    return await _sqliteService.getAllProducts();
  }

  Future<ProductModel?> getProductById(String id) async {
    return await _sqliteService.getProductById(id);
  }

  Future<ProductModel> saveProduct({
    required String name,
    required String sku,
    required String barcode,
    required String qrCode,
    required String category,
    required String brand,
    required String color,
    required Gender gender,
    required double price,
    required String image,
    required Map<String, int> sizeQuantities,
    String? existingProductId,
  }) async {
    if (existingProductId != null) {
      // Editing: overwrite details and set exact stock counts.
      return await _sqliteService.updateProduct(
        productId: existingProductId,
        name: name,
        sku: sku,
        barcode: barcode,
        qrCode: qrCode,
        category: category,
        brand: brand,
        color: color,
        gender: gender,
        price: price,
        image: image,
        sizeQuantities: sizeQuantities,
      );
    }
    // Adding: PRD Section 11 merge rule (quantities are added).
    return await _sqliteService.addOrUpdateProduct(
      name: name,
      sku: sku,
      barcode: barcode,
      qrCode: qrCode,
      category: category,
      brand: brand,
      color: color,
      gender: gender,
      price: price,
      image: image,
      sizeQuantities: sizeQuantities,
    );
  }

  Future<void> deleteProduct(String id) async {
    await _sqliteService.deleteProduct(id);
  }
}
