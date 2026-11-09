import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/tables.dart';
import '../models/user_model.dart';
import '../../domain/entities/enums.dart';

/// Why a sign-in / reset failed. The UI maps these to translated messages.
enum AuthFailure {
  invalidCredentials,
  invalidEmail,
  noProfile,
  userDisabled,
  tooManyRequests,
  network,
  unknown,
}

class AuthException implements Exception {
  final AuthFailure reason;
  final String? detail;
  const AuthException(this.reason, [this.detail]);

  @override
  String toString() => 'AuthException(${reason.name}${detail != null ? ': $detail' : ''})';
}

/// Real authentication (PRD Â§6):
/// - Firebase Auth checks the email + password.
/// - The user's role comes from Firestore `users/{uid}`, which only an owner
///   can write (see firestore.rules) â€” never from the email address.
/// - The profile is cached in SQLite so the app works offline after the
///   first successful login (Firebase Auth also persists the session).
class FirebaseAuthService {
  final FirebaseAuth? _firebaseAuth;
  final FirebaseFirestore? _firestore;

  FirebaseAuthService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
      : _firebaseAuth = firebaseAuth,
        _firestore = firestore;

  FirebaseAuth get auth => _firebaseAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  static const String usersCollection = 'users';

  /// Signs in and returns the user's profile (with role).
  /// Throws [AuthException] on failure; nothing is kept signed in on failure.
  Future<UserModel> signIn({required String email, required String password}) async {
    final cleanEmail = email.trim();
    try {
      final cred = await auth.signInWithEmailAndPassword(email: cleanEmail, password: password);
      final user = cred.user;
      if (user == null) throw const AuthException(AuthFailure.unknown);

      final UserModel? profile;
      try {
        profile = await _loadProfile(user);
      } on AuthException {
        await auth.signOut(); // couldn't verify the role — don't stay half signed in
        rethrow;
      }
      if (profile == null) {
        // Valid login, but the owner hasn't given this account a role yet.
        await auth.signOut();
        throw const AuthException(AuthFailure.noProfile);
      }
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(mapErrorCode(e.code), e.code);
    }
  }

  /// Returns the signed-in user's profile if a session was persisted
  /// (works offline from the SQLite cache), otherwise null.
  Future<UserModel?> restoreSession() async {
    // On a cold start Firebase restores the saved session asynchronously;
    // wait for its first auth-state event instead of reading currentUser
    // too early (which can be null on slow devices).
    User? user = auth.currentUser;
    if (user == null) {
      try {
        user = await auth.authStateChanges().first.timeout(const Duration(seconds: 5));
      } catch (_) {
        user = auth.currentUser;
      }
    }
    if (user == null) return null;
    final UserModel? profile;
    try {
      profile = await _loadProfile(user);
    } on AuthException {
      // Offline and never cached: show the login screen, but keep the Firebase
      // session so it can be restored next time the device is online.
      return null;
    }
    if (profile == null) {
      await auth.signOut();
      return null;
    }
    return profile;
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(mapErrorCode(e.code), e.code);
    }
  }

  Future<void> signOut() async {
    try {
      await auth.signOut();
    } catch (e) {
      debugPrint('Sign-out error (ignored): $e');
    }
  }

  // ---------------------------------------------------------------------------

  /// Firestore first (server, or its offline cache); falls back to the SQLite
  /// copy when Firestore can't answer at all (offline with no cache).
  /// Returns null only when Firestore positively says there is no profile.
  Future<UserModel?> _loadProfile(User user) async {
    try {
      final snap = await firestore.collection(usersCollection).doc(user.uid).get();
      if (!snap.exists) {
        await _deleteCachedProfile(user.uid);
        return null;
      }
      final data = snap.data() ?? {};
      final now = DateTime.now().toUtc().toIso8601String();
      final profile = UserModel(
        userId: user.uid,
        fullName: (data['full_name'] as String?)?.trim().isNotEmpty == true
            ? data['full_name'] as String
            : (user.email ?? 'User'),
        // The sign-in email (Firebase Auth) is the source of truth; the
        // Firestore copy is only a fallback (it can contain typos).
        email: user.email ?? (data['email'] as String?) ?? '',
        phoneNumber: (data['phone_number'] as String?) ?? '',
        role: UserRole.fromString((data['role'] as String?) ?? 'employee'),
        dateCreated: (data['date_created'] as String?) ?? now,
        lastLogin: now,
      );
      await _cacheProfile(profile);
      return profile;
    } catch (e) {
      debugPrint('Profile fetch failed, using offline cache: $e');
      final cached = await _cachedProfile(user.uid);
      // Couldn't reach the server AND this device has never seen this user:
      // that's a connection problem, not "no role" — say so.
      if (cached == null) throw const AuthException(AuthFailure.network);
      return cached;
    }
  }

  Future<void> _cacheProfile(UserModel profile) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      DatabaseTables.tableUsers,
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserModel?> _cachedProfile(String uid) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.tableUsers, where: 'user_id = ?', whereArgs: [uid], limit: 1);
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  Future<void> _deleteCachedProfile(String uid) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseTables.tableUsers, where: 'user_id = ?', whereArgs: [uid]);
  }

  @visibleForTesting
  static AuthFailure mapErrorCode(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'INVALID_LOGIN_CREDENTIALS':
        return AuthFailure.invalidCredentials;
      case 'invalid-email':
        return AuthFailure.invalidEmail;
      case 'user-disabled':
        return AuthFailure.userDisabled;
      case 'too-many-requests':
        return AuthFailure.tooManyRequests;
      case 'network-request-failed':
        return AuthFailure.network;
      default:
        return AuthFailure.unknown;
    }
  }
}
