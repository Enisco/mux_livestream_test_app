import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/creator_asset_repo.dart'
    show AssetUploadFailure, AssetUploadResult;
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/s3_upload.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Sending the bytes to S3. [S3PresignedUpload.send] in production.
typedef S3Send =
    Future<void> Function({
      required String uploadUrl,
      required Map<String, dynamic> fields,
      required Uint8List bytes,
      required String filename,
    });

/// The reader's own account record.
///
/// The auth guide lists these routes under "not yet client-integrated — treat
/// as unverified", so everything below was read off staging on 2026-10-07
/// rather than from the guide:
///
/// - **`PATCH /v1/user/{id}`** takes `firstName`, `lastName`, `phone`,
///   `gender` and `countryCode`. It **refuses** `email`, `password`,
///   `language`, `displayName` and `avatarFileId` — each answers
///   *"property … should not exist"*. So this screen can change a name and a
///   phone number and nothing else; an email or password change has no route
///   at all (see `docs/OPEN_ISSUES.md`).
/// - **The photo is a separate pair.** `POST /v1/user/avatar/upload-url` mints
///   a presigned S3 **POST** under `quarantine/`, and
///   `POST /v1/user/avatar/confirm` with the `fileId` promotes it to
///   `public/` and sets `avatarKey` on the account. Unlike the creator's
///   photo, this one *is* confirmed separately — saving the user does not do
///   it.
///
/// Every write answers with the updated `User`, which is cached wholesale so
/// the account menu and the profile header agree with the server without a
/// second read.
class AccountRepo {
  AccountRepo({ApiService? api, S3Send? send})
    : _injected = api,
      _send = send ?? S3PresignedUpload.send;

  final ApiService? _injected;

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
  }) async {
    final id = LocalStorage.cachedUserId;
    if (id == null) throw StateError('no cached account id');
    final response = await _api.patch(
      ApiEndpoints.user(id),
      data: {'firstName': ?firstName, 'lastName': ?lastName, 'phone': ?phone},
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

  static Map<String, dynamic> _user(Object? body) {
    final data = (body as Map<String, dynamic>?)?['data'];
    return data is Map<String, dynamic> ? data : const {};
  }
}
