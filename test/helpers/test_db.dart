import 'package:coki_boutique/data/database/database_helper.dart';
import 'package:coki_boutique/data/models/product_model.dart';
import 'package:coki_boutique/data/models/sale_model.dart';
import 'package:coki_boutique/data/services/sqlite_service.dart';
import 'package:coki_boutique/domain/entities/enums.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Points the app's DatabaseHelper at a brand-new in-memory SQLite database.
/// Call in setUp(); every test then starts from an empty shop.
bool _ffiReady = false;

Future<void> useFreshTestDatabase() async {
  if (!_ffiReady) {
    // Desktop SQLite engine for tests (the app itself uses Android's).
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _ffiReady = true;
  }
  await DatabaseHelper.resetForTest();
  DatabaseHelper.pathOverride = inMemoryDatabasePath;
}

/// Adds a product the way the Add Product dialog does.
Future<ProductModel> addTestProduct(
  SQLiteService db, {
  String name = 'Test Shirt',
  String brand = 'Coki',
  String color = 'Blue',
  Gender gender = Gender.men,
  double price = 100,
  String barcode = '2000000000008',
  String sku = 'SKU-1',
  Map<String, int> sizes = const {'S': 2, 'M': 5},
}) {
  return db.addOrUpdateProduct(
    name: name,
    sku: sku,
    barcode: barcode,
    qrCode: 'QR-$barcode',
    category: 'Shirts',
    brand: brand,
    color: color,
    gender: gender,
    price: price,
    image: '',
    sizeQuantities: sizes,
  );
}

/// One cart line for processSale.
SaleItemModel line(ProductModel p, String size, int qty) => SaleItemModel(
      saleItemId: '',
      saleId: '',
      productId: p.productId,
      productName: p.productName,
      size: size,
      quantity: qty,
      unitPrice: p.price,
      totalAmount: p.price * qty,
    );

/// Sells [items] with no tax (keeps the arithmetic in tests obvious).
Future<SaleModel> sell(SQLiteService db, List<SaleItemModel> items) {
  final total = items.fold<double>(0, (s, i) => s + i.totalAmount);
  return db.processSale(
    items: items,
    subtotal: total,
    taxAmount: 0,
    totalAmount: total,
    employeeId: 'tester',
    employeeName: 'Tester',
  );
}
