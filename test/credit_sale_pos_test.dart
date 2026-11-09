import 'dart:convert';
import 'dart:io';

import 'package:coki_boutique/data/database/database_helper.dart';
import 'package:coki_boutique/data/database/tables.dart';
import 'package:coki_boutique/data/models/credit_sale_model.dart';
import 'package:coki_boutique/data/models/sale_model.dart';
import 'package:coki_boutique/data/services/sqlite_service.dart';
import 'package:coki_boutique/data/sync/remote_apply.dart';
import 'package:coki_boutique/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_db.dart';

/// Credit sales made from the POS cart (P2): goods leave stock like any sale,
/// and a credit account linked to that sale tracks what the customer owes.
void main() {
  late SQLiteService db;

  setUp(() async {
    await useFreshTestDatabase();
    db = SQLiteService();
  });

  tearDown(DatabaseHelper.resetForTest);

  Future<({SaleModel sale, CreditSaleModel credit})> sellOnCredit(
    List<SaleItemModel> items, {
    double deposit = 0,
    String name = 'Dawit',
    String phone = '+251900000000',
  }) {
    final total = items.fold<double>(0, (s, i) => s + i.totalAmount);
    return db.processCreditSale(
      items: items,
      subtotal: total,
      taxAmount: 0,
      totalAmount: total,
      employeeId: 'tester',
      employeeName: 'Tester',
      customerName: name,
      customerPhone: phone,
      initialDeposit: deposit,
      dueDate: DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String(),
    );
  }

  Future<int> stock(String productId, String size) async =>
      (await db.getProductById(productId))!.stockForSize(size);

  test('takes the goods out of stock and opens a linked credit account', () async {
    final p = await addTestProduct(db, price: 1000, sizes: {'M': 5, 'L': 2});

    final r = await sellOnCredit([line(p, 'M', 2), line(p, 'L', 1)], deposit: 500);

    expect(await stock(p.productId, 'M'), 3);
    expect(await stock(p.productId, 'L'), 1);

    expect(r.sale.paymentMethod, 'credit');
    expect(r.sale.customerName, 'Dawit');
    expect(r.credit.saleId, r.sale.saleId);
    expect(r.credit.totalAmountOwed, 3000);
    expect(r.credit.amountPaid, 500);
    expect(r.credit.remainingBalance, 2500);
    expect(r.credit.status, CreditStatus.partiallyPaid);
    expect(r.credit.totalQuantity, 3);
    expect(r.credit.productsDescription, 'Test Shirt (M) ×2, Test Shirt (L) ×1');
    expect(r.credit.payments.single.amountPaid, 500);

    // Visible to the rest of the app.
    final sales = await db.getAllSales();
    expect(sales.single.items.length, 2);
    final credits = await db.getAllCreditSales();
    expect(credits.single.saleId, r.sale.saleId);
  });

  test('no down payment → pending, no payment record', () async {
    final p = await addTestProduct(db, price: 800, sizes: {'M': 1});
    final r = await sellOnCredit([line(p, 'M', 1)]);
    expect(r.credit.status, CreditStatus.pending);
    expect(r.credit.remainingBalance, 800);
    expect(r.credit.payments, isEmpty);
  });

  test('later payments still settle a POS credit normally', () async {
    final p = await addTestProduct(db, price: 1000, sizes: {'M': 1});
    final r = await sellOnCredit([line(p, 'M', 1)], deposit: 400);
    final settled = await db.recordCreditPayment(
      creditId: r.credit.creditId,
      paymentAmount: 600,
      employeeId: 'tester',
      employeeName: 'Tester',
    );
    expect(settled.status, CreditStatus.fullyPaid);
    expect(settled.saleId, r.sale.saleId);
  });

  group('nothing is saved when it fails', () {
    Future<void> expectNothingSaved(String productId, int mStock) async {
      expect(await stock(productId, 'M'), mStock);
      expect(await db.getAllSales(), isEmpty);
      expect(await db.getAllCreditSales(), isEmpty);
    }

    test('not enough stock', () async {
      final p = await addTestProduct(db, sizes: {'M': 1});
      await expectLater(
        sellOnCredit([line(p, 'M', 2)]),
        throwsA(isA<InsufficientStockException>()),
      );
      await expectNothingSaved(p.productId, 1);
    });

    test('down payment larger than the total', () async {
      final p = await addTestProduct(db, price: 100, sizes: {'M': 3});
      await expectLater(
        sellOnCredit([line(p, 'M', 1)], deposit: 150),
        throwsA(isA<InvalidPaymentException>()
            .having((e) => e.reason, 'reason', PaymentRejection.depositExceedsTotal)),
      );
      await expectNothingSaved(p.productId, 3);
    });

    test('negative down payment', () async {
      final p = await addTestProduct(db, price: 100, sizes: {'M': 3});
      await expectLater(sellOnCredit([line(p, 'M', 1)], deposit: -1), throwsA(isA<InvalidPaymentException>()));
      await expectNothingSaved(p.productId, 3);
    });

    test('missing customer name', () async {
      final p = await addTestProduct(db, price: 100, sizes: {'M': 3});
      await expectLater(sellOnCredit([line(p, 'M', 1)], name: '  '), throwsArgumentError);
      await expectNothingSaved(p.productId, 3);
    });

    test('missing or malformed phone number', () async {
      final p = await addTestProduct(db, price: 100, sizes: {'M': 3});
      for (final bad in ['', '0912345678', '+251 912 345 678', '+251-912345678', '+251abc345678', '+25191']) {
        await expectLater(sellOnCredit([line(p, 'M', 1)], phone: bad), throwsArgumentError, reason: bad);
      }
      await expectNothingSaved(p.productId, 3);
    });
  });

  test('queues sale, stock change, credit (with sale_id) and deposit for upload', () async {
    final p = await addTestProduct(db, price: 1000, sizes: {'M': 5});
    final before = (await db.getPendingSyncQueue()).length;

    final r = await sellOnCredit([line(p, 'M', 2)], deposit: 300);

    final q = (await db.getPendingSyncQueue()).skip(before).toList();
    Map<String, dynamic> body(String table) =>
        jsonDecode(q.firstWhere((i) => i.tableName == table).payload) as Map<String, dynamic>;

    expect(body(DatabaseTables.tableSales)['payment_method'], 'credit');
    expect(body(DatabaseTables.tableProductVariants)['delta'], -2);
    final credit = body(DatabaseTables.tableCreditSales);
    expect(credit['sale_id'], r.sale.saleId);
    expect(credit['amount_paid'], 300);
    expect(body(DatabaseTables.tablePayments)['amount_paid'], 300);
    // The deposit is already inside the credit's amount_paid: no extra +300.
    expect(
      q.where((i) => i.tableName == DatabaseTables.tableCreditSales && i.operation == SyncOperation.increment),
      isEmpty,
    );
  });

  test('a credit downloaded from another device keeps its sale link', () async {
    final raw = await DatabaseHelper.instance.database;
    await raw.transaction((txn) => RemoteApply.apply(txn, DatabaseTables.tableCreditSales, 'c-1', {
          'credit_id': 'c-1',
          'customer_name': 'Hana',
          'phone_number': '+251911111111',
          'products_description': 'Blazer (M) ×1',
          'total_quantity': 1,
          'total_amount_owed': 2000.0,
          'amount_paid': 0.0,
          'remaining_balance': 2000.0,
          'due_date': '2026-12-31T00:00:00.000Z',
          'date_created': '2026-11-09T00:00:00.000Z',
          'status': 'pending',
          'sale_id': 'sale-xyz',
        }));
    expect((await db.getAllCreditSales()).single.saleId, 'sale-xyz');
  });

  test('upgrading an existing v1 database keeps old credits and adds sale_id', () async {
    final dir = await Directory.systemTemp.createTemp('coki_migration_');
    final path = '${dir.path}/v1.db';
    try {
      // A database as the v1 app created it (credit_sales without sale_id).
      final v1 = await databaseFactory.openDatabase(path,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (d, _) async {
              await d.execute(DatabaseTables.createCreditSalesTable.replaceFirst(',\n      sale_id TEXT', ''));
              await d.execute(DatabaseTables.createPaymentsTable);
              await d.insert(DatabaseTables.tableCreditSales, {
                'credit_id': 'old-1',
                'customer_name': 'Old Customer',
                'phone_number': '+251922222222',
                'products_description': 'Boutique Apparel',
                'total_quantity': 1,
                'total_amount_owed': 1000.0,
                'amount_paid': 0.0,
                'remaining_balance': 1000.0,
                'due_date': '2026-12-01T00:00:00.000Z',
                'date_created': '2026-11-01T00:00:00.000Z',
                'status': 'pending',
              });
            },
          ));
      final v1Columns = await v1.rawQuery('PRAGMA table_info(${DatabaseTables.tableCreditSales})');
      expect(v1Columns.map((c) => c['name']), isNot(contains('sale_id')));
      await v1.close();

      await DatabaseHelper.resetForTest();
      DatabaseHelper.pathOverride = path;
      final upgraded = await DatabaseHelper.instance.database;

      expect(await upgraded.getVersion(), DatabaseHelper.databaseVersion);
      final credits = await SQLiteService().getAllCreditSales();
      expect(credits.single.customerName, 'Old Customer');
      expect(credits.single.saleId, isNull);
    } finally {
      await DatabaseHelper.resetForTest();
      await dir.delete(recursive: true);
    }
  });
}
