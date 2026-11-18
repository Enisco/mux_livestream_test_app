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
    // Nullable on purpose, though registration requires both: an account
    // created by Apple sign-in has whatever name the person chose to share,
    // and they may share none — Apple puts no name in the token and hands
    // one to the client on the first authorization only. `as String` threw
    // a TypeError on that account, at sign-in, with nothing to read.
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
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

/// Thrown when a 200 carries something no client can act on.
///
/// The gateway's own contract makes this reachable rather than theoretical:
/// a `LOGGED_IN` body omits `accessToken` and `refreshToken` for
/// `clientType: "web"`, so a build that stopped sending `"native"` would
/// parse a perfectly valid response into a session with no tokens in it.
/// Better a sentence the screen can show than a `TypeError` on a device.
class AuthContractException implements Exception {
  const AuthContractException(this.detail);

  final String detail;

  @override
  String toString() => 'AuthContractException($detail)';
}

/// What login, two-factor verification and provider sign-in all answer.
///
/// `data` is a **union discriminated on `type`**, and the integration guide
/// is blunt about it: *"Always branch on it; never assume login succeeded
/// because the HTTP status was 200."* Reading the tokens straight out of
/// `data` threw on every account with the second factor on — which is the
/// platform default.
sealed class AuthOutcome {
  const AuthOutcome();

  /// The one `type` that is not a session.
  static const challengeType = '2FA_REQUIRED';

  /// Reads the whole `{success, data}` envelope.
  factory AuthOutcome.fromEnvelope(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    if (data['type'] == challengeType) {
      // The challenge sits one level deeper than everything else in the
      // union: `data.data.challengeId`, not `data.challengeId`.
      final inner = data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : const <String, dynamic>{};
      final challengeId = inner['challengeId'] as String?;
      if (challengeId == null || challengeId.isEmpty) {
        throw const AuthContractException(
          '2FA_REQUIRED carried no challengeId',
        );
      }
      return AuthChallengeRequired(
        challengeId: challengeId,
        expiresInMinutes: (inner['expiresInMinutes'] as num?)?.toInt() ?? 10,
        // Only the provider routes document an address here; a password
        // login already knows the one that was typed.
        email: (data['email'] ?? inner['email']) as String?,
        isNewUser: data['isNewUser'] == true,
      );
    }

    return AuthSignedIn(LoginResponse.fromData(data));
  }
}

/// A session exists. The tokens are already stored by the time a screen
/// sees this.
final class AuthSignedIn extends AuthOutcome {
  const AuthSignedIn(this.session);

  final LoginResponse session;
}

/// No session yet: the account wants the code it was just emailed.
final class AuthChallengeRequired extends AuthOutcome {
  const AuthChallengeRequired({
    required this.challengeId,
    required this.expiresInMinutes,
    this.email,
    this.isNewUser = false,
  });

  final String challengeId;

  /// How long the code lasts, in minutes. **Nothing displays it**: the
  /// screen's own countdown is the 60-second resend cooldown, which is a
  /// different thing, and the 2FA routes publish no `resendAvailableAt`
  /// like the account-change ones do. Kept because it is the field the
  /// route sends and the only thing it says about expiry.
  final int expiresInMinutes;

  /// Where the code went, for the screen to name. An Apple private relay
  /// address is possible.
  final String? email;

  /// Carried through the challenge so the screen past it knows whether to
  /// start onboarding or go home.
  final bool isNewUser;
}

class LoginResponse {
  final String type;
  final GtubeUser user;
  final GtubeSession session;
  final String accessToken;
  final String refreshToken;

  /// Set by the provider routes when that call **created** the account, so
  /// the app knows to start onboarding rather than open the feed. Always
  /// false for a password login, which cannot create anything.
  final bool isNewUser;

  const LoginResponse({
    required this.type,
    required this.user,
    required this.session,
    required this.accessToken,
    required this.refreshToken,
    this.isNewUser = false,
  });

  /// Reads the `LOGGED_IN` arm of the union — the contents of `data`, not
  /// the envelope. Use [AuthOutcome.fromEnvelope] unless the shape is
  /// already known to be a session.
  factory LoginResponse.fromData(Map<String, dynamic> data) {
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw AuthContractException(
        'a ${data['type'] ?? 'LOGGED_IN'} answer carried no session tokens',
      );
    }
    if (data['user'] is! Map<String, dynamic> ||
        data['session'] is! Map<String, dynamic>) {
      throw const AuthContractException(
        'a signed-in answer carried no user or session',
      );
    }
    return LoginResponse(
      type: data['type'] as String? ?? 'LOGGED_IN',
      user: GtubeUser.fromJson(data['user'] as Map<String, dynamic>),
      session: GtubeSession.fromJson(data['session'] as Map<String, dynamic>),
      accessToken: accessToken,
      refreshToken: refreshToken,
      isNewUser: data['isNewUser'] == true,
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
