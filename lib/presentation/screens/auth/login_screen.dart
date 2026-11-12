import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/firebase_auth_service.dart';
import '../../../core/constants/pref_keys.dart';
import '../main_layout_screen.dart';

class LoginScreen extends StatefulWidget {
  final Function(Locale) onLanguageChanged;
  final Function(bool) onThemeChanged;

  /// Why the user was sent back here (e.g. access removed); shown on open.
  final AuthFailure? initialFailure;

  const LoginScreen({
    super.key,
    required this.onLanguageChanged,
    required this.onThemeChanged,
    this.initialFailure,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // No pre-filled credentials: every login is checked by Firebase.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = FirebaseAuthService();
  bool _isLoading = false;
  bool _rememberMe = true;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _infoMessage;

  bool get _isAmharic => Localizations.localeOf(context).languageCode == 'am';

  bool _shownInitialFailure = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs the locale, so it can't run in initState.
    final reason = widget.initialFailure;
    if (!_shownInitialFailure && reason != null) {
      _shownInitialFailure = true;
      _errorMessage = _failureMessage(reason);
    }
  }

  String _failureMessage(AuthFailure reason) {
    final am = _isAmharic;
    switch (reason) {
      case AuthFailure.invalidCredentials:
        return am ? 'ኢሜይል ወይም የይለፍ ቃል ትክክል አይደለም።' : 'Incorrect email or password.';
      case AuthFailure.invalidEmail:
        return am ? 'የኢሜይል አድራሻው ትክክል አይደለም።' : 'That email address is not valid.';
      case AuthFailure.noProfile:
        return am
            ? 'ይህ መለያ እስካሁን ሚና አልተሰጠውም። ባለቤቱን ያነጋግሩ።'
            : 'This account has no role assigned yet. Ask the store owner to add you.';
      case AuthFailure.userDisabled:
        return am ? 'ይህ መለያ ታግዷል።' : 'This account has been disabled.';
      case AuthFailure.tooManyRequests:
        return am
            ? 'በጣም ብዙ ሙከራዎች። ትንሽ ቆይተው እንደገና ይሞክሩ።'
            : 'Too many attempts. Please wait a moment and try again.';
      case AuthFailure.network:
        return am
            ? 'ኢንተርኔት የለም። ለመግባት ኢንተርኔት ያስፈልጋል።'
            : 'No internet connection. Signing in needs internet.';
      case AuthFailure.accessRemoved:
        return am
            ? 'የዚህ መለያ ፈቃድ በባለቤቱ ተነስቷል። ባለቤቱን ያነጋግሩ።'
            : "The store owner removed this account's access. Contact the owner if this is a mistake.";
      case AuthFailure.roleChanged:
        return am
            ? 'የእርስዎ ሚና ተቀይሯል። እባክዎ እንደገና ይግቡ።'
            : 'Your role was changed. Please sign in again.';
      case AuthFailure.offlineTooLong:
        return am
            ? 'ከ7 ቀን በላይ ያለ ኢንተርኔት ቆይቷል። መለያዎን ለማረጋገጥ ከኢንተርኔት ጋር ይገናኙና አፑን እንደገና ይክፈቱ።'
            : 'This phone has been offline for more than 7 days. Connect to the internet and reopen the app so your account can be checked.';
      case AuthFailure.unknown:
        return am ? 'መግባት አልተቻለም። እንደገና ይሞክሩ።' : 'Sign-in failed. Please try again.';
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _infoMessage = null;
        _errorMessage = _isAmharic
            ? 'መጀመሪያ ኢሜይልዎን ያስገቡ፣ ከዚያ "የይለፍ ቃል ረሱ?" ይጫኑ።'
            : 'Enter your email first, then tap "Forgot Password?".';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await _authService.sendPasswordReset(email);
      if (mounted) {
        setState(() => _infoMessage = _isAmharic
            ? 'ለ $email መለያ ካለ፣ የይለፍ ቃል መቀየሪያ ሊንክ በኢሜይል ተልኳል። ኢሜይልዎን (Spam ጭምር) ይመልከቱ፣ ሊንኩን ከፍተው አዲስ የይለፍ ቃል ያስገቡ፣ ከዚያ እዚህ ይግቡ።'
            : 'If $email has an account, a reset link was emailed to it. Check your inbox (and Spam), open the link, choose a new password, then sign in here.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = _failureMessage(e.reason));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = _isAmharic
          ? 'እባክዎ ኢሜይል እና የይለፍ ቃል ያስገቡ።'
          : 'Please enter email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final user = await _authService.signIn(email: email, password: password);
      // Remember Me: when off, AuthGate signs out on next launch.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(PrefKeys.rememberMe, _rememberMe);
      } catch (_) {}
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MainLayoutScreen(
              currentUser: user,
              onLanguageChanged: widget.onLanguageChanged,
              onThemeChanged: widget.onThemeChanged,
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = _failureMessage(e.reason));
    } catch (e) {
      if (mounted) setState(() => _errorMessage = _failureMessage(AuthFailure.unknown));
      debugPrint('Login error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Fashion store background image
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=1600',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1F2937)),
            ),
          ),

          // 2. Semi-transparent elegant dark overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),

          // 3. Top language toggle button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: languageCode,
                      dropdownColor: const Color(0xFF2A2A2A),
                      icon: const Icon(Icons.language, color: Colors.white, size: 18),
                      items: const [
                        DropdownMenuItem(
                          value: 'en',
                          child: Text('English', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: 'am',
                          child: Text('አማርኛ', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ],
                      onChanged: (code) {
                        if (code != null) {
                          widget.onLanguageChanged(Locale(code));
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Center Login Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusDialog),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusDialog),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Store Logo & Title
                        Center(
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGreen.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.storefront, color: Colors.white, size: 36),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            l10n.appTitle,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            l10n.storeSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.error, fontSize: 12),
                            ),
                          ),

                        if (_infoMessage != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primaryGreen),
                            ),
                            child: Text(
                              _infoMessage!,
                              style: const TextStyle(color: AppColors.primaryGreen, fontSize: 12),
                            ),
                          ),

                        // Email Field
                        Text(
                          l10n.email,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          // The login card is always light, so fix the text
                          // color (otherwise dark mode makes it white-on-white).
                          style: const TextStyle(color: Color(0xFF1F2937)),
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AppColors.secondaryBrown),
                            hintText: 'name@example.com',
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        Text(
                          l10n.password,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          style: const TextStyle(color: Color(0xFF1F2937)),
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _isLoading ? null : _handleLogin(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.secondaryBrown),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20,
                                color: AppColors.secondaryBrown,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            hintText: '••••••••',
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Remember Me & Forgot Password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: AppColors.primaryGreen,
                                    onChanged: (val) => setState(() => _rememberMe = val ?? true),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.rememberMe,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: _isLoading ? null : _handleForgotPassword,
                              child: Text(
                                l10n.forgotPassword,
                                style: const TextStyle(fontSize: 12, color: AppColors.secondaryBrown),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Primary Sign In Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : () => _handleLogin(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  l10n.login,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                        // (Demo "quick role login" buttons removed: they let
                        // anyone in as Owner without a password.)
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
