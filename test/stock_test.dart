import 'package:coki_boutique/data/database/database_helper.dart';
import 'package:coki_boutique/data/database/tables.dart';
import 'package:coki_boutique/data/services/sqlite_service.dart';
import 'package:coki_boutique/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_db.dart';

void main() {
  late SQLiteService db;

  setUp(() async {
    await useFreshTestDatabase();
    db = SQLiteService();
  });

  tearDown(DatabaseHelper.resetForTest);

  group('fresh install', () {
    test('starts with no sample data', () async {
      expect(await db.getAllProducts(), isEmpty);
      expect(await db.getAllSales(), isEmpty);
      expect(await db.getAllCreditSales(), isEmpty);
      final raw = await DatabaseHelper.instance.database;
      expect(await raw.query(DatabaseTables.tableUsers), isEmpty);
    });
  });

  group('adding stock (PRD §11 merge rule)', () {
    test('a new product is created with its sizes', () async {
      final p = await addTestProduct(db, sizes: {'S': 2, 'M': 5});
      expect(p.stockForSize('S'), 2);
      expect(p.stockForSize('M'), 5);
      expect(p.totalStock, 7);
    });

    test('same name/brand/color/gender ADDS to the existing product', () async {
      await addTestProduct(db, sizes: {'M': 12});
      final again = await addTestProduct(db, name: 'test shirt', sizes: {'M': 5, 'L': 3});
      expect((await db.getAllProducts()).length, 1, reason: 'no duplicate product');
      expect(again.stockForSize('M'), 17);
      expect(again.stockForSize('L'), 3);
    });

    test('a different color is a different product', () async {
      await addTestProduct(db, color: 'Blue');
      await addTestProduct(db, color: 'Red', barcode: '2000000000015');
      expect((await db.getAllProducts()).length, 2);
    });

    test('sizes left at 0 are not saved (P4)', () async {
      final p = await addTestProduct(db, sizes: {'S': 0, 'M': 3, 'L': 0, 'XL': 0});
      expect(p.variants.map((v) => v.size), ['M']);
      final stored = await db.getProductById(p.productId);
      expect(stored!.variants.map((v) => v.size), ['M']);
    });

    test('restocking with 0 or negative never changes or lowers stock', () async {
      await addTestProduct(db, sizes: {'M': 4});
      final again = await addTestProduct(db, sizes: {'M': 0, 'S': -2});
      expect(again.stockForSize('M'), 4);
      expect(again.variants.any((v) => v.size == 'S'), isFalse);
    });
  });

  group('deleting a product (P4)', () {
    test('removes the product and its sizes but keeps past sales', () async {
      final p = await addTestProduct(db, sizes: {'M': 5});
      await sell(db, [line(p, 'M', 2)]);

      await db.deleteProduct(p.productId);

      expect(await db.getProductById(p.productId), isNull);
      final raw = await DatabaseHelper.instance.database;
      expect(
        await raw.query(DatabaseTables.tableProductVariants,
            where: 'product_id = ?', whereArgs: [p.productId]),
        isEmpty,
      );
      // Sale history is untouched and still names the product.
      expect((await db.getAllSales()).single.totalAmount, 200);
      final items = await raw.query(DatabaseTables.tableSaleItems);
      expect(items.single['product_name'], 'Test Shirt');
    });

    test('queues a cloud soft-delete for the product and every size', () async {
      final p = await addTestProduct(db, sizes: {'S': 1, 'M': 2});
      await db.deleteProduct(p.productId);

      final raw = await DatabaseHelper.instance.database;
      final deletes = await raw.query(DatabaseTables.tableSyncQueue,
          where: 'operation = ?', whereArgs: [SyncOperation.delete.name]);
      final byTable = deletes.map((r) => r['table_name']).toList();
      expect(byTable.where((t) => t == DatabaseTables.tableProducts).length, 1);
      expect(byTable.where((t) => t == DatabaseTables.tableProductVariants).length, 2);
    });
  });

  group('editing a product (fix #3)', () {
    test('SETS stock to the typed numbers instead of adding', () async {
      final p = await addTestProduct(db, sizes: {'M': 15});
      final edited = await db.updateProduct(
        productId: p.productId,
        name: p.productName,
        sku: '',
        category: p.category,
        brand: p.brand,
        color: p.color,
        gender: p.gender,
        price: 250,
        image: '',
        sizeQuantities: {'M': 12},
      );
      expect(edited.stockForSize('M'), 12);
      expect(edited.price, 250);
    });

    test('keeps barcode and SKU when left empty', () async {
      final p = await addTestProduct(db, barcode: '2111111111116', sku: 'KEEP-ME');
      final edited = await db.updateProduct(
        productId: p.productId,
        name: 'Renamed',
        sku: '',
        category: p.category,
        brand: p.brand,
        color: p.color,
        gender: Gender.unisex,
        price: p.price,
        image: '',
        sizeQuantities: const {},
      );
      expect(edited.productName, 'Renamed');
      expect(edited.barcode, '2111111111116');
      expect(edited.sku, 'KEEP-ME');
    });
  });

  group('selling (fix #5)', () {
    test('a sale deducts exactly the quantity sold', () async {
      final p = await addTestProduct(db, sizes: {'M': 5});
      await sell(db, [line(p, 'M', 2)]);
      final after = await db.getProductById(p.productId);
      expect(after!.stockForSize('M'), 3);
      expect((await db.getAllSales()).length, 1);
    });

    test('overselling is rejected and NOTHING is saved', () async {
      final p = await addTestProduct(db, sizes: {'M': 1});
      await expectLater(
        sell(db, [line(p, 'M', 2)]),
        throwsA(isA<InsufficientStockException>()
            .having((e) => e.available, 'available', 1)
            .having((e) => e.requested, 'requested', 2)),
      );
      expect((await db.getProductById(p.productId))!.stockForSize('M'), 1, reason: 'stock unchanged');
      expect(await db.getAllSales(), isEmpty, reason: 'no sale recorded');
    });

    test('two cart lines for the same size are checked together', () async {
      final p = await addTestProduct(db, sizes: {'M': 3});
      await expectLater(
        sell(db, [line(p, 'M', 2), line(p, 'M', 2)]),
        throwsA(isA<InsufficientStockException>()),
      );
      expect((await db.getProductById(p.productId))!.stockForSize('M'), 3);
    });

    test('one bad line rolls back the good lines too', () async {
      final shirt = await addTestProduct(db, sizes: {'M': 5});
      final scarf = await addTestProduct(db, name: 'Scarf', barcode: '2000000000022', sizes: {'M': 1});
      await expectLater(
        sell(db, [line(shirt, 'M', 1), line(scarf, 'M', 3)]),
        throwsA(isA<InsufficientStockException>()),
      );
      expect((await db.getProductById(shirt.productId))!.stockForSize('M'), 5);
    });

    test('selling a size that does not exist is rejected', () async {
      final p = await addTestProduct(db, sizes: {'M': 5});
      await expectLater(sell(db, [line(p, 'XL', 1)]), throwsA(isA<InsufficientStockException>()));
    });

    test('zero or negative quantities are rejected', () async {
      final p = await addTestProduct(db, sizes: {'M': 5});
      await expectLater(sell(db, [line(p, 'M', 0)]), throwsArgumentError);
    });
  });

  group('looking up by code (scanner)', () {
    test('finds by barcode, QR code or SKU', () async {
      final p = await addTestProduct(db, barcode: '2123456789012', sku: 'ck-shirt-1');
      expect((await db.getProductByCode('2123456789012'))?.productId, p.productId);
      expect((await db.getProductByCode('QR-2123456789012'))?.productId, p.productId);
      expect((await db.getProductByCode('CK-SHIRT-1'))?.productId, p.productId, reason: 'SKU ignores case');
      expect(await db.getProductByCode('nothing-here'), isNull);
      expect(await db.getProductByCode('  '), isNull);
    });
  });
}
