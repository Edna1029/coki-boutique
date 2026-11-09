/// Country calling codes offered in phone fields, and validation of the
/// number typed after the code. Numbers are stored in E.164 form
/// (`+251912345678`): no spaces, dashes, brackets or letters.
class PhoneCountry {
  final String dialCode; // "+251"
  final String nameEn;
  final String nameAm;
  final String flag;

  /// Allowed length of the national number (without the leading 0).
  final int minDigits;
  final int maxDigits;

  /// If set, the national number must match this (e.g. Ethiopian mobiles).
  final RegExp? pattern;

  /// Example shown as a hint.
  final String example;

  const PhoneCountry({
    required this.dialCode,
    required this.nameEn,
    required this.nameAm,
    required this.flag,
    required this.minDigits,
    required this.maxDigits,
    required this.example,
    this.pattern,
  });
}

class PhoneNumbers {
  /// Ethiopia: mobile numbers are 9 digits starting with 9 (Ethio telecom)
  /// or 7 (Safaricom), e.g. 912 345 678. Written locally as 0912 345 678.
  static final ethiopia = PhoneCountry(
    dialCode: '+251',
    nameEn: 'Ethiopia',
    nameAm: 'ኢትዮጵያ',
    flag: '🇪🇹',
    minDigits: 9,
    maxDigits: 9,
    example: '912345678',
    pattern: RegExp(r'^[79]\d{8}$'),
  );

  static final countries = <PhoneCountry>[
    ethiopia,
    const PhoneCountry(dialCode: '+254', nameEn: 'Kenya', nameAm: 'ኬንያ', flag: '🇰🇪', minDigits: 9, maxDigits: 9, example: '712345678'),
    const PhoneCountry(dialCode: '+253', nameEn: 'Djibouti', nameAm: 'ጅቡቲ', flag: '🇩🇯', minDigits: 8, maxDigits: 8, example: '77123456'),
    const PhoneCountry(dialCode: '+291', nameEn: 'Eritrea', nameAm: 'ኤርትራ', flag: '🇪🇷', minDigits: 7, maxDigits: 7, example: '7123456'),
    const PhoneCountry(dialCode: '+252', nameEn: 'Somalia', nameAm: 'ሶማሊያ', flag: '🇸🇴', minDigits: 7, maxDigits: 9, example: '612345678'),
    const PhoneCountry(dialCode: '+249', nameEn: 'Sudan', nameAm: 'ሱዳን', flag: '🇸🇩', minDigits: 9, maxDigits: 9, example: '912345678'),
    const PhoneCountry(dialCode: '+211', nameEn: 'South Sudan', nameAm: 'ደቡብ ሱዳን', flag: '🇸🇸', minDigits: 9, maxDigits: 9, example: '912345678'),
    const PhoneCountry(dialCode: '+971', nameEn: 'UAE', nameAm: 'ዩ.ኤ.ኢ', flag: '🇦🇪', minDigits: 8, maxDigits: 9, example: '501234567'),
    const PhoneCountry(dialCode: '+966', nameEn: 'Saudi Arabia', nameAm: 'ሳዑዲ ዓረቢያ', flag: '🇸🇦', minDigits: 9, maxDigits: 9, example: '512345678'),
    const PhoneCountry(dialCode: '+1', nameEn: 'USA / Canada', nameAm: 'አሜሪካ / ካናዳ', flag: '🇺🇸', minDigits: 10, maxDigits: 10, example: '2025550123'),
    const PhoneCountry(dialCode: '+44', nameEn: 'United Kingdom', nameAm: 'ዩናይትድ ኪንግደም', flag: '🇬🇧', minDigits: 10, maxDigits: 10, example: '7400123456'),
  ];

  /// Longest input the field accepts: national number plus a leading 0.
  static int maxInputLength(PhoneCountry c) => c.maxDigits + 1;

  /// The national number with a local leading 0 removed ("0912…" → "912…").
  static String national(String digits) => digits.startsWith('0') ? digits.substring(1) : digits;

  /// True when [digits] (digits only, as typed after the code) is a valid
  /// number for [country].
  static bool isValid(PhoneCountry country, String digits) {
    if (!RegExp(r'^\d+$').hasMatch(digits)) return false;
    final n = national(digits);
    if (n.length < country.minDigits || n.length > country.maxDigits) return false;
    return country.pattern?.hasMatch(n) ?? true;
  }

  /// Stored form check: "+" then 8–15 digits, nothing else.
  static bool isE164(String phone) => RegExp(r'^\+\d{8,15}$').hasMatch(phone);

  /// "+251" + "0912345678" → "+251912345678". Call only when [isValid].
  static String toE164(PhoneCountry country, String digits) => '${country.dialCode}${national(digits)}';
}
