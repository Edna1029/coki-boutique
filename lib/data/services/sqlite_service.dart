import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../database/tables.dart';
import '../models/product_model.dart';
import '../models/product_variant_model.dart';
import '../models/sale_model.dart';
import '../models/credit_sale_model.dart';
import '../models/payment_model.dart';
import '../models/sync_queue_item.dart';
import '../../core/utils/phone_number.dart';
import '../../domain/entities/enums.dart';

/// Thrown by [SQLiteService.processSale] when a line asks for more units than
/// are in stock. The whole sale is rolled back; nothing is recorded.
class InsufficientStockException implements Exception {
  final String productName;
  final String size;
  final int requested;
  final int available;

  const InsufficientStockException({
    required this.productName,
    required this.size,
    required this.requested,
    required this.available,
  });

  @override
  String toString() =>
      'Not enough stock for $productName (size $size): requested $requested, only $available left';
}

/// Why a credit payment / down payment was rejected. The UI maps these to
/// translated messages; nothing is written when one is thrown.
enum PaymentRejection { notPositive, exceedsBalance, alreadyPaid, depositExceedsTotal }

class InvalidPaymentException implements Exception {
  final PaymentRejection reason;

  /// The most that could have been accepted (remaining balance or total owed).
  final double maxAllowed;

  const InvalidPaymentException(this.reason, {this.maxAllowed = 0});

  @override
  String toString() => 'Invalid payment: ${reason.name} (max allowed $maxAllowed)';
}

/// Money is stored as doubles; treat differences under half a cent as equal.
const double _moneyEpsilon = 0.005;

class SQLiteService {
  final DatabaseHelper _dbHelper;
  SQLiteService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;
  static const _uuid = Uuid();

  // ==========================================
  // PRODUCTS & INVENTORY
  // ==========================================

  Future<List<ProductModel>> getAllProducts() async {
    final db = await _db;
    final productMaps = await db.query(DatabaseTables.tableProducts, orderBy: 'product_name ASC');
    final variantMaps = await db.query(DatabaseTables.tableProductVariants);

    final Map<String, List<ProductVariantModel>> variantMap = {};
    for (final v in variantMaps) {
      final variant = ProductVariantModel.fromMap(v);
      variantMap.putIfAbsent(variant.productId, () => []).add(variant);
    }

    return productMaps.map((p) {
      final pid = p['product_id'] as String;
      return ProductModel.fromMap(p, variants: variantMap[pid] ?? []);
    }).toList();
  }

  Future<ProductModel?> getProductById(String id) async {
    final db = await _db;
    final productMaps = await db.query(
      DatabaseTables.tableProducts,
      where: 'product_id = ?',
      whereArgs: [id],
    );
    if (productMaps.isEmpty) return null;

    final variantMaps = await db.query(
      DatabaseTables.tableProductVariants,
      where: 'product_id = ?',
      whereArgs: [id],
    );

    return ProductModel.fromMap(
      productMaps.first,
      variants: variantMaps.map((v) => ProductVariantModel.fromMap(v)).toList(),
    );
  }

