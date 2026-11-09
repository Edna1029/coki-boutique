import 'package:coki_boutique/data/database/database_helper.dart';
import 'package:coki_boutique/data/models/credit_sale_model.dart';
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

  Future<CreditSaleModel> newCredit({double owed = 6200, double deposit = 0}) => db.createCreditSale(
        customerName: 'Dawit',
        phoneNumber: '+251900000000',
        productsDescription: 'Blazer',
        totalQuantity: 1,
        totalAmountOwed: owed,
        initialDeposit: deposit,
        dueDate: DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String(),
        employeeId: 'tester',
        employeeName: 'Tester',
      );

  Future<CreditSaleModel> pay(CreditSaleModel c, double amount) => db.recordCreditPayment(
        creditId: c.creditId,
        paymentAmount: amount,
        employeeId: 'tester',
        employeeName: 'Tester',
      );

  Matcher rejectedFor(PaymentRejection reason) =>
      throwsA(isA<InvalidPaymentException>().having((e) => e.reason, 'reason', reason));

  group('creating a credit sale', () {
    test('no deposit → pending, full balance owed', () async {
      final c = await newCredit(owed: 1000);
      expect(c.status, CreditStatus.pending);
      expect(c.remainingBalance, 1000);
    });

    test('part deposit → partially paid, deposit recorded as a payment', () async {
      final c = await newCredit(owed: 1000, deposit: 400);
      expect(c.status, CreditStatus.partiallyPaid);
      expect(c.remainingBalance, 600);
      expect(c.payments.single.amountPaid, 400);
    });

    test('deposit larger than the total is rejected (fix #8)', () async {
      await expectLater(newCredit(owed: 1000, deposit: 1500), rejectedFor(PaymentRejection.depositExceedsTotal));
      expect(await db.getAllCreditSales(), isEmpty);
    });

    test('zero total or negative deposit is rejected', () async {
      await expectLater(newCredit(owed: 0), rejectedFor(PaymentRejection.notPositive));
      await expectLater(newCredit(owed: 100, deposit: -5), rejectedFor(PaymentRejection.notPositive));
    });
  });

  group('recording payments', () {
    test('partial payment lowers the balance', () async {
      final c = await newCredit(owed: 6200);
      final after = await pay(c, 2000);
      expect(after.remainingBalance, 4200);
      expect(after.status, CreditStatus.partiallyPaid);
    });

    test('paying the exact balance settles it at 0 → fully paid', () async {
      final c = await newCredit(owed: 6200);
      final after = await pay(c, 6200);
      expect(after.remainingBalance, 0);
      expect(after.amountPaid, 6200);
      expect(after.status, CreditStatus.fullyPaid);
    });

    test('rounding leftovers under half a cent still settle', () async {
      final c = await newCredit(owed: 100.10);
      await pay(c, 33.37);
      await pay(c, 33.37);
      final after = await pay(c, 33.36);
      expect(after.status, CreditStatus.fullyPaid);
      expect(after.remainingBalance, 0);
    });

    test('paying more than owed is rejected and nothing changes (fix #8)', () async {
      final c = await newCredit(owed: 6200);
      await expectLater(pay(c, 7000), rejectedFor(PaymentRejection.exceedsBalance));
      final stored = (await db.getAllCreditSales()).single;
      expect(stored.remainingBalance, 6200);
      expect(stored.payments, isEmpty);
    });

    test('the rejection reports the maximum allowed', () async {
      final c = await newCredit(owed: 6200, deposit: 200);
      await expectLater(
        pay(c, 9999),
        throwsA(isA<InvalidPaymentException>().having((e) => e.maxAllowed, 'maxAllowed', 6000)),
      );
    });

    test('no payments on a fully paid credit', () async {
      final c = await newCredit(owed: 500);
      await pay(c, 500);
      await expectLater(pay(c, 1), rejectedFor(PaymentRejection.alreadyPaid));
    });

    test('zero or negative payments are rejected', () async {
      final c = await newCredit(owed: 500);
      await expectLater(pay(c, 0), rejectedFor(PaymentRejection.notPositive));
      await expectLater(pay(c, -10), rejectedFor(PaymentRejection.notPositive));
    });
  });
}
