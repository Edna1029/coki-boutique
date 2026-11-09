import '../models/credit_sale_model.dart';
import '../services/sqlite_service.dart';

class CreditRepository {
  final SQLiteService _sqliteService;

  CreditRepository({SQLiteService? sqliteService})
      : _sqliteService = sqliteService ?? SQLiteService();

  Future<List<CreditSaleModel>> getCreditSales() async {
    return await _sqliteService.getAllCreditSales();
  }

  Future<CreditSaleModel> addCreditSale({
    required String customerName,
    required String phoneNumber,
    required String productsDescription,
    required int totalQuantity,
    required double totalAmountOwed,
    required double initialDeposit,
    required String dueDate,
    required String employeeId,
    required String employeeName,
  }) async {
    return await _sqliteService.createCreditSale(
      customerName: customerName,
      phoneNumber: phoneNumber,
      productsDescription: productsDescription,
      totalQuantity: totalQuantity,
      totalAmountOwed: totalAmountOwed,
      initialDeposit: initialDeposit,
      dueDate: dueDate,
      employeeId: employeeId,
      employeeName: employeeName,
    );
  }

  Future<CreditSaleModel> recordPayment({
    required String creditId,
    required double paymentAmount,
    required String employeeId,
    required String employeeName,
    String? note,
  }) async {
    return await _sqliteService.recordCreditPayment(
      creditId: creditId,
      paymentAmount: paymentAmount,
      employeeId: employeeId,
      employeeName: employeeName,
      note: note,
    );
  }
}
