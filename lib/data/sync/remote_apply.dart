import 'package:sqflite/sqflite.dart';
import '../database/tables.dart';
import '../services/sqlite_service.dart';

/// Result of applying one cloud document to the local database.
enum ApplyResult {
  applied,

  /// Ignored on purpose (already have it / local edit pending / unknown).
  skipped,

  /// Its parent record hasn't arrived yet (e.g. a size before its product).
  /// The caller should retry it after the next batch.
  deferred,
}

/// Applies documents downloaded from Firestore to the local SQLite database.
///
/// Pure database logic (no Firebase imports) so it can be unit-tested.
///
/// Rules (multi-device shop):
/// * Stock (`product_variants.quantity`) and credit `amount_paid` are
///   cumulative: the cloud value already includes every device's uploaded
///   changes, and this device's NOT-yet-uploaded changes are added on top.
/// * Other fields: the cloud value is applied unless this device has a pending
///   edit of the same record; that edit is uploaded later and "latest updated
///   timestamp wins" there (PRD §23).
/// * Sales and payments are add-only: inserted once, never modified.
/// * `deleted: true` removes the record locally.
/// * Rows are updated in place, never REPLACEd: a REPLACE deletes the row
///   first, which would cascade-delete its sizes / payments.
class RemoteApply {
  static const syncedCollections = [
    DatabaseTables.tableProducts,
    DatabaseTables.tableProductVariants,
    DatabaseTables.tableSales,
    DatabaseTables.tableCreditSales,
    DatabaseTables.tablePayments,
  ];

  static const _columns = <String, List<String>>{
    DatabaseTables.tableProducts: [
      'product_id', 'product_name', 'sku', 'barcode', 'qr_code', 'category', 'brand', 'color', 'gender', 'price',
      'product_image', 'date_added', 'last_updated',
    ],
    DatabaseTables.tableProductVariants: ['variant_id', 'product_id', 'size', 'quantity', 'last_updated'],
    DatabaseTables.tableSales: [
      'sale_id', 'subtotal', 'tax_amount', 'total_amount', 'employee_id', 'employee_name', 'customer_name',
      'customer_phone', 'date', 'payment_method',
    ],
    DatabaseTables.tableSaleItems: [
      'sale_item_id', 'sale_id', 'product_id', 'product_name', 'size', 'quantity', 'unit_price', 'total_amount',
    ],
    DatabaseTables.tableCreditSales: [
      'credit_id', 'customer_name', 'phone_number', 'products_description', 'total_quantity', 'total_amount_owed',
      'amount_paid', 'remaining_balance', 'due_date', 'date_created', 'status',
    ],
    DatabaseTables.tablePayments: [
      'payment_id', 'credit_id', 'payment_date', 'amount_paid', 'employee_id', 'employee_name', 'note',
    ],
  };

  static const _idColumn = {
    DatabaseTables.tableProducts: 'product_id',
    DatabaseTables.tableProductVariants: 'variant_id',
    DatabaseTables.tableSales: 'sale_id',
    DatabaseTables.tableCreditSales: 'credit_id',
    DatabaseTables.tablePayments: 'payment_id',
  };

  static Map<String, Object?> _only(String table, Map<String, dynamic> data) => {
        for (final c in _columns[table]!)
          if (data.containsKey(c)) c: data[c],
      };

  static Future<bool> _exists(DatabaseExecutor db, String table, String idCol, String id) async =>
      (await db.query(table, columns: [idCol], where: '$idCol = ?', whereArgs: [id], limit: 1)).isNotEmpty;

  /// Update-in-place if present, else insert. Never REPLACE (see class doc).
  static Future<void> _upsert(DatabaseExecutor db, String table, String id, Map<String, Object?> row) async {
    final idCol = _idColumn[table]!;
    final values = {...row, idCol: id};
    final updated = await db.update(table, values, where: '$idCol = ?', whereArgs: [id]);
    if (updated == 0) await db.insert(table, values);
  }

  static Future<ApplyResult> apply(
    DatabaseExecutor db,
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    final idCol = _idColumn[collection];
    if (idCol == null) return ApplyResult.skipped;

    // Soft delete from another device.
    if (data['deleted'] == true) {
      await db.delete(collection, where: '$idCol = ?', whereArgs: [id]);
      return ApplyResult.applied;
    }

    switch (collection) {
      case DatabaseTables.tableProducts:
        if (await SQLiteService.hasPendingOverwrite(db, collection, id)) return ApplyResult.skipped;
        await _upsert(db, collection, id, _only(collection, data));
        return ApplyResult.applied;

      case DatabaseTables.tableProductVariants:
        final productId = data['product_id'] as String?;
        if (productId == null) return ApplyResult.skipped;
        if (!await _exists(db, DatabaseTables.tableProducts, 'product_id', productId)) {
          return ApplyResult.deferred;
        }
        if (await SQLiteService.hasPendingOverwrite(db, collection, id)) return ApplyResult.skipped;
        final row = _only(collection, data);
        final cloudQty = (data['quantity'] as num?) ?? 0;
        final pending = await SQLiteService.pendingDelta(db, collection, id, 'quantity');
        row['quantity'] = (cloudQty + pending).round();
        await _upsert(db, collection, id, row);
        return ApplyResult.applied;

      case DatabaseTables.tableSales:
        if (await _exists(db, collection, idCol, id)) return ApplyResult.skipped; // add-only
        await db.insert(collection, {..._only(collection, data), idCol: id});
        final items = (data['items'] as List?) ?? const [];
        for (final raw in items) {
          final item = Map<String, dynamic>.from(raw as Map);
          await db.insert(
            DatabaseTables.tableSaleItems,
            {..._only(DatabaseTables.tableSaleItems, item), 'sale_id': id},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        return ApplyResult.applied;

      case DatabaseTables.tableCreditSales:
        if (await SQLiteService.hasPendingOverwrite(db, collection, id)) return ApplyResult.skipped;
        final row = _only(collection, data);
        final owed = (data['total_amount_owed'] as num?)?.toDouble() ?? 0;
        final cloudPaid = (data['amount_paid'] as num?)?.toDouble() ?? 0;
        final pending = (await SQLiteService.pendingDelta(db, collection, id, 'amount_paid')).toDouble();
        final paid = cloudPaid + pending;
        // Balance and status are always derived, never trusted from the cloud.
        final remaining = (owed - paid) <= 0.005 ? 0.0 : owed - paid;
        row['amount_paid'] = paid;
        row['remaining_balance'] = remaining;
        row['status'] = remaining <= 0 ? 'fullyPaid' : (paid > 0 ? 'partiallyPaid' : 'pending');
        await _upsert(db, collection, id, row);
        return ApplyResult.applied;

      case DatabaseTables.tablePayments:
        if (await _exists(db, collection, idCol, id)) return ApplyResult.skipped; // add-only
        final creditId = data['credit_id'] as String?;
        if (creditId == null) return ApplyResult.skipped;
        if (!await _exists(db, DatabaseTables.tableCreditSales, 'credit_id', creditId)) {
          return ApplyResult.deferred;
        }
        await db.insert(collection, {..._only(collection, data), idCol: id});
        return ApplyResult.applied;
    }
    return ApplyResult.skipped;
  }
}
