import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/creator_asset_repo.dart'
    show AssetUploadFailure, AssetUploadResult;
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/models/auth_models/account_challenge.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/s3_upload.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Why a credential change was refused, in terms a screen can act on.
///
/// The backend is deliberate about these: a `401` on any password-proving
/// route is uninformative and slow by design, because an authenticated route
/// that takes a password is a password oracle for anyone holding a stolen
/// access token. **Never retry one.**
enum AccountFailure {
  /// Wrong password, or wrong code. The server's own wording comes with it.
  rejected,

  /// Five wrong passwords in fifteen minutes. `retryAt` says when it lifts,
  /// and the lock is shared by the email change, the password change and
  /// turning 2FA off — all three are guesses at the same secret.
  locked,

  /// Asked again inside the cooldown. `retryAt` is `resendAvailableAt`.
  cooldown,

  /// The address belongs to someone else, or 2FA is already on.
  conflict,

  /// The request expired, or a newer one superseded it. Start again.
  expired,

  /// Refused for a reason the screen should print verbatim.
  invalid,

  network,
}

class AccountException implements Exception {
  const AccountException(this.failure, {this.message, this.retryAt});

  final AccountFailure failure;

  /// The server's words, where it gave any. The backend asks that its
  /// wording for a wrong password or a wrong code be used as-is.
  final String? message;

  /// When [AccountFailure.locked] or [AccountFailure.cooldown] lifts.
  final DateTime? retryAt;

  @override
  String toString() => 'AccountException($failure, $message)';
}

/// The reader's own account record.
///
/// Shapes probed on 2026-10-07 and widened on 2026-10-26 after the backend
/// answered `MOBILE_API_REQUESTS.md` — see `docs/mobile-api-gap-responses.md`.
///
/// - **`PATCH /v1/user/{id}`** takes `firstName`, `lastName`, `phone`,
///   `gender`, `countryCode` and — since 2026-10-26 — `language`. It still
///   refuses `email`, `password` and `avatarFileId`; those have routes of
///   their own below.
/// - **The photo is a separate pair.** `POST /v1/user/avatar/upload-url` mints
///   a presigned S3 **POST** under `quarantine/`, and
///   `POST /v1/user/avatar/confirm` with the `fileId` promotes it to
///   `public/` and sets `avatarKey`. Unlike the creator's photo, this one
///   *is* confirmed separately — saving the user does not do it.
/// - **Email, password and 2FA are `/v1/user/me/...` routes.** The email
///   change and the 2FA enrolment both answer an [AccountChallenge]; the
///   password change and the 2FA disable both prove the current password and
///   share one lockout.
///
/// Every write answers with the updated `User`, which is cached wholesale so
/// the account menu and the profile header agree with the server without a
/// second read.
class AccountRepo {
  AccountRepo({ApiService? api, S3Send? send, TokenStorageService? tokens})
    : _injected = api,
      _tokens = tokens,
      _send = send ?? S3PresignedUpload.send;

  final ApiService? _injected;

  /// Only the password change needs it — to name the session to spare.
  final TokenStorageService? _tokens;

  /// The S3 leg, injectable so a test can exercise the three-step flow
  /// without reaching the network.
  final S3Send _send;

  ApiService get _api => _injected ?? GetIt.instance<ApiService>();

  /// What staging's own `constraints.maxSizeBytes` answered for an avatar.
  /// Re-read from each ticket in case the server tightens it.
  static const avatarMaxBytes = 2 * 1024 * 1024;

  /// `GET /v1/user/profile` — the account as the server holds it.
  Future<Map<String, dynamic>> fetchProfile() async {
    final response = await _api.get(ApiEndpoints.userProfile);
    final user = _user(response.data);
    if (user.isNotEmpty) await LocalStorage.cacheUser(user);
    return user;
  }

