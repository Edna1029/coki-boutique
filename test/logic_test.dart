import 'package:coki_boutique/core/utils/barcode_generator.dart';
import 'package:coki_boutique/data/models/product_model.dart';
import 'package:coki_boutique/data/models/product_variant_model.dart';
import 'package:coki_boutique/data/models/sale_model.dart';
import 'package:coki_boutique/data/services/excel_export_service.dart';
import 'package:coki_boutique/data/services/firebase_auth_service.dart';
import 'package:coki_boutique/data/sync/sync_service.dart';
import 'package:coki_boutique/domain/entities/enums.dart';
import 'package:coki_boutique/domain/reports/sales_report.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure logic: login rules, barcodes, reports. No database or network.
void main() {
  group('offline access limit (P5)', () {
    final now = DateTime.utc(2026, 11, 20, 12);
    bool valid(UserRole role, DateTime? verified) =>
        FirebaseAuthService.cachedAccessStillValid(role: role, lastVerified: verified, now: now);

    test('staff may work offline up to 7 days after the last server check', () {
      expect(valid(UserRole.employee, now.subtract(const Duration(days: 1))), isTrue);
      expect(valid(UserRole.employee, now.subtract(const Duration(days: 7))), isTrue);
      expect(valid(UserRole.admin, now.subtract(const Duration(days: 6, hours: 23))), isTrue);
    });

    test('after 7 days offline staff must go online once', () {
      expect(valid(UserRole.employee, now.subtract(const Duration(days: 7, minutes: 1))), isFalse);
      expect(valid(UserRole.admin, now.subtract(const Duration(days: 30))), isFalse);
    });

    test('a device copy that was never confirmed is not trusted', () {
      expect(valid(UserRole.employee, null), isFalse);
    });

    test('the owner is never locked out of their own shop', () {
      expect(valid(UserRole.owner, now.subtract(const Duration(days: 365))), isTrue);
      expect(valid(UserRole.owner, null), isTrue);
    });
  });

  group('login / roles', () {
    test('only owners and admins may see shop finances (reports, export, revenue)', () {
      expect(UserRole.owner.canViewFinancials, isTrue);
      expect(UserRole.admin.canViewFinancials, isTrue);
      expect(UserRole.employee.canViewFinancials, isFalse);
      // A missing/unknown role falls back to employee → no reports.
      expect(UserRole.fromString('cashier').canViewFinancials, isFalse);
    });

    test('Firebase error codes map to the right user message', () {
      expect(FirebaseAuthService.mapErrorCode('invalid-credential'), AuthFailure.invalidCredentials);
      expect(FirebaseAuthService.mapErrorCode('wrong-password'), AuthFailure.invalidCredentials);
      expect(FirebaseAuthService.mapErrorCode('user-not-found'), AuthFailure.invalidCredentials);
      expect(FirebaseAuthService.mapErrorCode('invalid-email'), AuthFailure.invalidEmail);
      expect(FirebaseAuthService.mapErrorCode('user-disabled'), AuthFailure.userDisabled);
      expect(FirebaseAuthService.mapErrorCode('too-many-requests'), AuthFailure.tooManyRequests);
      expect(FirebaseAuthService.mapErrorCode('network-request-failed'), AuthFailure.network);
      expect(FirebaseAuthService.mapErrorCode('something-new'), AuthFailure.unknown);
    });

    test('wrong email and wrong password give the SAME message (no account probing)', () {
      expect(
        FirebaseAuthService.mapErrorCode('user-not-found'),
        FirebaseAuthService.mapErrorCode('wrong-password'),
      );
    });

    test('roles are read case-insensitively', () {
      expect(UserRole.fromString('owner'), UserRole.owner);
      expect(UserRole.fromString('OWNER'), UserRole.owner);
      expect(UserRole.fromString('Admin'), UserRole.admin);
      expect(UserRole.fromString('employee'), UserRole.employee);
    });

    test('an unknown or misspelled role gets the LEAST privilege (employee)', () {
      expect(UserRole.fromString('ownr'), UserRole.employee);
      expect(UserRole.fromString('superuser'), UserRole.employee);
      expect(UserRole.fromString(''), UserRole.employee);
    });
  });

  group('sizes', () {
    test('always listed S, M, L, XL, XXL regardless of stored order', () {
      ProductVariantModel v(String s) =>
          ProductVariantModel(variantId: s, productId: 'p', size: s, quantity: 1, lastUpdated: '');
      final sorted = ProductModel.sortedBySize([v('XXL'), v('M'), v('One Size'), v('s'), v('XL'), v('L')]);
      expect(sorted.map((e) => e.size), ['s', 'M', 'L', 'XL', 'XXL', 'One Size']);
    });
  });

  group('barcodes', () {
    test('check digit matches real-world EAN-13 codes', () {
      expect(BarcodeGenerator.ean13CheckDigit('400638133393'), 1);
      expect(BarcodeGenerator.ean13CheckDigit('590123412345'), 7);
      expect(BarcodeGenerator.ean13CheckDigit('978030640615'), 7);
    });

    test('generated codes are valid in-store EAN-13s and unique', () {
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        final code = BarcodeGenerator.generateInStoreEan13();
        expect(code, matches(RegExp(r'^2\d{12}$')));
        expect(BarcodeGenerator.ean13CheckDigit(code.substring(0, 12)), int.parse(code[12]));
        seen.add(code);
      }
      expect(seen.length, 200);
    });
  });

  group('sales report', () {
    var id = 0;
    SaleModel sale(DateTime localWhen, List<(String, String, int, double)> lines) {
      final items = [
        for (final (pid, name, qty, price) in lines)
          SaleItemModel(
            saleItemId: 'i${id++}',
            saleId: 's',
            productId: pid,
            productName: name,
            size: 'M',
            quantity: qty,
            unitPrice: price,
            totalAmount: qty * price,
          ),
      ];
      final total = items.fold<double>(0, (a, i) => a + i.totalAmount);
      return SaleModel(
        saleId: 's${id++}',
        items: items,
        subtotal: total,
        taxAmount: 0,
        totalAmount: total,
        employeeId: 'e',
        employeeName: 'E',
        date: localWhen.toUtc().toIso8601String(),
      );
    }

    final now = DateTime(2026, 11, 8, 15);
    final sales = [
      sale(DateTime(2026, 11, 8, 9, 30), [('shirt', 'Shirt', 2, 100)]), // today 200
      sale(DateTime(2026, 11, 8, 0, 5), [('dress', 'Dress', 1, 500)]), // today 500 (just after midnight)
      sale(DateTime(2026, 11, 7, 23, 55), [('shirt', 'Shirt', 1, 100), ('bag', 'Bag', 1, 300)]), // yesterday 400
      sale(DateTime(2026, 11, 2, 12), [('shirt', 'Shirt', 3, 100)]), // 6 days ago 300
      sale(DateTime(2026, 11, 1, 12), [('dress', 'Dress', 2, 500)]), // 7 days ago → previous week
      sale(DateTime(2026, 10, 29, 12), [('bag', 'Bag', 1, 300)]), // previous week
      sale(DateTime(2026, 10, 20, 12), [('bag', 'Bag', 9, 300)]), // outside both
    ];

    test('weekly totals, daily buckets and day boundaries', () {
      final r = SalesReport.lastDays(sales, 7, now: now);
      expect(r.revenue, 1400);
      expect(r.transactions, 4);
      expect(r.units, 8);
      expect(r.dailyRevenue[6], 700, reason: 'today, incl. a sale at 00:05');
      expect(r.dailyRevenue[5], 400, reason: 'yesterday, incl. a sale at 23:55');
      expect(r.dailyRevenue[0], 300, reason: '6 days ago is still in the week');
      expect(r.firstDay, DateTime(2026, 11, 2));
      expect(r.averageSale, 350);
    });

    test('comparison with the previous week', () {
      final r = SalesReport.lastDays(sales, 7, now: now);
      expect(r.previousRevenue, 1300);
      expect(r.changePercent!.toStringAsFixed(1), '7.7');
    });

    test('top products ranked by units sold', () {
      final week = SalesReport.lastDays(sales, 7, now: now);
      expect(week.topProducts.first.productName, 'Shirt');
      expect(week.topProducts.first.units, 6);
      expect(week.topProducts.first.revenue, 600);

      final month = SalesReport.lastDays(sales, 30, now: now);
      expect(month.revenue, 5400);
      expect(month.topProducts.first.productName, 'Bag');
    });

    test('no sales → zeros and no comparison', () {
      final r = SalesReport.lastDays(const [], 7, now: now);
      expect(r.revenue, 0);
      expect(r.averageSale, 0);
      expect(r.changePercent, isNull);
      expect(r.topProducts, isEmpty);
    });
  });

  ProductModel productWith(Map<String, int> sizes) => ProductModel.fromMap(
        const {'product_id': 'p1', 'product_name': 'Shirt'},
        variants: [
          for (final e in sizes.entries)
            ProductVariantModel(variantId: 'v-${e.key}', productId: 'p1', size: e.key, quantity: e.value, lastUpdated: ''),
        ],
      );

  group('oversold stock (R5)', () {
    test('a size below zero counts as 0 on the shelf and is reported as oversold', () {
      final p = productWith({'S': 3, 'M': -1});
      expect(p.totalStock, 3, reason: 'the −1 must not hide the 3 in S');
      expect(p.oversoldUnits, 1);
    });

    test('normal stock is not oversold', () {
      final p = productWith({'S': 3, 'M': 0});
      expect(p.totalStock, 3);
      expect(p.oversoldUnits, 0);
    });
  });

  group('Excel inventory size columns (R7)', () {
    test('every size in the shop gets a column, in shop order, once', () {
      final sizes = ExcelExportService.inventorySizeColumns([
        productWith({'XXXL': 1, 'M': 2}),
        productWith({'xs': 1, 'm': 4, '42': 2}),
      ]);
      expect(sizes, ['XS', 'M', 'XXXL', '42']);
    });
  });

  group('stuck sync warning (R4)', () {
    test('being offline is never "stuck", however long', () {
      expect(SyncService.isStuck(failuresSoFar: 50, offline: true), isFalse);
    });

    test('a real error warns only after repeated failures', () {
      expect(SyncService.isStuck(failuresSoFar: SyncService.stuckAfterFailures - 1, offline: false), isFalse);
      expect(SyncService.isStuck(failuresSoFar: SyncService.stuckAfterFailures, offline: false), isTrue);
    });
  });
}
