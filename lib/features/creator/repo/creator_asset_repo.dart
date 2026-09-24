import 'package:dio/dio.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/s3_upload.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// The two images a channel carries, and what staging will accept for each.
///
/// The ceilings are not guesses: each `upload-url` response returns its own
/// `constraints.maxSizeBytes`, and these are what staging answered. They are
/// held here so the picker can turn an oversized file away before a request
/// is made, and are re-read from the response on every upload in case the
/// server tightens them.
enum CreatorAssetKind {
  avatar('avatar', 2 * 1024 * 1024),
  banner('banner', 8 * 1024 * 1024);

  const CreatorAssetKind(this.slug, this.maxBytes);

  final String slug;
  final int maxBytes;
}

/// Where the upload went wrong, in terms the screen can explain.
enum AssetUploadFailure { tooLarge, rejected, network }

class AssetUploadResult {
  const AssetUploadResult._({this.fileId, this.failure});

  const AssetUploadResult.uploaded(String fileId) : this._(fileId: fileId);
  const AssetUploadResult.failed(AssetUploadFailure failure)
    : this._(failure: failure);

  /// The id to hand to `POST /v1/creator/onboard` or `PATCH /v1/creator/{id}`.
  final String? fileId;
  final AssetUploadFailure? failure;
}

/// Puts a channel photo or banner where the API can see it.
///
/// Three steps, all verified against staging:
///
///  1. `POST /v1/creator/{id}/{kind}/upload-url` with `{filename, mimeType,
///     size}` returns `{fileId, uploadUrl, key, fields, expiresAt,
///     constraints}`. The key lands under `quarantine/`.
///  2. The bytes go straight to S3 as a presigned **POST** — every entry of
///     `fields` as a form field, the file last. S3 answers `204`.
///  3. Nothing is confirmed separately. Saving the creator with the returned
///     `fileId` is what promotes the key from `quarantine/` to `public/`.
///
/// The declared `size` must be the exact byte length: the presigned policy
/// carries `content-length-range: N,N`, so a mismatch is refused by S3 with
/// `EntityTooSmall`.
class CreatorAssetRepo {
  CreatorAssetRepo(this._api);

  final ApiService _api;

  Future<AssetUploadResult> upload({
    required String creatorId,
    required CreatorAssetKind kind,
    required PickedImage image,
  }) async {
    try {
      final ticket = await _api.post(
        ApiEndpoints.creatorAssetUploadUrl(creatorId, kind.slug),
        data: {
          'filename': image.filename,
          'mimeType': image.mimeType,
          'size': image.size,
        },
      );

      final data = ticket.data['data'] as Map<String, dynamic>?;
      if (data == null) return _fail(AssetUploadFailure.rejected, 'no data');

      // Honour the server's own ceiling over the one compiled in, so a
      // tightened limit is respected without a release.
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
        return _fail(AssetUploadFailure.rejected, 'malformed ticket');
      }

      await S3PresignedUpload.send(
        uploadUrl: uploadUrl,
        fields: fields,
        bytes: image.bytes,
        filename: image.filename,
      );
      logger.i('Uploaded ${kind.slug} (${image.size}B)');

      return AssetUploadResult.uploaded(fileId);
    } on DioException catch (e) {
      // The gateway answers 500 rather than 400 when `size` is over the
      // ceiling, so an oversized file cannot be told apart from a real
      // outage by status alone — the pre-check above is what catches it.
      logger.w('Asset upload failed', error: e);
      return AssetUploadResult.failed(
        e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout
            ? AssetUploadFailure.network
            : AssetUploadFailure.rejected,
      );
    } catch (e) {
      logger.e('Asset upload failed', error: e);
      return const AssetUploadResult.failed(AssetUploadFailure.rejected);
    }
  }

  AssetUploadResult _fail(AssetUploadFailure failure, String why) {
    logger.w('Asset upload rejected: $why');
    return AssetUploadResult.failed(failure);
  }
}
