import '../models/sale_model.dart';
import '../services/sqlite_service.dart';

class SalesRepository {
  final SQLiteService _sqliteService;

  SalesRepository({SQLiteService? sqliteService})
      : _sqliteService = sqliteService ?? SQLiteService();

  Future<List<SaleModel>> getSales() async {
    return await _sqliteService.getAllSales();
  }

  Future<SaleModel> createSale({
    required List<SaleItemModel> items,
    required double subtotal,
    required double taxAmount,
    required double totalAmount,
    required String employeeId,
    required String employeeName,
    String? customerName,
    String? customerPhone,
    String paymentMethod = 'cash',
  }) async {
    return await _sqliteService.processSale(
      items: items,
      subtotal: subtotal,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      employeeId: employeeId,
      employeeName: employeeName,
      customerName: customerName,
      customerPhone: customerPhone,
      paymentMethod: paymentMethod,
    );
  }
}
