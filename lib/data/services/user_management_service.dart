import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../../domain/entities/enums.dart';
import 'firebase_auth_service.dart';

/// Why a user-management action failed. The UI maps these to messages.
enum UserAdminFailure { emailInUse, invalidEmail, weakPassword, network, permissionDenied, unknown }

class UserAdminException implements Exception {
  final UserAdminFailure reason;
  final String? detail;
  const UserAdminException(this.reason, [this.detail]);

  @override
  String toString() => 'UserAdminException(${reason.name}${detail != null ? ': $detail' : ''})';
}

/// Owner-only staff management (PRD §5, §28 "User Management").
///
/// Accounts are created through a SECONDARY Firebase app instance, because
/// creating a user with the normal instance would sign the owner out and sign
/// the new user in. Roles live in Firestore `users/{uid}`, which only an owner
/// may write (firestore.rules).
class UserManagementService {
  static const String _secondaryAppName = 'coki-user-admin';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirebaseAuthService.usersCollection);

  Future<List<UserModel>> listUsers() async {
    try {
      final snap = await _users.get();
      final users = snap.docs.map((d) => _fromDoc(d.id, d.data())).toList();
      // Owners first, then admins, then employees; alphabetical within.
      users.sort((a, b) {
        final byRole = a.role.index.compareTo(b.role.index);
        return byRole != 0 ? byRole : a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });
      return users;
    } on FirebaseException catch (e) {
      throw UserAdminException(_mapFirestore(e.code), e.code);
    }
  }

  /// Creates the login (email + temporary password) and the role record.
  Future<UserModel> createUser({
    required String fullName,
    required String email,
    required String phoneNumber,
    required UserRole role,
    required String temporaryPassword,
  }) async {
    final secondaryAuth = FirebaseAuth.instanceFor(app: await _secondaryApp());
    User? created;
    try {
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: temporaryPassword,
      );
      created = cred.user;
      if (created == null) throw const UserAdminException(UserAdminFailure.unknown);

      final now = DateTime.now().toUtc().toIso8601String();
      final data = {
        'full_name': fullName.trim(),
        'email': email.trim(),
        'phone_number': phoneNumber.trim(),
        'role': role.name,
        'date_created': now,
        'created_by': FirebaseAuth.instance.currentUser?.uid,
      };
      // Written with the OWNER's session (primary app) — rules allow owners only.
      await _users.doc(created.uid).set(data);
      return _fromDoc(created.uid, data);
    } on FirebaseAuthException catch (e) {
      throw UserAdminException(_mapAuth(e.code), e.code);
    } on FirebaseException catch (e) {
      // Role record failed: undo the half-created login so the email can be reused.
      try {
        await created?.delete();
      } catch (cleanupError) {
        debugPrint('Could not clean up auth user: $cleanupError');
      }
      throw UserAdminException(_mapFirestore(e.code), e.code);
    } finally {
      await secondaryAuth.signOut();
    }
  }

  Future<void> changeRole(String uid, UserRole role) async {
    try {
      await _users.doc(uid).update({'role': role.name});
    } on FirebaseException catch (e) {
      throw UserAdminException(_mapFirestore(e.code), e.code);
    }
  }

  /// Removes the role record, so the account can no longer sign in (the app
  /// refuses logins without a record). Sales/credit history is untouched.
  /// The email/password login itself remains in Firebase Authentication and
  /// can be deleted there if needed.
  Future<void> removeAccess(String uid) async {
    try {
      await _users.doc(uid).delete();
    } on FirebaseException catch (e) {
      throw UserAdminException(_mapFirestore(e.code), e.code);
    }
  }

  // ---------------------------------------------------------------------------

  Future<FirebaseApp> _secondaryApp() async {
    try {
      return Firebase.app(_secondaryAppName);
    } catch (_) {
      return Firebase.initializeApp(name: _secondaryAppName, options: Firebase.app().options);
    }
  }

  static UserModel _fromDoc(String uid, Map<String, dynamic> data) {
    return UserModel(
      userId: uid,
      fullName: (data['full_name'] as String?)?.trim().isNotEmpty == true
          ? data['full_name'] as String
          : ((data['email'] as String?) ?? 'User'),
      email: (data['email'] as String?) ?? '',
      phoneNumber: (data['phone_number'] as String?) ?? '',
      role: UserRole.fromString((data['role'] as String?) ?? 'employee'),
      dateCreated: (data['date_created'] as String?) ?? '',
    );
  }

  static UserAdminFailure _mapAuth(String code) {
    switch (code) {
      case 'email-already-in-use':
        return UserAdminFailure.emailInUse;
      case 'invalid-email':
        return UserAdminFailure.invalidEmail;
      case 'weak-password':
        return UserAdminFailure.weakPassword;
      case 'network-request-failed':
        return UserAdminFailure.network;
      default:
        return UserAdminFailure.unknown;
    }
  }

  static UserAdminFailure _mapFirestore(String code) {
    switch (code) {
      case 'permission-denied':
        return UserAdminFailure.permissionDenied;
      case 'unavailable':
        return UserAdminFailure.network;
      default:
        return UserAdminFailure.unknown;
    }
  }
}
