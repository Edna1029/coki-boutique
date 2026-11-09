import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat('#,##0.00', 'en_US');

  /// Formats amount in ETB according to locale:
  /// English: "ETB 1,500.00"
  /// Amharic: "1,500.00 ብር"
  static String format(double amount, {bool isAmharic = false}) {
    final formattedNumber = _formatter.format(amount);
    if (isAmharic) {
      return '$formattedNumber ብር';
    } else {
      return 'ETB $formattedNumber';
    }
  }
}
