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
  /// The owner removed this account's access (users/{uid} was deleted).
  accessRemoved,
  /// The owner changed this account's role while it was signed in.
  roleChanged,
  /// Offline for longer than [FirebaseAuthService.offlineGrace] — must go
  /// online once so the server can confirm the account is still allowed.
  offlineTooLong,
  unknown,
}

/// A change to the signed-in account noticed while the app is open.
enum AccessChange { removed, roleChanged }

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

  /// How long a non-owner may keep using the app offline (app restarts
  /// included) before the server must confirm the account again. Limits how
  /// long a removed staff member can keep working on a phone kept offline.
  static const Duration offlineGrace = Duration(days: 7);

  static const Duration _serverTimeout = Duration(seconds: 10);

  /// Whether a profile cached on this device may still be used without
  /// asking the server. [lastVerified] = last time the server confirmed it.
  /// Owners are never locked out of their own shop.
  @visibleForTesting
  static bool cachedAccessStillValid({
    required UserRole role,
    required DateTime? lastVerified,
    required DateTime now,
  }) {
    if (role == UserRole.owner) return true;
    if (lastVerified == null) return false;
    return now.difference(lastVerified) <= offlineGrace;
  }

  /// Signs in and returns the user's profile (with role).
  /// Throws [AuthException] on failure; nothing is kept signed in on failure.
  /// The role is ALWAYS confirmed with the server here (never an offline
  /// copy), so a removed account cannot sign in again.
  Future<UserModel> signIn({required String email, required String password}) async {
    final cleanEmail = email.trim();
    try {
      final cred = await auth.signInWithEmailAndPassword(email: cleanEmail, password: password);
      final user = cred.user;
      if (user == null) throw const AuthException(AuthFailure.unknown);

      final UserModel? profile;
      try {
        profile = await _fetchProfileFromServer(user);
      } catch (e) {
        debugPrint('Role check failed during sign-in: $e');
        await auth.signOut(); // couldn't verify the role — don't stay half signed in
        throw const AuthException(AuthFailure.network);
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

  /// Returns the signed-in user's profile if a session was persisted,
  /// otherwise null. Online: the server decides (removed → signed out and
  /// [AuthFailure.accessRemoved] thrown). Offline: the SQLite copy is used
  /// within [offlineGrace]; past it [AuthFailure.offlineTooLong] is thrown
  /// (the session is kept so it works again once online).
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
      profile = await _fetchProfileFromServer(user);
    } catch (e) {
      // Offline (or server slow): fall back to this device's copy, but only
      // for a limited time since the server last confirmed it.
      debugPrint('Profile check offline, using device copy: $e');
      final cached = await _cachedProfile(user.uid);
      // Never cached here: show the login screen, but keep the Firebase
      // session so it can be restored next time the device is online.
      if (cached == null) return null;
      final ok = cachedAccessStillValid(
        role: cached.role,
        lastVerified: DateTime.tryParse(cached.lastLogin ?? ''),
        now: DateTime.now().toUtc(),
      );
      if (!ok) throw const AuthException(AuthFailure.offlineTooLong);
      return cached;
    }
    if (profile == null) {
      await auth.signOut();
      throw const AuthException(AuthFailure.accessRemoved);
    }
    return profile;
  }

  /// Emits when the signed-in account is removed or its role changes while
  /// the app is open. Only answers confirmed by the SERVER count (never the
  /// offline cache), so going offline never logs anyone out.
  Stream<AccessChange> watchAccess(String uid, UserRole currentRole) {
    return firestore
        .collection(usersCollection)
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .where((snap) => !snap.metadata.isFromCache)
        .map<AccessChange?>((snap) {
          if (!snap.exists) return AccessChange.removed;
          final role = UserRole.fromString((snap.data()?['role'] as String?) ?? 'employee');
          return role == currentRole ? null : AccessChange.roleChanged;
        })
        .where((change) => change != null)
        .cast<AccessChange>();
  }

  /// Ends the session after the owner removed this account: signs out and
  /// forgets the cached profile so it can't be used offline either.
  Future<void> signOutRemoved(String uid) async {
    await signOut();
    try {
      await _deleteCachedProfile(uid);
    } catch (e) {
      debugPrint('Could not clear cached profile: $e');
    }
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

  /// Reads users/{uid} from the SERVER only (never Firestore's offline
  /// cache, which could still hold a removed account's old role).
  /// Returns null when the server says there is no profile (and forgets the
  /// device copy); throws when the server can't be reached.
  /// On success the profile is cached with `last_login` = now, which is the
  /// "last confirmed by the server" time used for [offlineGrace].
  Future<UserModel?> _fetchProfileFromServer(User user) async {
    final snap = await firestore
        .collection(usersCollection)
        .doc(user.uid)
        .get(const GetOptions(source: Source.server))
        .timeout(_serverTimeout);
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
