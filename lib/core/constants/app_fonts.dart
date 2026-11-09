/// Bundled font families (declared in pubspec.yaml, files in assets/fonts/).
///
/// Fonts ship inside the app so text and PDF receipts render the same with or
/// without internet. Each language uses its own primary family and falls back
/// to the other, so mixed text like "Cash (ጥሬ ገንዘብ)" renders correctly in
/// both English and Amharic mode.
class AppFonts {
  static const String latin = 'NotoSans';
  static const String ethiopic = 'NotoSansEthiopic';

  static String primary({required bool isAmharic}) => isAmharic ? ethiopic : latin;

  static List<String> fallback({required bool isAmharic}) => [isAmharic ? latin : ethiopic];

  /// Asset paths of the TTF files, for non-Flutter renderers (PDF receipts).
  static const String latinRegularAsset = 'assets/fonts/NotoSans-Regular.ttf';
  static const String latinBoldAsset = 'assets/fonts/NotoSans-Bold.ttf';
  static const String ethiopicRegularAsset = 'assets/fonts/NotoSansEthiopic-Regular.ttf';
  static const String ethiopicBoldAsset = 'assets/fonts/NotoSansEthiopic-Bold.ttf';
}
