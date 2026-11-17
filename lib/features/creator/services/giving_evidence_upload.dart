import 'package:get_it/get_it.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/s3_upload.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

/// What the evidence routes accept, read off `constraints.maxSizeBytes`.
const evidenceMaxBytes = 10 * 1024 * 1024;

/// How one evidence upload ended.
typedef EvidenceUpload = ({bool attached, String? fileId, String? problem});

/// Pick a document, ticket it, send it to S3, attach it to the rail's case.
Future<EvidenceUpload> pickAndAttachEvidence({
  required String creatorId,
  required String railId,
  required String evidenceType,
  required void Function() onPicked,
  ApiService? api,
  S3Send? send,
}) async {
  final picked = await CreatorImagePicker.pick(maxBytes: evidenceMaxBytes);
  if (picked.isCancelled) {
    return (attached: false, fileId: null, problem: null);
  }
  if (picked.failure case final failure?) {
    return (
      attached: false,
      fileId: null,
      problem: switch (failure) {
        PickFailure.tooLarge => AppStrings.givingEvidenceFailed,
        PickFailure.unreadable ||
        PickFailure.unsupported => AppStrings.settingsPhotoUnreadable,
        final refusal => refusal.accessProblem,
      },
    );
  }
  final image = picked.image!;
  onPicked();

  final client = api ?? GetIt.instance<ApiService>();
  final upload = send ?? S3PresignedUpload.send;
  try {
    final ticket = await client.post(
      ApiEndpoints.givingEvidenceUploadUrl,
      data: {
        'creatorId': creatorId,
        'railId': railId,
        'evidenceType': evidenceType,
        'filename': image.filename,
        'mimeType': image.mimeType,
        // Exactly the bytes being sent: the presigned policy carries a
        // content-length-range of N,N and S3 refuses anything else.
        'size': image.size,
      },
    );
    final data =
        (ticket.data as Map<String, dynamic>?)?['data']
            as Map<String, dynamic>? ??
        const {};
    final fileId = data['fileId'] as String?;
    final uploadUrl = data['uploadUrl'] as String?;
    if (fileId == null || uploadUrl == null) {
      throw StateError('malformed evidence ticket');
    }
    await upload(
      uploadUrl: uploadUrl,
      fields: (data['fields'] as Map<String, dynamic>?) ?? const {},
      bytes: image.bytes,
      filename: image.filename,
    );
    await client.post(
      ApiEndpoints.givingEvidence,
      data: {
        'creatorId': creatorId,
        'railId': railId,
        'evidenceType': evidenceType,
        'fileId': fileId,
      },
    );
    return (attached: true, fileId: fileId, problem: null);
  } catch (e) {
    // The error only; never the ticket, which carries a presigned URL.
    logger.w('Evidence upload failed', error: e);
    return (
      attached: false,
      fileId: null,
      problem: AppStrings.givingEvidenceFailed,
    );
  }
}
