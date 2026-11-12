import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product_model.dart';
import '../models/product_variant_model.dart';
import '../models/sale_model.dart';
import '../models/credit_sale_model.dart';
import '../../core/utils/date_formatter.dart';

class ExcelExportService {
  /// Every size found in [products] (upper-cased, no duplicates), in shop
  /// order: XS…XXXL first, anything else after, alphabetically.
  static List<String> inventorySizeColumns(List<ProductModel> products) {
    final seen = <String, ProductVariantModel>{};
    for (final p in products) {
      for (final v in p.variants) {
        seen.putIfAbsent(v.size.toUpperCase(), () => v);
      }
    }
    return ProductModel.sortedBySize(seen.values.toList()).map((v) => v.size.toUpperCase()).toList();
  }

  /// Generates Inventory.xlsx
  static Future<File> exportInventoryExcel(List<ProductModel> products) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Inventory'];
    excel.delete('Sheet1');

    // One column per size that actually exists in the shop (XS, XXXL, shoe
    // sizes…), in shop order — not a fixed S–XXL list.
    final sizes = inventorySizeColumns(products);

    // Header Row
    sheet.appendRow([
      TextCellValue('Product ID'),
      TextCellValue('Product Name'),
      TextCellValue('SKU'),
      TextCellValue('Category'),
      TextCellValue('Brand'),
      TextCellValue('Color'),
      TextCellValue('Gender'),
      TextCellValue('Price (ETB)'),
      for (final s in sizes) TextCellValue('Size $s'),
      TextCellValue('Total Stock'),
      TextCellValue('Last Updated'),
    ]);

    for (final p in products) {
      sheet.appendRow([
        TextCellValue(p.productId),
        TextCellValue(p.productName),
        TextCellValue(p.sku),
        TextCellValue(p.category),
        TextCellValue(p.brand),
        TextCellValue(p.color),
        TextCellValue(p.gender.name.toUpperCase()),
        DoubleCellValue(p.price),
        for (final s in sizes) IntCellValue(p.stockForSize(s)),
        IntCellValue(p.totalStock),
        TextCellValue(DateFormatter.formatIsoDate(p.lastUpdated)),
      ]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Inventory.xlsx');
    final fileBytes = excel.save();
    if (fileBytes != null) {
      await file.writeAsBytes(fileBytes);
    }
    return file;
  }

  /// Generates Sales.xlsx
  static Future<File> exportSalesExcel(List<SaleModel> sales) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Sales'];
    excel.delete('Sheet1');

    // Header Row
    sheet.appendRow([
      TextCellValue('Sale ID'),
      TextCellValue('Date'),
      TextCellValue('Employee'),
      TextCellValue('Customer Name'),
      TextCellValue('Customer Phone'),
      TextCellValue('Payment Method'),
      TextCellValue('Total Items'),
      TextCellValue('Subtotal (ETB)'),
      TextCellValue('Tax (ETB)'),
      TextCellValue('Total Amount (ETB)'),
    ]);

    for (final s in sales) {
      sheet.appendRow([
        TextCellValue(s.saleId),
        TextCellValue(DateFormatter.formatIsoDate(s.date)),
        TextCellValue(s.employeeName),
        TextCellValue(s.customerName ?? 'Walk-in'),
        TextCellValue(s.customerPhone ?? 'N/A'),
        TextCellValue(s.paymentMethod.toUpperCase()),
        IntCellValue(s.totalItemCount),
        DoubleCellValue(s.subtotal),
        DoubleCellValue(s.taxAmount),
        DoubleCellValue(s.totalAmount),
      ]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Sales.xlsx');
    final fileBytes = excel.save();
    if (fileBytes != null) {
      await file.writeAsBytes(fileBytes);
    }
    return file;
  }

  /// Generates CreditSales.xlsx
  static Future<File> exportCreditSalesExcel(List<CreditSaleModel> creditSales) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['CreditSales'];
    excel.delete('Sheet1');

    // Header Row
    sheet.appendRow([
      TextCellValue('Credit ID'),
      TextCellValue('Customer Name'),
      TextCellValue('Phone Number'),
      TextCellValue('Items Summary'),
      TextCellValue('Total Owed (ETB)'),
      TextCellValue('Amount Paid (ETB)'),
      TextCellValue('Remaining Balance (ETB)'),
      TextCellValue('Due Date'),
      TextCellValue('Date Created'),
      TextCellValue('Status'),
    ]);

    for (final c in creditSales) {
      sheet.appendRow([
        TextCellValue(c.creditId),
        TextCellValue(c.customerName),
        TextCellValue(c.phoneNumber),
        TextCellValue(c.productsDescription),
        DoubleCellValue(c.totalAmountOwed),
        DoubleCellValue(c.amountPaid),
        DoubleCellValue(c.remainingBalance),
        TextCellValue(DateFormatter.formatIsoDate(c.dueDate)),
        TextCellValue(DateFormatter.formatIsoDate(c.dateCreated)),
        TextCellValue(c.status.name.toUpperCase()),
      ]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/CreditSales.xlsx');
    final fileBytes = excel.save();
    if (fileBytes != null) {
      await file.writeAsBytes(fileBytes);
    }
    return file;
  }
}
