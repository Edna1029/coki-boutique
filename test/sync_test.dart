import 'dart:convert';

import 'package:coki_boutique/data/database/database_helper.dart';
import 'package:coki_boutique/data/database/tables.dart';
import 'package:coki_boutique/data/services/sqlite_service.dart';
import 'package:coki_boutique/data/sync/remote_apply.dart';
import 'package:coki_boutique/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_db.dart';

/// Multi-device sync, local side: what gets queued for upload, and how
/// downloaded cloud documents are applied.
void main() {
  late SQLiteService db;
  late Database raw;

  setUp(() async {
    await useFreshTestDatabase();
    db = SQLiteService();
    raw = await DatabaseHelper.instance.database;
  });

  tearDown(DatabaseHelper.resetForTest);

  Future<List<Map<String, dynamic>>> queue() async => [
        for (final i in await db.getPendingSyncQueue())
          {
            'table': i.tableName,
            'id': i.recordId,
            'op': i.operation,
            ...jsonDecode(i.payload) as Map<String, dynamic>,
          }
      ];

  Future<ApplyResult> applyCloud(String collection, String id, Map<String, dynamic> data) =>
      raw.transaction((txn) => RemoteApply.apply(txn, collection, id, data));

  /// Simulates "everything queued so far has reached the cloud".
  Future<void> markAllUploaded() async {
    for (final i in await db.getPendingSyncQueue()) {
      await db.markSyncItemCompleted(i.queueId);
    }
  }

  group('what is queued for upload', () {
    test('a sale uploads the receipt WITH its items, and stock as a −n change', () async {
      final p = await addTestProduct(db, sizes: {'M': 5});
      final variantId = p.variants.single.variantId;
      final before = (await queue()).length;

      await sell(db, [line(p, 'M', 2)]);
      final q = (await queue()).skip(before).toList();

      final saleEntry = q.firstWhere((e) => e['table'] == DatabaseTables.tableSales);
      expect(saleEntry['op'], SyncOperation.insert);
      expect((saleEntry['items'] as List).single['quantity'], 2);

      final stockEntry = q.firstWhere((e) => e['table'] == DatabaseTables.tableProductVariants);
      expect(stockEntry['op'], SyncOperation.increment);
      expect(stockEntry['id'], variantId);
      expect(stockEntry['field'], 'quantity');
      expect(stockEntry['delta'], -2, reason: 'a CHANGE, never the new total');
    });

    test('restocking an existing size uploads +n, not the new total', () async {
      await addTestProduct(db, sizes: {'M': 5});
      final before = (await queue()).length;
      await addTestProduct(db, sizes: {'M': 3});
      final stock = (await queue()).skip(before).where((e) => e['op'] == SyncOperation.increment).single;
      expect(stock['delta'], 3);
    });

    test('a new credit with a deposit uploads the credit AND the deposit payment', () async {
      await db.createCreditSale(
        customerName: 'A', phoneNumber: '1', productsDescription: 'x', totalQuantity: 1,
        totalAmountOwed: 1000, initialDeposit: 400,
        dueDate: DateTime.now().toUtc().toIso8601String(), employeeId: 't', employeeName: 'T',
      );
      final q = await queue();
      expect(q.where((e) => e['table'] == DatabaseTables.tableCreditSales).single['amount_paid'], 400);
      expect(q.where((e) => e['table'] == DatabaseTables.tablePayments).single['amount_paid'], 400);
      expect(q.where((e) => e['op'] == SyncOperation.increment), isEmpty,
          reason: 'the deposit is already in the credit record; adding it again would double-count');
    });

    test('a later payment uploads the payment and +amount on the credit', () async {
      final c = await db.createCreditSale(
        customerName: 'A', phoneNumber: '1', productsDescription: 'x', totalQuantity: 1,
        totalAmountOwed: 1000, initialDeposit: 0,
        dueDate: DateTime.now().toUtc().toIso8601String(), employeeId: 't', employeeName: 'T',
      );
      final before = (await queue()).length;
      await db.recordCreditPayment(creditId: c.creditId, paymentAmount: 250, employeeId: 't', employeeName: 'T');
      final q = (await queue()).skip(before).toList();
      expect(q.where((e) => e['table'] == DatabaseTables.tablePayments).single['amount_paid'], 250);
      final inc = q.singleWhere((e) => e['op'] == SyncOperation.increment);
      expect(inc['field'], 'amount_paid');
      expect(inc['delta'], 250);
    });

    test('deleting a product also deletes its sizes in the cloud', () async {
      final p = await addTestProduct(db, sizes: {'S': 1, 'M': 1});
      final before = (await queue()).length;
      await db.deleteProduct(p.productId);
      final deletes = (await queue()).skip(before).where((e) => e['op'] == SyncOperation.delete).toList();
      expect(deletes.where((e) => e['table'] == DatabaseTables.tableProductVariants).length, 2);
      expect(deletes.where((e) => e['table'] == DatabaseTables.tableProducts).length, 1);
    });

    test('queue keeps insertion order even within the same millisecond', () async {
      final p = await addTestProduct(db, sizes: {'S': 1, 'M': 1, 'L': 1});
      final q = await queue();
      expect(q.first['table'], DatabaseTables.tableProducts, reason: 'product before its sizes');
      expect(q.first['id'], p.productId);
    });
  });

  group('applying downloaded data', () {
    Map<String, dynamic> productDoc(String id) => {
          'product_id': id, 'product_name': 'Cloud Shirt', 'sku': 'C1', 'barcode': '2999', 'qr_code': 'QR-2999',
          'category': 'Shirts', 'brand': 'B', 'color': 'Red', 'gender': 'men', 'price': 300.0, 'product_image': '',
          'date_added': '2026-11-08T00:00:00Z', 'last_updated': '2026-11-08T00:00:00Z',
        };

    test('a product and its size from another device appear locally', () async {
      expect(await applyCloud('products', 'p1', productDoc('p1')), ApplyResult.applied);
      expect(
        await applyCloud('product_variants', 'v1',
            {'variant_id': 'v1', 'product_id': 'p1', 'size': 'M', 'quantity': 7, 'last_updated': 'x'}),
        ApplyResult.applied,
      );
      final p = await db.getProductById('p1');
      expect(p!.productName, 'Cloud Shirt');
      expect(p.stockForSize('M'), 7);
    });

    test('a size arriving before its product is deferred, then applies', () async {
      final size = {'variant_id': 'v1', 'product_id': 'p1', 'size': 'M', 'quantity': 7, 'last_updated': 'x'};
      expect(await applyCloud('product_variants', 'v1', size), ApplyResult.deferred);
      await applyCloud('products', 'p1', productDoc('p1'));
      expect(await applyCloud('product_variants', 'v1', size), ApplyResult.applied);
    });

    test('cloud stock + this device\'s unsent sales = correct local stock', () async {
      // This device has 5 in M and sells 2 offline (−2 still waiting to upload).
      final p = await addTestProduct(db, sizes: {'M': 5});
      final v = p.variants.single;
      await markAllUploaded(); // the product itself reached the cloud earlier
      await sell(db, [line(p, 'M', 2)]);
      // Meanwhile another device sold 1; the cloud says 4 (it only knows that sale
      // plus our initial +5... ), i.e. 5 − 1 = 4.
      await applyCloud('product_variants', v.variantId,
          {'variant_id': v.variantId, 'product_id': p.productId, 'size': 'M', 'quantity': 4, 'last_updated': 'x'});
      // Correct answer: 5 − 1 (other device) − 2 (us) = 2.
      expect((await db.getProductById(p.productId))!.stockForSize('M'), 2);
    });

    test('a pending local edit is not overwritten by older cloud data', () async {
      final p = await addTestProduct(db, sizes: {'M': 1});
      await db.updateProduct(
        productId: p.productId, name: 'My New Name', sku: '', category: p.category, brand: p.brand,
        color: p.color, gender: p.gender, price: p.price, image: '', sizeQuantities: const {},
      );
      await applyCloud('products', p.productId, {...productDoc(p.productId), 'product_name': 'Old Cloud Name'});
      expect((await db.getProductById(p.productId))!.productName, 'My New Name');
    });

    test('updating a product from the cloud does NOT wipe its sizes', () async {
      await applyCloud('products', 'p1', productDoc('p1'));
      await applyCloud('product_variants', 'v1',
          {'variant_id': 'v1', 'product_id': 'p1', 'size': 'M', 'quantity': 3, 'last_updated': 'x'});
      await applyCloud('products', 'p1', {...productDoc('p1'), 'price': 350.0});
      final p = await db.getProductById('p1');
      expect(p!.price, 350);
      expect(p.stockForSize('M'), 3);
    });

    test('a product deleted on another device is removed here, with its sizes', () async {
      await applyCloud('products', 'p1', productDoc('p1'));
      await applyCloud('product_variants', 'v1',
          {'variant_id': 'v1', 'product_id': 'p1', 'size': 'M', 'quantity': 3, 'last_updated': 'x'});
      await applyCloud('products', 'p1', {'deleted': true});
      expect(await db.getProductById('p1'), isNull);
      expect(await raw.query(DatabaseTables.tableProductVariants), isEmpty);
    });

    test('a sale from another device is added once, with its items', () async {
      final sale = {
        'sale_id': 's1', 'subtotal': 200.0, 'tax_amount': 0.0, 'total_amount': 200.0, 'employee_id': 'e',
        'employee_name': 'E', 'date': '2026-11-08T10:00:00Z', 'payment_method': 'cash',
        'items': [
          {'sale_item_id': 'i1', 'sale_id': 's1', 'product_id': 'p1', 'product_name': 'X', 'size': 'M',
           'quantity': 2, 'unit_price': 100.0, 'total_amount': 200.0},
        ],
      };
      expect(await applyCloud('sales', 's1', sale), ApplyResult.applied);
      expect(await applyCloud('sales', 's1', sale), ApplyResult.skipped, reason: 'idempotent');
      final sales = await db.getAllSales();
      expect(sales.single.items.single.quantity, 2);
    });

    test('credit balance and status are derived from owed − paid (+ unsent payments)', () async {
      final c = await db.createCreditSale(
        customerName: 'A', phoneNumber: '1', productsDescription: 'x', totalQuantity: 1,
        totalAmountOwed: 1000, initialDeposit: 0,
        dueDate: '2026-12-01T00:00:00Z', employeeId: 't', employeeName: 'T',
      );
      await markAllUploaded(); // the credit itself reached the cloud earlier
      await db.recordCreditPayment(creditId: c.creditId, paymentAmount: 300, employeeId: 't', employeeName: 'T');
      // Cloud has only another device's 200 so far (and a stale balance field).
      await applyCloud('credit_sales', c.creditId, {
        ...c.toMap(), 'amount_paid': 200.0, 'remaining_balance': 999.0, 'status': 'pending',
      });
      final after = (await db.getAllCreditSales()).single;
      expect(after.amountPaid, 500, reason: '200 (cloud) + 300 (ours, unsent)');
      expect(after.remainingBalance, 500);
      expect(after.status, CreditStatus.partiallyPaid);
    });

    test('a payment arriving before its credit is deferred', () async {
      expect(
        await applyCloud('payments', 'pay1', {
          'payment_id': 'pay1', 'credit_id': 'missing', 'payment_date': 'x', 'amount_paid': 10.0,
          'employee_id': 'e', 'employee_name': 'E',
        }),
        ApplyResult.deferred,
      );
    });

    test('downloaded data is never queued for upload again', () async {
      await applyCloud('products', 'p1', productDoc('p1'));
      expect(await db.pendingSyncCount(), 0);
    });
  });
}
