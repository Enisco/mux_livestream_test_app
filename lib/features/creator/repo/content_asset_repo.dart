import 'package:test_app/core/locator.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/s3_upload.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// The two images the content service takes, for posts and for events.
enum ContentAssetKind {
  cover('cover'),
  bodyImage('body_image');

  const ContentAssetKind(this.slug);

  final String slug;
}

/// Puts a cover or an inline image where the content service can see it.
class ContentAssetRepo {
  ContentAssetRepo([ApiService? api]) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? getIt<ApiService>();

  /// JPEG, PNG and WebP, up to 8 MB — for both kinds. The ticket states
  /// this in its refusals rather than carrying a `constraints` block the
  /// way the media routes do.
  static const maxBytes = 8 * 1024 * 1024;

  /// Returns the `fileId`, or null if the ticket came back unusable.
  Future<String?> upload({
    required String creatorId,
    required ContentAssetKind kind,
    required PickedImage image,
  }) async {
    final ticket = await _api.post(
      ApiEndpoints.contentAssetUploadUrl,
      data: {
        'creatorId': creatorId,
        'category': kind.slug,
        'filename': image.filename,
        'mimeType': image.mimeType,
        'size': image.size,
      },
    );

    final data = ticket.data['data'] as Map<String, dynamic>?;
    final fileId = data?['fileId'] as String?;
    final uploadUrl = data?['uploadUrl'] as String?;
    final fields = (data?['fields'] as Map<String, dynamic>?) ?? const {};
    if (fileId == null || uploadUrl == null || fields.isEmpty) return null;

    await S3PresignedUpload.send(
      uploadUrl: uploadUrl,
      fields: fields,
      bytes: image.bytes,
      filename: image.filename,
    );
    return fileId;
  }
}
