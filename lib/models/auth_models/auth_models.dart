import 'dart:convert';

class GtubeUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? gender;
  final String? countryCode;
  final String role;
  final String status;
  final String? avatarFileId;
  final String? avatarKey;
  final List<String> viewerPreferenceCategorySlugs;
  final DateTime? viewerPreferencesCompletedAt;
  final DateTime? suspendedAt;
  final DateTime? deletedAt;
  final DateTime updatedAt;
  final DateTime createdAt;

  const GtubeUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.gender,
    this.countryCode,
    required this.role,
    required this.status,
    this.avatarFileId,
    this.avatarKey,
    required this.viewerPreferenceCategorySlugs,
    this.viewerPreferencesCompletedAt,
    this.suspendedAt,
    this.deletedAt,
    required this.updatedAt,
    required this.createdAt,
  });

  factory GtubeUser.fromJson(Map<String, dynamic> json) => GtubeUser(
    id: json['id'] as String,
    email: json['email'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    phone: json['phone'] as String?,
    gender: json['gender'] as String?,
    countryCode: json['countryCode'] as String?,
    role: json['role'] as String,
    status: json['status'] as String,
    avatarFileId: json['avatarFileId'] as String?,
    avatarKey: json['avatarKey'] as String?,
    viewerPreferenceCategorySlugs:
        (json['viewerPreferenceCategorySlugs'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
    viewerPreferencesCompletedAt: json['viewerPreferencesCompletedAt'] != null
        ? DateTime.tryParse(json['viewerPreferencesCompletedAt'] as String)
        : null,
    suspendedAt: json['suspendedAt'] != null
        ? DateTime.tryParse(json['suspendedAt'] as String)
        : null,
    deletedAt: json['deletedAt'] != null
        ? DateTime.tryParse(json['deletedAt'] as String)
        : null,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'gender': gender,
    'countryCode': countryCode,
    'role': role,
    'status': status,
    'avatarFileId': avatarFileId,
    'avatarKey': avatarKey,
    'viewerPreferenceCategorySlugs': viewerPreferenceCategorySlugs,
    'viewerPreferencesCompletedAt': viewerPreferencesCompletedAt
        ?.toIso8601String(),
    'suspendedAt': suspendedAt?.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  String get fullName => '$firstName $lastName'.trim();

  String toJsonString() => jsonEncode(toJson());

  static GtubeUser? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return GtubeUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

class GtubeSession {
  final String id;
  final String userId;
  final String familyId;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final DateTime? revokedAt;
  final String? userAgent;
  final String? ip;

  const GtubeSession({
    required this.id,
    required this.userId,
    required this.familyId,
    required this.expiresAt,
    required this.createdAt,
    required this.lastUsedAt,
    this.revokedAt,
    this.userAgent,
    this.ip,
  });

  factory GtubeSession.fromJson(Map<String, dynamic> json) => GtubeSession(
    id: json['id'] as String,
    userId: json['userId'] as String,
    familyId: json['familyId'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
    revokedAt: json['revokedAt'] != null
        ? DateTime.tryParse(json['revokedAt'] as String)
        : null,
    userAgent: json['userAgent'] as String?,
    ip: json['ip'] as String?,
  );
}

class LoginResponse {
  final String type;
  final GtubeUser user;
  final GtubeSession session;
  final String accessToken;
  final String refreshToken;

  const LoginResponse({
    required this.type,
    required this.user,
    required this.session,
    required this.accessToken,
    required this.refreshToken,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    return LoginResponse(
      type: data['type'] as String? ?? 'LOGGED_IN',
      user: GtubeUser.fromJson(data['user'] as Map<String, dynamic>),
      session: GtubeSession.fromJson(data['session'] as Map<String, dynamic>),
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }
}

class RegisterResponse {
  final GtubeUser user;

  const RegisterResponse({required this.user});

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return RegisterResponse(user: GtubeUser.fromJson(data));
  }
}

class RefreshSessionResponse {
  final GtubeUser user;
  final String accessToken;
  final String refreshToken;

  const RefreshSessionResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory RefreshSessionResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return RefreshSessionResponse(
      user: GtubeUser.fromJson(data['user'] as Map<String, dynamic>),
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }
}
