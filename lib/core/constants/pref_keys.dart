/// Keys for values stored with shared_preferences (small per-device settings).
class PrefKeys {
  static const String language = 'pref_language_code';
  static const String darkMode = 'pref_dark_mode';

  /// Set at login; when false, the saved session is dropped on next launch.
  static const String rememberMe = 'pref_remember_me';
}
