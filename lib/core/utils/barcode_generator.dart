import 'dart:math';

/// Generates and validates EAN-13 barcodes for products that don't come
/// with a manufacturer barcode.
///
/// Generated codes start with `2`, the GS1 prefix range reserved for
/// in-store (restricted circulation) use, so they will never collide with a
/// real manufacturer barcode printed on branded goods.
class BarcodeGenerator {
  static final Random _random = Random.secure();

  /// Returns a new random in-store EAN-13 code, e.g. `2048193720461`.
  static String generateInStoreEan13() {
    final buffer = StringBuffer('2');
    for (var i = 0; i < 11; i++) {
      buffer.write(_random.nextInt(10));
    }
    final first12 = buffer.toString();
    return '$first12${ean13CheckDigit(first12)}';
  }

  /// Computes the EAN-13 check digit for the first 12 digits.
  static int ean13CheckDigit(String first12) {
    assert(first12.length == 12);
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final digit = first12.codeUnitAt(i) - 48;
      sum += (i.isEven) ? digit : digit * 3;
    }
    return (10 - sum % 10) % 10;
  }
}
