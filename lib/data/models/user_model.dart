import '../../domain/entities/enums.dart';

class UserModel {
  final String userId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final UserRole role;
  final String dateCreated;
  final String? lastLogin;

  UserModel({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.dateCreated,
    this.lastLogin,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'role': role.name,
      'date_created': dateCreated,
      'last_login': lastLogin,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['user_id'] ?? '',
      fullName: map['full_name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phone_number'] ?? '',
      role: UserRole.fromString(map['role'] ?? 'employee'),
      dateCreated: map['date_created'] ?? DateTime.now().toUtc().toIso8601String(),
      lastLogin: map['last_login'],
    );
  }

  UserModel copyWith({
    String? userId,
    String? fullName,
    String? email,
    String? phoneNumber,
    UserRole? role,
    String? dateCreated,
    String? lastLogin,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      dateCreated: dateCreated ?? this.dateCreated,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
