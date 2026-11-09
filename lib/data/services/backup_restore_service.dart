import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import '../database/tables.dart';

class BackupRestoreService {
  /// Generates full database backup bundle (Owner only feature)
  static Future<File> createBackup() async {
    final db = await DatabaseHelper.instance.database;

    final users = await db.query(DatabaseTables.tableUsers);
    final products = await db.query(DatabaseTables.tableProducts);
    final variants = await db.query(DatabaseTables.tableProductVariants);
    final sales = await db.query(DatabaseTables.tableSales);
    final saleItems = await db.query(DatabaseTables.tableSaleItems);
    final creditSales = await db.query(DatabaseTables.tableCreditSales);
    final payments = await db.query(DatabaseTables.tablePayments);
    final settings = await db.query(DatabaseTables.tableSettings);

    final backupPayload = {
      'version': '1.0',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'store': 'Coki Boutique',
      'data': {
        DatabaseTables.tableUsers: users,
        DatabaseTables.tableProducts: products,
        DatabaseTables.tableProductVariants: variants,
        DatabaseTables.tableSales: sales,
        DatabaseTables.tableSaleItems: saleItems,
        DatabaseTables.tableCreditSales: creditSales,
        DatabaseTables.tablePayments: payments,
        DatabaseTables.tableSettings: settings,
      }
    };

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/coki_backup_$timestamp.json');
    await file.writeAsString(jsonEncode(backupPayload));
    return file;
  }

  /// Restores database from a validated backup file
  static Future<bool> restoreFromBackup(String jsonContent) async {
    try {
      final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
      if (!decoded.containsKey('data')) return false;

      final data = decoded['data'] as Map<String, dynamic>;
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        // Clear existing tables
        await txn.delete(DatabaseTables.tableSaleItems);
        await txn.delete(DatabaseTables.tableSales);
        await txn.delete(DatabaseTables.tablePayments);
        await txn.delete(DatabaseTables.tableCreditSales);
        await txn.delete(DatabaseTables.tableProductVariants);
        await txn.delete(DatabaseTables.tableProducts);

        // Restore tables
        for (final item in (data[DatabaseTables.tableProducts] as List? ?? [])) {
          await txn.insert(DatabaseTables.tableProducts, item as Map<String, dynamic>);
        }
        for (final item in (data[DatabaseTables.tableProductVariants] as List? ?? [])) {
          await txn.insert(DatabaseTables.tableProductVariants, item as Map<String, dynamic>);
        }
        for (final item in (data[DatabaseTables.tableSales] as List? ?? [])) {
          await txn.insert(DatabaseTables.tableSales, item as Map<String, dynamic>);
        }
        for (final item in (data[DatabaseTables.tableSaleItems] as List? ?? [])) {
          await txn.insert(DatabaseTables.tableSaleItems, item as Map<String, dynamic>);
        }
        for (final item in (data[DatabaseTables.tableCreditSales] as List? ?? [])) {
          await txn.insert(DatabaseTables.tableCreditSales, item as Map<String, dynamic>);
        }
        for (final item in (data[DatabaseTables.tablePayments] as List? ?? [])) {
          await txn.insert(DatabaseTables.tablePayments, item as Map<String, dynamic>);
        }
      });

      return true;
    } catch (e) {
      return false;
    }
  }
}
