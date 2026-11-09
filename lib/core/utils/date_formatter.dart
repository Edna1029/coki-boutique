import 'package:intl/intl.dart';
import '../localization/ethiopian_calendar.dart';

class DateFormatter {
  static final DateFormat _gregorianFormat = DateFormat('MMMM d, yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');

  /// Formats date for display:
  /// English: Gregorian, e.g. "June 24, 2026"
  /// Amharic: Ethiopian, e.g. "24 ሰኔ 2018"
  static String formatDate(DateTime dateTime, {bool isAmharic = false}) {
    if (isAmharic) {
      final eth = EthiopianCalendar.fromGregorian(dateTime);
      return eth.format(isAmharic: true);
    }
    return _gregorianFormat.format(dateTime);
  }

  /// Formats time
  static String formatTime(DateTime dateTime) {
    return _timeFormat.format(dateTime);
  }

  /// Converts UTC ISO 8601 string to formatted date string
  static String formatIsoDate(String isoString, {bool isAmharic = false}) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return formatDate(dt, isAmharic: isAmharic);
    } catch (_) {
      return isoString;
    }
  }
}
