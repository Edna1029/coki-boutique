import 'package:coki_boutique/core/utils/phone_number.dart';
import 'package:coki_boutique/presentation/widgets/phone_number_field.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final et = PhoneNumbers.ethiopia;
  PhoneCountry country(String code) => PhoneNumbers.countries.firstWhere((c) => c.dialCode == code);

  test('Ethiopia (+251) is the default first entry', () {
    expect(PhoneNumbers.countries.first.dialCode, '+251');
  });

  group('Ethiopian numbers', () {
    test('accepts 9-digit mobiles starting with 9 or 7, with or without the leading 0', () {
      for (final ok in ['912345678', '0912345678', '712345678', '0712345678']) {
        expect(PhoneNumbers.isValid(et, ok), isTrue, reason: ok);
      }
    });

    test('rejects wrong length, wrong first digit, landlines', () {
      for (final bad in ['', '91234567', '9123456789', '00912345678', '812345678', '112345678', '0112345678']) {
        expect(PhoneNumbers.isValid(et, bad), isFalse, reason: bad);
      }
    });

    test('rejects anything that is not just digits', () {
      for (final bad in ['912 345 678', '912-345-678', '+251912345678', '(091)2345678', '91234567a', '٩١٢٣٤٥٦٧٨']) {
        expect(PhoneNumbers.isValid(et, bad), isFalse, reason: bad);
      }
    });

    test('stored as +251 followed by the national number (local 0 dropped)', () {
      expect(PhoneNumbers.toE164(et, '0912345678'), '+251912345678');
      expect(PhoneNumbers.toE164(et, '712345678'), '+251712345678');
    });
  });

  test('other countries use their own lengths', () {
    expect(PhoneNumbers.isValid(country('+1'), '2025550123'), isTrue);
    expect(PhoneNumbers.isValid(country('+1'), '202555012'), isFalse);
    expect(PhoneNumbers.isValid(country('+253'), '77123456'), isTrue);
    expect(PhoneNumbers.toE164(country('+254'), '0712345678'), '+254712345678');
  });

  test('field length allows a leading 0 but nothing longer', () {
    expect(PhoneNumbers.maxInputLength(et), 10);
  });

  test('stored-form check', () {
    expect(PhoneNumbers.isE164('+251912345678'), isTrue);
    for (final bad in ['', '251912345678', '+251 912345678', '+251-912345678', '+2519', '+251abc']) {
      expect(PhoneNumbers.isE164(bad), isFalse, reason: bad);
    }
  });

  test('every country example is itself valid', () {
    for (final c in PhoneNumbers.countries) {
      expect(PhoneNumbers.isValid(c, c.example), isTrue, reason: c.nameEn);
    }
  });

  group('field messages (credit = required, staff = optional)', () {
    String? check(String digits, {bool required = true, bool am = false}) =>
        PhoneNumberField.validate(et, digits, isAmharic: am, required: required);

    test('empty: error when required, fine when optional', () {
      expect(check(''), 'Phone number is required.');
      expect(check('', required: false), isNull);
    });

    test('valid number: no message', () {
      expect(check('0912345678'), isNull);
      expect(check('912345678', required: false), isNull);
    });

    test('invalid number: explains the Ethiopian rule, in both languages', () {
      expect(check('812345678'), contains('starting with 9 or 7'));
      expect(check('812345678', required: false), isNotNull);
      expect(check('812345678', am: true), contains('ኢትዮጵያ'));
    });

    test('other countries name the expected length', () {
      final us = PhoneNumbers.countries.firstWhere((c) => c.dialCode == '+1');
      expect(PhoneNumberField.validate(us, '123', isAmharic: false), contains('10 digits'));
    });
  });
}
