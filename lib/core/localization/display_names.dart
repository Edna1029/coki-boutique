import '../../domain/entities/enums.dart';

/// Translated DISPLAY names for values that are stored in English.
///
/// Category and gender values stay in English in the database and in the
/// cloud (so every device, report and export agrees on the same key); only
/// what the user sees changes with the app language.
class DisplayNames {
  static const Map<String, String> _categoryAm = {
    'Traditional': 'ባህላዊ',
    'Dresses': 'ቀሚሶች',
    'Formal Wear': 'መደበኛ አልባሳት',
    'Shirts': 'ሸሚዞች',
    'Jeans': 'ጂንስ',
    'Accessories': 'መለዋወጫዎች',
  };

  /// e.g. "Dresses" → "ቀሚሶች" in Amharic. Unknown categories are shown as stored.
  static String category(String stored, {required bool isAmharic}) =>
      isAmharic ? (_categoryAm[stored] ?? stored) : stored;

  static String gender(Gender g, {required bool isAmharic}) {
    switch (g) {
      case Gender.men:
        return isAmharic ? 'የወንዶች' : 'Men';
      case Gender.women:
        return isAmharic ? 'የሴቶች' : 'Women';
      case Gender.unisex:
        return isAmharic ? 'ለሁለቱም' : 'Unisex';
    }
  }
}
