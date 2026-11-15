import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';

/// Picks a video or a piece of audio to upload.
abstract final class CreatorMediaPicker {
  /// Which MIME list the API will hold the upload to. `web` never applies on
  /// a phone, and the desktop targets fall back to it.
  static MediaUploadTarget get target => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => MediaUploadTarget.ios,
    TargetPlatform.android => MediaUploadTarget.android,
    _ => MediaUploadTarget.web,
  };

  /// How to ask the platform. See [pick] for why this is not
  /// [FileType.custom].
  static FileType fileTypeFor(MediaUploadKind kind) => switch (kind) {
    MediaUploadKind.video => FileType.video,
    MediaUploadKind.music => FileType.audio,
  };

  static Future<MediaPickResult> pick({required MediaUploadKind kind}) async {
    final types = uploadMimeTypes(kind, target);

    // `FileType.video` / `FileType.audio`, never `FileType.custom`:
    // custom resolves to `*/*` and hands the extensions to Android's
    // `EXTRA_MIME_TYPES` verbatim, so the picker filters on `mp4` and
    // friends — not MIME types — and opens empty. Format is still held
    // to [uploadMimeTypes]: the picker is wide, the acceptance is not.
    final result = await FilePicker.platform.pickFiles(type: fileTypeFor(kind));
    final file = result?.files.singleOrNull;
    if (file == null) return const MediaPickResult.cancelled();

    final path = file.path;
    if (path == null) {
      logger.w('Picked file has no path');
      return const MediaPickResult.failed(MediaUploadFailure.rejected);
    }

    final mimeType = types[(file.extension ?? '').toLowerCase()];
    if (mimeType == null) {
      return const MediaPickResult.failed(MediaUploadFailure.unsupportedFormat);
    }

    // `file.size` is what the picker reports; the presigned ticket is minted
    // against it, so it has to be the length that is actually sent.
    final size = await _lengthOf(path) ?? file.size;
    if (size <= 0) {
      return const MediaPickResult.failed(MediaUploadFailure.rejected);
    }
    if (size > kind.maxBytes) {
      return const MediaPickResult.failed(MediaUploadFailure.tooLarge);
    }

    return MediaPickResult.picked(
      PickedMediaFile(
        path: path,
        filename: file.name,
        mimeType: mimeType,
        size: size,
      ),
    );
  }

  static Future<int?> _lengthOf(String path) async {
    try {
      return await File(path).length();
    } catch (e) {
      logger.w('Could not measure the picked file', error: e);
      return null;
    }
  }
}

class MediaPickResult {
  const MediaPickResult._({this.file, this.failure});

  const MediaPickResult.picked(PickedMediaFile file) : this._(file: file);
  const MediaPickResult.failed(MediaUploadFailure failure)
    : this._(failure: failure);

  /// The creator backed out of the picker. Not a failure.
  const MediaPickResult.cancelled() : this._();

  final PickedMediaFile? file;
  final MediaUploadFailure? failure;

  bool get isCancelled => file == null && failure == null;
}
