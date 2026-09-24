import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Sending bytes to S3 against a presigned **POST** ticket.
///
/// Three routes in this app mint one of these — the channel photo and banner
/// (`/v1/creator/{id}/{kind}/upload-url`), a media thumbnail
/// (`/v1/media/thumbnail/upload-url`) and a content cover
/// (`/v1/content/assets/upload-url`) — and all three answer the same shape:
/// `{fileId, uploadUrl, key, fields, expiresAt}`. The key lands under
/// `quarantine/` and is promoted to `public/` when something names the
/// `fileId`.
///
/// This is **not** how video and audio are uploaded: those go to Mux as a
/// PUT with the bytes as the body. See `MediaUploadRepo`.
abstract final class S3PresignedUpload {
  /// A bare client: the S3 leg must carry neither the app's Authorization
  /// header nor its base URL.
  static final _plain = Dio();

  /// Posts [bytes] to [uploadUrl], with every entry of [fields] as a form
  /// field and the file last — S3 rejects any other order.
  ///
  /// The declared `size` on the ticket must be the exact byte length: the
  /// presigned policy carries `content-length-range: N,N`, so a mismatch
  /// comes back from S3 as `EntityTooSmall`.
  static Future<void> send({
    required String uploadUrl,
    required Map<String, dynamic> fields,
    required Uint8List bytes,
    required String filename,
  }) => _plain.post<void>(
    uploadUrl,
    data: FormData.fromMap({
      for (final entry in fields.entries) entry.key: '${entry.value}',
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    }),
    options: Options(validateStatus: (code) => code != null && code < 400),
  );
}