  /// `PATCH /v1/user/{id}` with only the fields the route accepts.
  ///
  /// Returns the updated account. The caller is expected to let a failure
  /// surface: a name that silently did not save is worse than an error.
  Future<Map<String, dynamic>> updateAccount({
    String? firstName,
    String? lastName,
    String? phone,
    String? language,
    bool clearLanguage = false,
  }) async {
    final id = LocalStorage.cachedUserId;
    if (id == null) throw StateError('no cached account id');
    final response = await _api.patch(
      ApiEndpoints.user(id),
      data: {
        'firstName': ?firstName,
        'lastName': ?lastName,
        'phone': ?phone,
        // BCP 47. **Null is not English** — it means the viewer has not
        // chosen, which is the only state a client can honestly fall back to
        // the device language from.
        if (clearLanguage) 'language': null else 'language': ?language,
      },
    );
    final user = _user(response.data);
    if (user.isNotEmpty) await LocalStorage.cacheUser(user);
    return user;
  }

  /// Put a photo on the account: ticket, S3, confirm.
  ///
  /// The declared `size` must be the exact byte length — the presigned policy
  /// carries `content-length-range: N,N`. The ticket route answers **500**,
  /// not 400, when `size` is over the ceiling, which is why the ceiling is
  /// checked before the bytes are sent as well as after the ticket comes back.
  Future<AssetUploadResult> uploadAvatar(PickedImage image) async {
    try {
      if (image.size > avatarMaxBytes) {
        return const AssetUploadResult.failed(AssetUploadFailure.tooLarge);
      }

      final ticket = await _api.post(
        ApiEndpoints.userAvatarUploadUrl,
        data: {
          'filename': image.filename,
          'mimeType': image.mimeType,
          'size': image.size,
        },
      );
      final data = _user(ticket.data);
      final maxBytes =
          (data['constraints'] as Map<String, dynamic>?)?['maxSizeBytes']
              as int?;
      if (maxBytes != null && image.size > maxBytes) {
        return const AssetUploadResult.failed(AssetUploadFailure.tooLarge);
      }

      final fileId = data['fileId'] as String?;
      final uploadUrl = data['uploadUrl'] as String?;
      final fields = (data['fields'] as Map<String, dynamic>?) ?? const {};
      if (fileId == null || uploadUrl == null || fields.isEmpty) {
        logger.w('Avatar ticket was malformed');
        return const AssetUploadResult.failed(AssetUploadFailure.rejected);
      }

      await _send(
        uploadUrl: uploadUrl,
        fields: fields,
        bytes: image.bytes,
        filename: image.filename,
      );

      // Confirming is what moves the key out of `quarantine/` and writes
      // `avatarKey` onto the account. Without it the upload is invisible.
      final confirmed = await _api.post(
        ApiEndpoints.userAvatarConfirm,
        data: {'fileId': fileId},
      );
      final user = _user(confirmed.data);
      if (user.isNotEmpty) await LocalStorage.cacheUser(user);

      return AssetUploadResult.uploaded(fileId);
    } on DioException catch (e) {
      logger.w('Avatar upload failed', error: e);
      return AssetUploadResult.failed(
        e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout
            ? AssetUploadFailure.network
            : AssetUploadFailure.rejected,
      );
    } catch (e) {
      logger.e('Avatar upload failed', error: e);
      return const AssetUploadResult.failed(AssetUploadFailure.rejected);
    }
  }

  // ---- Credentials ------------------------------------------------------

  /// `POST /v1/user/me/email-change` — asks for a code.
  ///
  /// The code goes to **[newEmail]**, not the address on file: receiving it is
  /// what proves control of the new mailbox, which is the whole point of the
  /// step. The current address gets a no-code notice, which the client neither
  /// triggers nor can suppress.
  Future<AccountChallenge> requestEmailChange({
    required String newEmail,
    required String password,
  }) => _challenge(ApiEndpoints.emailChange, {
    'newEmail': newEmail.trim().toLowerCase(),
    'password': password,
  });

  Future<AccountChallenge> resendEmailChange(String challengeId) =>
      _challenge(ApiEndpoints.emailChangeResend(challengeId), null);

  /// Answers the updated `User`, so the cache is replaced rather than re-read.
  Future<Map<String, dynamic>> verifyEmailChange({
    required String challengeId,
    required String code,
  }) => _userWrite(ApiEndpoints.emailChangeVerify(challengeId), {'code': code});

