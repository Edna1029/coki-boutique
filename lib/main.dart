import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/pref_keys.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'data/database/database_helper.dart';
import 'data/models/user_model.dart';
import 'data/services/firebase_auth_service.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/main_layout_screen.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (Auth + Firestore). Reads android/app/google-services.json.
  // Works offline: initialization is local, and Auth persists the session.
  // Time-limited so a Firebase problem can never leave the shop staring at a
  // blank launch screen; the app still opens (offline features keep working).
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    debugPrint('Firebase initialized');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize SQLite local database with initial seed data
  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint('Database initialization note: $e');
  }

  // Restore the user's last language and theme choice (PRD §7: language
  // selection persists; light/dark mode).
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('Preferences unavailable, using defaults: $e');
  }
  final savedLanguage = prefs?.getString(PrefKeys.language);
  final savedDark = prefs?.getBool(PrefKeys.darkMode) ?? false;

  runApp(CokiBoutiqueApp(
    prefs: prefs,
    initialLocale: Locale(savedLanguage == 'am' ? 'am' : 'en'),
    initialDarkMode: savedDark,
  ));
}

class CokiBoutiqueApp extends StatefulWidget {
  final SharedPreferences? prefs;
  final Locale initialLocale;
  final bool initialDarkMode;

  const CokiBoutiqueApp({
    super.key,
    this.prefs,
    this.initialLocale = const Locale('en'),
    this.initialDarkMode = false,
  });

  @override
  State<CokiBoutiqueApp> createState() => _CokiBoutiqueAppState();
}

class _CokiBoutiqueAppState extends State<CokiBoutiqueApp> {
  late Locale _locale = widget.initialLocale;
  late bool _isDarkMode = widget.initialDarkMode;

  void _changeLanguage(Locale newLocale) {
    setState(() => _locale = newLocale);
    widget.prefs?.setString(PrefKeys.language, newLocale.languageCode);
  }

  void _toggleTheme(bool isDark) {
    setState(() => _isDarkMode = isDark);
    widget.prefs?.setBool(PrefKeys.darkMode, isDark);
  }

  @override
  Widget build(BuildContext context) {
    final isAmharic = _locale.languageCode == 'am';

    return MaterialApp(
      title: 'Coki Boutique',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightTheme(isAmharic: isAmharic),
      darkTheme: AppTheme.darkTheme(isAmharic: isAmharic),
      locale: _locale,
      supportedLocales: const [
        Locale('en', ''),
        Locale('am', ''),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Screens read the CURRENT theme/locale from context
      // (Theme.of / Localizations.localeOf), never from constructor copies,
      // so they update instantly when these change.
      home: AuthGate(
        prefs: widget.prefs,
        onLanguageChanged: _changeLanguage,
        onThemeChanged: _toggleTheme,
      ),
    );
  }
}

/// Decides the first screen: a restored Firebase session ("Remember Me")
/// goes straight to the app; otherwise the login screen.
class AuthGate extends StatefulWidget {
  final SharedPreferences? prefs;
  final Function(Locale) onLanguageChanged;
  final Function(bool) onThemeChanged;

  const AuthGate({
    super.key,
    this.prefs,
    required this.onLanguageChanged,
    required this.onThemeChanged,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<UserModel?> _session = _restore();

  /// Why the saved session was not restored, shown on the login screen.
  AuthFailure? _restoreFailure;

  Future<UserModel?> _restore() async {
    final auth = FirebaseAuthService();
    try {
      final remember = widget.prefs?.getBool(PrefKeys.rememberMe) ?? true;
      if (!remember) {
        await auth.signOut();
        return null;
      }
      return await auth.restoreSession();
    } on AuthException catch (e) {
      _restoreFailure = e.reason; // e.g. access removed / offline too long
      return null;
    } catch (e) {
      debugPrint('Session restore failed: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _session,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
          );
        }
        final user = snap.data;
        if (user != null) {
          return MainLayoutScreen(
            currentUser: user,
            onLanguageChanged: widget.onLanguageChanged,
            onThemeChanged: widget.onThemeChanged,
          );
        }
        return LoginScreen(
          onLanguageChanged: widget.onLanguageChanged,
          onThemeChanged: widget.onThemeChanged,
          initialFailure: _restoreFailure,
        );
      },
    );
  }
}