  /// Finds the product whose barcode exactly matches [barcode], or null.
  /// Used for duplicate checks now and barcode scanning later.
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.tableProducts,
      columns: ['product_id'],
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return getProductById(rows.first['product_id'] as String);
  }

  /// Finds a product by any code a scanner or cashier might give: barcode,
  /// QR code, or SKU (exact match, SKU case-insensitive). Barcode wins if
  /// several match. Returns null if nothing matches.
  Future<ProductModel?> getProductByCode(String code) async {
    final c = code.trim();
    if (c.isEmpty) return null;
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT product_id FROM ${DatabaseTables.tableProducts} '
      'WHERE barcode = ? OR qr_code = ? OR UPPER(sku) = UPPER(?) '
      'ORDER BY CASE WHEN barcode = ? THEN 0 WHEN qr_code = ? THEN 1 ELSE 2 END '
      'LIMIT 1',
      [c, c, c, c, c],
    );
    if (rows.isEmpty) return null;
    return getProductById(rows.first['product_id'] as String);
  }

  /// ADDING stock (new product or new shipment). Implements PRD Section 11:
  /// if Name, Brand, Color, Gender (and Size) match an existing product variant,
  /// the given quantities are ADDED to it instead of creating a duplicate.
  ///
  /// To change an existing product's details or correct its stock counts,
  /// use [updateProduct] instead — it sets quantities rather than adding them.
  Future<ProductModel> addOrUpdateProduct({
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
    required Map<String, int> sizeQuantities, // e.g. {'S': 2, 'M': 5}
  }) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    return await db.transaction<ProductModel>((txn) async {
      String targetProductId = '';

      // Check if an existing product with same Name, Brand, Color, Gender exists
      final existing = await txn.query(
        DatabaseTables.tableProducts,
        where: 'LOWER(product_name) = ? AND LOWER(brand) = ? AND LOWER(color) = ? AND LOWER(gender) = ?',
        whereArgs: [name.toLowerCase(), brand.toLowerCase(), color.toLowerCase(), gender.name.toLowerCase()],
      );

      if (existing.isNotEmpty) {
        targetProductId = existing.first['product_id'] as String;
        // Update timestamp & price if changed
        await txn.update(
          DatabaseTables.tableProducts,
          {
            'price': price,
            'last_updated': now,
          },
          where: 'product_id = ?',
          whereArgs: [targetProductId],
        );
        await _enqueueSync(
          txn,
          DatabaseTables.tableProducts,
          targetProductId,
          SyncOperation.update,
          {'price': price, 'last_updated': now},
        );
      }

      if (targetProductId.isEmpty) {
        // Create brand new product
        targetProductId = _uuid.v4();
        final newProductMap = {
          'product_id': targetProductId,
          'product_name': name,
          'sku': sku.isNotEmpty ? sku : 'CK-${DateTime.now().millisecondsSinceEpoch % 10000}',
          'barcode': barcode,
          'qr_code': qrCode,
          'category': category,
          'brand': brand,
          'color': color,
          'gender': gender.name,
          'price': price,
          'product_image': image,
          'date_added': now,
          'last_updated': now,
        };
        await txn.insert(DatabaseTables.tableProducts, newProductMap);

        // Queue Sync
        await _enqueueSync(
          txn,
          DatabaseTables.tableProducts,
          targetProductId,
          SyncOperation.insert,
          newProductMap,
        );
      }

      // Process Variants for each size
      final List<ProductVariantModel> finalVariants = [];
      for (final entry in sizeQuantities.entries) {
        final size = entry.key;
        final qtyToAdd = entry.value;

        final existingVariant = await txn.query(
          DatabaseTables.tableProductVariants,
          where: 'product_id = ? AND UPPER(size) = ?',
          whereArgs: [targetProductId, size.toUpperCase()],
        );

        if (existingVariant.isNotEmpty) {
          final currentQty = existingVariant.first['quantity'] as int;
          final variantId = existingVariant.first['variant_id'] as String;
          final newQty = currentQty + qtyToAdd;

          await txn.update(
            DatabaseTables.tableProductVariants,
            {
              'quantity': newQty,
              'last_updated': now,
            },
            where: 'variant_id = ?',
            whereArgs: [variantId],
          );

          finalVariants.add(ProductVariantModel(
            variantId: variantId,
            productId: targetProductId,
            size: size,
            quantity: newQty,
            lastUpdated: now,
          ));

          // Restock = a CHANGE (+n), so restocks on two devices both count.
          if (qtyToAdd != 0) {
            await _enqueueIncrement(txn, DatabaseTables.tableProductVariants, variantId, 'quantity', qtyToAdd, now);
          }
        } else {
          final variantId = _uuid.v4();
          final variantMap = {
            'variant_id': variantId,
            'product_id': targetProductId,
            'size': size,
            'quantity': qtyToAdd,
            'last_updated': now,
          };
          await txn.insert(DatabaseTables.tableProductVariants, variantMap);

          finalVariants.add(ProductVariantModel.fromMap(variantMap));

          await _enqueueSync(
            txn,
            DatabaseTables.tableProductVariants,
            variantId,
            SyncOperation.insert,
            variantMap,
          );
        }
      }

      final updatedProduct = await txn.query(
        DatabaseTables.tableProducts,
        where: 'product_id = ?',
        whereArgs: [targetProductId],
      );

      return ProductModel.fromMap(updatedProduct.first, variants: finalVariants);
    });
  }

  /// EDITING an existing product. Overwrites its details and SETS each given
  /// size's stock to the exact quantity provided (it does not add to it).
  /// Sizes not present in [sizeQuantities] are left untouched.
  /// Barcode and QR code are preserved unless new non-empty values are given.
  Future<ProductModel> updateProduct({
    required String productId,
    required String name,
    required String sku,
    required String category,
    required String brand,
    required String color,
    required Gender gender,
    required double price,
    required String image,
    required Map<String, int> sizeQuantities,
    String? barcode,
    String? qrCode,
  }) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    return await db.transaction<ProductModel>((txn) async {
      final current = await txn.query(
        DatabaseTables.tableProducts,
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      if (current.isEmpty) {
        throw Exception('Product not found');
      }
      final old = current.first;

      final productMap = <String, Object?>{
        'product_name': name,
        'sku': sku.isNotEmpty ? sku : old['sku'],
        'barcode': (barcode != null && barcode.isNotEmpty) ? barcode : old['barcode'],
        'qr_code': (qrCode != null && qrCode.isNotEmpty) ? qrCode : old['qr_code'],
        'category': category,
        'brand': brand,
        'color': color,
        'gender': gender.name,
        'price': price,
        'product_image': image,
        'last_updated': now,
      };

      await txn.update(
        DatabaseTables.tableProducts,
        productMap,
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      await _enqueueSync(
        txn,
        DatabaseTables.tableProducts,
        productId,
        SyncOperation.update,
        productMap,
      );

      for (final entry in sizeQuantities.entries) {
        final size = entry.key;
        final newQty = entry.value < 0 ? 0 : entry.value;

        final existingVariant = await txn.query(
          DatabaseTables.tableProductVariants,
          where: 'product_id = ? AND UPPER(size) = ?',
          whereArgs: [productId, size.toUpperCase()],
        );

        if (existingVariant.isNotEmpty) {
          final variantId = existingVariant.first['variant_id'] as String;
          final oldQty = existingVariant.first['quantity'] as int;
          if (oldQty == newQty) continue;

          await txn.update(
            DatabaseTables.tableProductVariants,
            {'quantity': newQty, 'last_updated': now},
            where: 'variant_id = ?',
            whereArgs: [variantId],
          );
          await _enqueueSync(
            txn,
            DatabaseTables.tableProductVariants,
            variantId,
            SyncOperation.update,
            {'quantity': newQty, 'last_updated': now},
          );
        } else if (newQty > 0) {
          final variantId = _uuid.v4();
          final variantMap = {
            'variant_id': variantId,
            'product_id': productId,
            'size': size,
            'quantity': newQty,
            'last_updated': now,
          };
          await txn.insert(DatabaseTables.tableProductVariants, variantMap);
          await _enqueueSync(
            txn,
            DatabaseTables.tableProductVariants,
            variantId,
            SyncOperation.insert,
            variantMap,
          );
        }
      }

      final updated = await txn.query(
        DatabaseTables.tableProducts,
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      final variants = await txn.query(
        DatabaseTables.tableProductVariants,
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      return ProductModel.fromMap(
        updated.first,
        variants: variants.map((v) => ProductVariantModel.fromMap(v)).toList(),
      );
    });
  }

  Future<void> deleteProduct(String productId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final variants = await txn.query(
        DatabaseTables.tableProductVariants,
        columns: ['variant_id'],
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      await txn.delete(
        DatabaseTables.tableProductVariants,
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      await txn.delete(
        DatabaseTables.tableProducts,
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      final now = DateTime.now().toUtc().toIso8601String();
      // Soft-delete the sizes too, so other devices don't keep orphan stock.
      for (final v in variants) {
        await _enqueueSync(txn, DatabaseTables.tableProductVariants, v['variant_id'] as String,
            SyncOperation.delete, {'last_updated': now});
      }
      await _enqueueSync(
        txn,
        DatabaseTables.tableProducts,
        productId,
        SyncOperation.delete,
        {'last_updated': now},
      );
    });
  }

  // ==========================================
  // SALES & POS
  // ==========================================

  Future<SaleModel> processSale({
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
    final db = await _db;
    return await db.transaction<SaleModel>((txn) => _recordSaleTxn(
          txn,
          items: items,
          subtotal: subtotal,
          taxAmount: taxAmount,
          totalAmount: totalAmount,
          employeeId: employeeId,
          employeeName: employeeName,
          customerName: customerName,
          customerPhone: customerPhone,
          paymentMethod: paymentMethod,
        ));
  }

  /// A POS sale paid on credit: the goods leave stock exactly like a normal
  /// sale (same stock check, same sync) AND a credit account is opened for the
  /// customer, linked by `sale_id`. One transaction — if either part fails
  /// (not enough stock, bad down payment) nothing at all is saved.
  Future<({SaleModel sale, CreditSaleModel credit})> processCreditSale({
    required List<SaleItemModel> items,
    required double subtotal,
    required double taxAmount,
    required double totalAmount,
    required String employeeId,
    required String employeeName,
    required String customerName,
    required String customerPhone,
    required double initialDeposit,
    required String dueDate,
  }) async {
    _validateNewCredit(totalAmount, initialDeposit);
    if (customerName.trim().isEmpty) {
      throw ArgumentError('Customer name is required for a credit sale');
    }
    if (!PhoneNumbers.isE164(customerPhone.trim())) {
      throw ArgumentError('A valid phone number (e.g. +251912345678) is required for a credit sale');
    }
    final db = await _db;
    return await db.transaction((txn) async {
      final sale = await _recordSaleTxn(
        txn,
        items: items,
        subtotal: subtotal,
        taxAmount: taxAmount,
        totalAmount: totalAmount,
        employeeId: employeeId,
        employeeName: employeeName,
        customerName: customerName.trim(),
        customerPhone: customerPhone.trim(),
        paymentMethod: 'credit',
      );
      final credit = await _recordCreditTxn(
        txn,
        customerName: customerName.trim(),
        phoneNumber: customerPhone.trim(),
        productsDescription: describeItems(items),
        totalQuantity: items.fold(0, (sum, i) => sum + i.quantity),
        totalAmountOwed: totalAmount,
        initialDeposit: initialDeposit,
        dueDate: dueDate,
        employeeId: employeeId,
        employeeName: employeeName,
        saleId: sale.saleId,
      );
      return (sale: sale, credit: credit);
    });
  }

  /// "Habesha Kemis (M) ×1, Silk Scarf (S) ×2" — shown on the credit card.
  static String describeItems(List<SaleItemModel> items) =>
      items.map((i) => '${i.productName} (${i.size}) ×${i.quantity}').join(', ');

  Future<SaleModel> _recordSaleTxn(
    Transaction txn, {
    required List<SaleItemModel> items,
    required double subtotal,
    required double taxAmount,
    required double totalAmount,
    required String employeeId,
    required String employeeName,
    String? customerName,
    String? customerPhone,
    required String paymentMethod,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final saleId = _uuid.v4();
    // 1. Validate stock for every line BEFORE writing anything. Quantities
    //    for the same product+size are summed in case they appear twice.
    //    Throwing here rolls back the whole transaction: no partial sale.
    final required = <String, int>{};
    final labels = <String, SaleItemModel>{};
    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError('Quantity must be positive for ${item.productName}');
      }
      final key = '${item.productId}|${item.size.toUpperCase()}';
      required[key] = (required[key] ?? 0) + item.quantity;
      labels[key] = item;
    }
    final variantIds = <String, String>{};
    for (final entry in required.entries) {
      final item = labels[entry.key]!;
      final variant = await txn.query(
        DatabaseTables.tableProductVariants,
        where: 'product_id = ? AND UPPER(size) = ?',
        whereArgs: [item.productId, item.size.toUpperCase()],
      );
      final available = variant.isEmpty ? 0 : variant.first['quantity'] as int;
      if (available < entry.value) {
        throw InsufficientStockException(
          productName: item.productName,
          size: item.size,
          requested: entry.value,
          available: available,
        );
      }
      variantIds[entry.key] = variant.first['variant_id'] as String;
    }

    // 2. Record the sale.
    final saleMap = {
      'sale_id': saleId,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'date': now,
      'payment_method': paymentMethod,
    };

    await txn.insert(DatabaseTables.tableSales, saleMap);

    final List<SaleItemModel> savedItems = [];
    final itemMaps = <Map<String, Object?>>[];
    final stockChanges = <String, int>{}; // variantId → units sold
    for (final item in items) {
      final itemId = _uuid.v4();
      final itemMap = {
        'sale_item_id': itemId,
        'sale_id': saleId,
        'product_id': item.productId,
        'product_name': item.productName,
        'size': item.size,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_amount': item.totalAmount,
      };
      await txn.insert(DatabaseTables.tableSaleItems, itemMap);
      savedItems.add(SaleItemModel.fromMap(itemMap));
      itemMaps.add(itemMap);

      // 3. Deduct stock. Already validated above, and the update itself is
      //    relative (quantity - n) so it can never go below what was checked.
      final variantId = variantIds['${item.productId}|${item.size.toUpperCase()}']!;
      await txn.rawUpdate(
        'UPDATE ${DatabaseTables.tableProductVariants} '
        'SET quantity = quantity - ?, last_updated = ? WHERE variant_id = ?',
        [item.quantity, now, variantId],
      );
      stockChanges[variantId] = (stockChanges[variantId] ?? 0) + item.quantity;
    }

    // Sync: the sale (with its line items embedded) is an add-only record;
    // stock is uploaded as CHANGES (−n) so sales on several devices all count.
    await _enqueueSync(
      txn,
      DatabaseTables.tableSales,
      saleId,
      SyncOperation.insert,
      {...saleMap, 'items': itemMaps},
    );
    for (final e in stockChanges.entries) {
      await _enqueueIncrement(txn, DatabaseTables.tableProductVariants, e.key, 'quantity', -e.value, now);
    }

    return SaleModel(
      saleId: saleId,
      items: savedItems,
      subtotal: subtotal,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      employeeId: employeeId,
      employeeName: employeeName,
      customerName: customerName,
      customerPhone: customerPhone,
      date: now,
      paymentMethod: paymentMethod,
    );
  }

  Future<List<SaleModel>> getAllSales() async {
    final db = await _db;
    final sales = await db.query(DatabaseTables.tableSales, orderBy: 'date DESC');
    final items = await db.query(DatabaseTables.tableSaleItems);

    final Map<String, List<SaleItemModel>> itemMap = {};
    for (final i in items) {
      final item = SaleItemModel.fromMap(i);
      itemMap.putIfAbsent(item.saleId, () => []).add(item);
    }

    return sales.map((s) {
      final sid = s['sale_id'] as String;
      return SaleModel.fromMap(s, items: itemMap[sid] ?? []);
    }).toList();
  }

  // ==========================================
  // CREDIT SALES & PAYMENTS
  // ==========================================

  Future<List<CreditSaleModel>> getAllCreditSales() async {
    final db = await _db;
    final credits = await db.query(DatabaseTables.tableCreditSales, orderBy: 'date_created DESC');
    final payments = await db.query(DatabaseTables.tablePayments, orderBy: 'payment_date DESC');

    final Map<String, List<PaymentModel>> paymentMap = {};
    for (final p in payments) {
      final payment = PaymentModel.fromMap(p);
      paymentMap.putIfAbsent(payment.creditId, () => []).add(payment);
    }

    return credits.map((c) {
      final cid = c['credit_id'] as String;
      return CreditSaleModel.fromMap(c, payments: paymentMap[cid] ?? []);
    }).toList();
  }

  Future<CreditSaleModel> createCreditSale({
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
    _validateNewCredit(totalAmountOwed, initialDeposit);
    final db = await _db;
    return await db.transaction<CreditSaleModel>((txn) => _recordCreditTxn(
          txn,
          customerName: customerName,
          phoneNumber: phoneNumber,
          productsDescription: productsDescription,
          totalQuantity: totalQuantity,
          totalAmountOwed: totalAmountOwed,
          initialDeposit: initialDeposit,
          dueDate: dueDate,
          employeeId: employeeId,
          employeeName: employeeName,
        ));
  }

  /// Rejects owed ≤ 0, a negative down payment, or one larger than the total.
  void _validateNewCredit(double totalAmountOwed, double initialDeposit) {
    if (totalAmountOwed <= 0) {
      throw const InvalidPaymentException(PaymentRejection.notPositive);
    }
    if (initialDeposit < 0) {
      throw const InvalidPaymentException(PaymentRejection.notPositive);
    }
    if (initialDeposit > totalAmountOwed + _moneyEpsilon) {
      throw InvalidPaymentException(PaymentRejection.depositExceedsTotal, maxAllowed: totalAmountOwed);
    }
  }

  Future<CreditSaleModel> _recordCreditTxn(
    Transaction txn, {
    required String customerName,
    required String phoneNumber,
    required String productsDescription,
    required int totalQuantity,
    required double totalAmountOwed,
    required double initialDeposit,
    required String dueDate,
    required String employeeId,
    required String employeeName,
    String? saleId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final creditId = _uuid.v4();
    final remaining = (totalAmountOwed - initialDeposit).clamp(0.0, totalAmountOwed);
    final status = remaining <= 0
        ? CreditStatus.fullyPaid
        : (initialDeposit > 0 ? CreditStatus.partiallyPaid : CreditStatus.pending);

    final creditMap = {
      'credit_id': creditId,
      'customer_name': customerName,
      'phone_number': phoneNumber,
      'products_description': productsDescription,
      'total_quantity': totalQuantity,
      'total_amount_owed': totalAmountOwed,
      'amount_paid': initialDeposit,
      'remaining_balance': remaining,
      'due_date': dueDate,
      'date_created': now,
      'status': status.name,
      'sale_id': saleId,
    };

    await txn.insert(DatabaseTables.tableCreditSales, creditMap);

    // Credit record first (it already includes the deposit in amount_paid),
    // then the deposit's payment record — which must NOT add again.
    await _enqueueSync(
      txn,
      DatabaseTables.tableCreditSales,
      creditId,
      SyncOperation.insert,
      {...creditMap, 'last_updated': now},
    );

    final List<PaymentModel> payments = [];
    if (initialDeposit > 0) {
      final paymentId = _uuid.v4();
      final paymentMap = {
        'payment_id': paymentId,
        'credit_id': creditId,
        'payment_date': now,
        'amount_paid': initialDeposit,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'note': 'Initial Down Payment',
      };
      await txn.insert(DatabaseTables.tablePayments, paymentMap);
      payments.add(PaymentModel.fromMap(paymentMap));
      await _enqueueSync(txn, DatabaseTables.tablePayments, paymentId, SyncOperation.insert, paymentMap);
    }

    return CreditSaleModel.fromMap(creditMap, payments: payments);
  }

  /// Implements PRD Section 17 Automatic Completion Logic:
  /// When Remaining Balance reaches 0, system automatically marks Fully Paid
  Future<CreditSaleModel> recordCreditPayment({
    required String creditId,
    required double paymentAmount,
    required String employeeId,
    required String employeeName,
    String? note,
  }) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    return await db.transaction<CreditSaleModel>((txn) async {
      final creditResult = await txn.query(
        DatabaseTables.tableCreditSales,
        where: 'credit_id = ?',
        whereArgs: [creditId],
      );

      if (creditResult.isEmpty) {
        throw Exception('Credit record not found');
      }

      final current = CreditSaleModel.fromMap(creditResult.first);

      // Validate inside the transaction against the CURRENT balance, so a
      // stale dialog can't push amount_paid past what's owed.
      if (paymentAmount <= 0) {
        throw const InvalidPaymentException(PaymentRejection.notPositive);
      }
      if (current.remainingBalance <= _moneyEpsilon) {
        throw const InvalidPaymentException(PaymentRejection.alreadyPaid);
      }
      if (paymentAmount > current.remainingBalance + _moneyEpsilon) {
        throw InvalidPaymentException(
          PaymentRejection.exceedsBalance,
          maxAllowed: current.remainingBalance,
        );
      }

      // Paying (within half a cent of) the full balance settles it exactly.
      final settles = (current.remainingBalance - paymentAmount).abs() <= _moneyEpsilon;
      final newAmountPaid = settles ? current.totalAmountOwed : current.amountPaid + paymentAmount;
      final newRemaining = settles ? 0.0 : current.totalAmountOwed - newAmountPaid;

      final newStatus = newRemaining <= 0
          ? CreditStatus.fullyPaid
          : CreditStatus.partiallyPaid;

      await txn.update(
        DatabaseTables.tableCreditSales,
        {
          'amount_paid': newAmountPaid,
          'remaining_balance': newRemaining,
          'status': newStatus.name,
        },
        where: 'credit_id = ?',
        whereArgs: [creditId],
      );

      final paymentId = _uuid.v4();
      final paymentMap = {
        'payment_id': paymentId,
        'credit_id': creditId,
        'payment_date': now,
        'amount_paid': paymentAmount,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'note': note ?? 'Installment Payment',
      };
      await txn.insert(DatabaseTables.tablePayments, paymentMap);

      // Sync: the payment is an add-only record; the credit's amount_paid goes
      // up as a CHANGE, so payments taken on two devices both count.
      // (Balance and status are derived from owed − paid on every device.)
      await _enqueueSync(txn, DatabaseTables.tablePayments, paymentId, SyncOperation.insert, paymentMap);
      await _enqueueIncrement(
        txn,
        DatabaseTables.tableCreditSales,
        creditId,
        'amount_paid',
        newAmountPaid - current.amountPaid,
        now,
      );

      final allPayments = await txn.query(
        DatabaseTables.tablePayments,
        where: 'credit_id = ?',
        whereArgs: [creditId],
      );

      return current.copyWith(
        amountPaid: newAmountPaid,
        remainingBalance: newRemaining,
        status: newStatus,
        payments: allPayments.map((p) => PaymentModel.fromMap(p)).toList(),
      );
    });
  }

  // ==========================================
  // SYNC QUEUE HELPER
  // ==========================================

  /// Called after local data changes are queued for upload, so the sync
  /// service can push them promptly. Set by SyncService; null in tests.
  static void Function()? onLocalChange;

  Future<void> _enqueueSync(
    DatabaseExecutor txn,
    String tableName,
    String recordId,
    SyncOperation operation,
    Map<String, dynamic> data,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await txn.insert(DatabaseTables.tableSyncQueue, {
      'queue_id': _uuid.v4(),
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation.name,
      'payload': jsonEncode(data),
      'timestamp': now,
      'retry_count': 0,
      'status': 'pending',
    });
    onLocalChange?.call();
  }

  /// Queues "add [delta] to [field]" for a record (stock, amount paid).
  Future<void> _enqueueIncrement(
    DatabaseExecutor txn,
    String tableName,
    String recordId,
    String field,
    num delta,
    String now,
  ) =>
      _enqueueSync(txn, tableName, recordId, SyncOperation.increment, {
        'field': field,
        'delta': delta,
        'last_updated': now,
      });

  /// Pending uploads, oldest first. Ordered by insertion (rowid), not by
  /// timestamp: several entries written in the same millisecond must still
  /// be sent in the order they were made.
  Future<List<SyncQueueItem>> getPendingSyncQueue() async {
    final db = await _db;
    final res = await db.query(
      DatabaseTables.tableSyncQueue,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'rowid ASC',
    );
    return res.map((m) => SyncQueueItem.fromMap(m)).toList();
  }

  Future<int> pendingSyncCount() async {
    final db = await _db;
    final r = await db.rawQuery(
      "SELECT COUNT(*) AS n FROM ${DatabaseTables.tableSyncQueue} WHERE status = 'pending'",
    );
    return (r.first['n'] as int?) ?? 0;
  }

  /// Sum of not-yet-uploaded increments for one record's field. When a newer
  /// value arrives from the cloud, these are added on top so local changes
  /// that haven't reached the cloud yet are not lost from the screen.
  static Future<num> pendingDelta(DatabaseExecutor db, String tableName, String recordId, String field) async {
    final rows = await db.query(
      DatabaseTables.tableSyncQueue,
      columns: ['payload'],
      where: 'status = ? AND table_name = ? AND record_id = ? AND operation = ?',
      whereArgs: ['pending', tableName, recordId, SyncOperation.increment.name],
    );
    num sum = 0;
    for (final r in rows) {
      final p = jsonDecode(r['payload'] as String) as Map<String, dynamic>;
      if (p['field'] == field) sum += (p['delta'] as num? ?? 0);
    }
    return sum;
  }

  /// True if this record has local changes (other than increments) that
  /// haven't been uploaded yet — remote values must not overwrite them.
  static Future<bool> hasPendingOverwrite(DatabaseExecutor db, String tableName, String recordId) async {
    final rows = await db.query(
      DatabaseTables.tableSyncQueue,
      columns: ['queue_id'],
      where: 'status = ? AND table_name = ? AND record_id = ? AND operation != ?',
      whereArgs: ['pending', tableName, recordId, SyncOperation.increment.name],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> markSyncItemCompleted(String queueId) async {
    final db = await _db;
    await db.update(
      DatabaseTables.tableSyncQueue,
      {'status': 'completed'},
      where: 'queue_id = ?',
      whereArgs: [queueId],
    );
  }

  Future<void> markSyncItemFailed(String queueId) async {
    final db = await _db;
    await db.rawUpdate(
      'UPDATE ${DatabaseTables.tableSyncQueue} SET retry_count = retry_count + 1 WHERE queue_id = ?',
      [queueId],
    );
  }

  /// Removes uploaded entries older than [keep] (the queue only needs history
  /// for debugging; completed entries are never re-sent).
  Future<void> purgeCompletedSync({Duration keep = const Duration(days: 7)}) async {
    final db = await _db;
    final cutoff = DateTime.now().toUtc().subtract(keep).toIso8601String();
    await db.delete(
      DatabaseTables.tableSyncQueue,
      where: 'status = ? AND timestamp < ?',
      whereArgs: ['completed', cutoff],
    );
  }
}