  /// `POST /v1/user/me/password`.
  ///
  /// The refresh token goes in the body so the backend can tell this session
  /// from the others and spare it — the access token carries no session id.
  /// Omit it and every session dies, which comes back as
  /// `currentSessionRetained: false`; the caller must check that rather than
  /// assume it survived.
  Future<PasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final refresh =
        await (_tokens ?? GetIt.instance<TokenStorageService>()).refreshToken;
    final body = await _call(ApiEndpoints.passwordChange, {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'refreshToken': ?refresh,
    });
    final result = PasswordChangeResult.fromJson(body);
    // The only credential route that does not answer with a `User`, so the
    // one field the account menu reads is folded into the cache by hand.
    if (result.passwordChangedAt case final at?) {
      await LocalStorage.mergeCachedUser({
        'passwordChangedAt': at.toUtc().toIso8601String(),
      });
    }
    return result;
  }

  // ---- Two-factor -------------------------------------------------------

  /// `POST /v1/user/me/two-factor/enable` — **takes no password.**
  ///
  /// The emailed code is the proof, and it doubles as a check that codes
  /// actually arrive at that address, so nobody can switch 2FA on against a
  /// mailbox they cannot read and lock themselves out.
  Future<AccountChallenge> enableTwoFactor() =>
      _challenge(ApiEndpoints.twoFactorEnable, const {});

  Future<AccountChallenge> resendTwoFactor(String challengeId) =>
      _challenge(ApiEndpoints.twoFactorEnableResend(challengeId), null);

  Future<Map<String, dynamic>> verifyTwoFactor({
    required String challengeId,
    required String code,
  }) => _userWrite(ApiEndpoints.twoFactorEnableVerify(challengeId), {
    'code': code,
  });

  /// `POST /v1/user/me/two-factor/disable` — **takes the current password.**
  ///
  /// Turning the protection off is the direction an attacker on a stolen
  /// session wants, so it is re-authenticated rather than confirmed by email:
  /// a code sent to the mailbox would be the same factor being removed.
  Future<Map<String, dynamic>> disableTwoFactor(String password) =>
      _userWrite(ApiEndpoints.twoFactorDisable, {'password': password});

  Future<AccountChallenge> _challenge(String path, Object? body) async =>
      AccountChallenge.fromJson(await _call(path, body));

  /// A call whose success is the updated `User`; caches it.
  Future<Map<String, dynamic>> _userWrite(String path, Object? body) async {
    final user = await _call(path, body);
    if (user.isNotEmpty) await LocalStorage.cacheUser(user);
    return user;
  }

  /// Post, and turn a refusal into something a screen can say out loud.
  Future<Map<String, dynamic>> _call(String path, Object? body) async {
    try {
      final response = await _api.post(path, data: body ?? const {});
      return _user(response.data);
    } on DioException catch (e) {
      throw _refusal(e);
    }
  }

  /// The backend's status codes carry distinct meanings on these routes, and
  /// it asks that its own wording for a wrong password or code be shown.
  static AccountException _refusal(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const AccountException(AccountFailure.network);
    }
    final body = e.response?.data;
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final details = map['details'] is Map<String, dynamic>
        ? map['details'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final retryAt = DateTime.tryParse(
      (details['retryAt'] ?? details['resendAvailableAt']) as String? ?? '',
    );
    final raw = map['error'];
    final message = raw is String
        ? raw
        : raw is List && raw.isNotEmpty
        ? '${raw.first}'
        : null;

    return switch (e.response?.statusCode) {
      // Wrong password, wrong code — or an enrolment that aged out, which the
      // backend also answers 401. `retryAt` tells the two apart: an expiry
      // carries none.
      401 => AccountException(
        details['expired'] == true
            ? AccountFailure.expired
            : AccountFailure.rejected,
        message: message,
      ),
      409 when retryAt != null => AccountException(
        details['retryAt'] != null
            ? AccountFailure.locked
            : AccountFailure.cooldown,
        message: message,
        retryAt: retryAt,
      ),
      409 => AccountException(AccountFailure.conflict, message: message),
      _ => AccountException(AccountFailure.invalid, message: message),
    };
  }

  static Map<String, dynamic> _user(Object? body) {
    final data = (body as Map<String, dynamic>?)?['data'];
    return data is Map<String, dynamic> ? data : const {};
  }
}
