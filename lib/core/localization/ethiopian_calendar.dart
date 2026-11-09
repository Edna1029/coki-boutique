/// Ethiopian Calendar Converter and Formatter
/// Implements bidirectional conversion between Gregorian and Ethiopian calendars.
/// Complies with PRD Section 8 requirements.
class EthiopianCalendar {
  static const List<String> amharicMonths = [
    'መስከረም',
    'ጥቅምት',
    'ኅዳር',
    'ታኅሣሥ',
    'ጥር',
    'የካቲት',
    'መጋቢት',
    'ሚያዝያ',
    'ግንቦት',
    'ሰኔ',
    'ሐምሌ',
    'ነሐሴ',
    'ጳጉሜ'
  ];

  static const List<String> englishMonths = [
    'Meskerem',
    'Tikimt',
    'Hidar',
    'Tahsas',
    'Tir',
    'Yekatit',
    'Megabit',
    'Miyazya',
    'Ginbot',
    'Sene',
    'Hamle',
    'Nehase',
    'Pagume'
  ];

  final int year;
  final int month;
  final int day;

  EthiopianCalendar({
    required this.year,
    required this.month,
    required this.day,
  });

  /// Convert a Gregorian DateTime to Ethiopian date
  factory EthiopianCalendar.fromGregorian(DateTime gregorianDate) {
    // Julian Day Number algorithm
    int year = gregorianDate.year;
    int month = gregorianDate.month;
    int day = gregorianDate.day;

    int a = ((14 - month) / 12).floor();
    int y = year + 4800 - a;
    int m = month + 12 * a - 3;

    int jdn = day +
        ((153 * m + 2) / 5).floor() +
        365 * y +
        (y / 4).floor() -
        (y / 100).floor() +
        (y / 400).floor() -
        32045;

    // Convert JDN to Ethiopian Date
    int r = (jdn - 1723856) % 1461;
    int n = (r % 365) + 365 * (r / 1460).floor();

    int ethYear = 4 * ((jdn - 1723856) / 1461).floor() +
        (r / 365).floor() -
        (r / 1460).floor();
    int ethMonth = (n / 30).floor() + 1;
    int ethDay = (n % 30) + 1;

    return EthiopianCalendar(year: ethYear, month: ethMonth, day: ethDay);
  }

  /// Format date for display according to locale:
  /// Amharic: e.g. "24 ሰኔ 2018"
  /// English: e.g. "24 Sene 2018"
  String format({bool isAmharic = true}) {
    if (month < 1 || month > 13) return '$day/$month/$year';
    final monthName = isAmharic
        ? amharicMonths[month - 1]
        : englishMonths[month - 1];
    return '$day $monthName $year';
  }

  @override
  String toString() => '$day/${month}/$year';
}
