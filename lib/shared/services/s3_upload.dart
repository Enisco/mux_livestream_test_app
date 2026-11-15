import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Sending bytes to S3 against a presigned **POST** ticket.
typedef S3Send =
    Future<void> Function({
      required String uploadUrl,
      required Map<String, dynamic> fields,
      required Uint8List bytes,
      required String filename,
    });

abstract final class S3PresignedUpload {
  /// A bare client: the S3 leg must carry neither the app's Authorization
  /// header nor its base URL.
  static final _plain = Dio();

  /// Posts [bytes] to [uploadUrl], with every entry of [fields] as a form
  /// field and the file last — S3 rejects any other order.
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
