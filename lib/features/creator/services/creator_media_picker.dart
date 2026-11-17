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

  /// How to ask the platform.
  ///
  /// `FileType.video` and `FileType.audio` on Android, never
  /// `FileType.custom`: custom resolves to `*/*` and the extension filter has
  /// to survive a round trip through `MimeTypeMap`, which drops whatever that
  /// device has not heard of. Format is still held to [uploadMimeTypes]: the
  /// picker is wide, the acceptance is not.
  ///
  /// **Audio on iOS is the exception.** `FileType.audio` there opens
  /// `MPMediaPickerController`, which reads the *Apple Music* library: it
  /// needs `NSAppleMusicUsageDescription` — without it iOS kills the app the
  /// moment the picker is presented — and the tracks it returns are mostly
  /// DRM-protected with no file to upload. The document picker is both safe
  /// and where a sermon recording actually lives.
  static FileType fileTypeFor(MediaUploadKind kind) => switch (kind) {
    MediaUploadKind.video => FileType.video,
    MediaUploadKind.music =>
      target == MediaUploadTarget.ios ? FileType.custom : FileType.audio,
  };

  static Future<MediaPickResult> pick({required MediaUploadKind kind}) async {
    final types = uploadMimeTypes(kind, target);
    final fileType = fileTypeFor(kind);

    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: fileType == FileType.custom
            ? types.keys.toList(growable: false)
            : null,
      );
    } catch (e) {
      // `pickFiles` rethrows whatever the platform raised: a picker already
      // open, a provider that will not give the bytes up, a host activity
      // the system reclaimed while the picker was up. Unhandled, each of
      // those is a crash where a sentence will do.
      logger.w('Media picker failed', error: e);
      return const MediaPickResult.failed(MediaUploadFailure.pickerFailed);
    }
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
