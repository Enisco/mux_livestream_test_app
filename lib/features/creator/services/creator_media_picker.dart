import 'dart:io';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/utils/helpers/keyboard.dart';

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
    // The system picker is presented over Flutter's view and does not take
    // the keyboard with it, so a tap from the focused title field left one
    // standing in front of the picker.
    dismissKeyboard();

    final types = uploadMimeTypes(kind, target);
    final fileType = fileTypeFor(kind);

    final PlatformFile? file;
    try {
      file = await FilePickerPlatform.instance.pickFile(
        type: fileType,
        allowedExtensions: fileType == FileType.custom
            ? types.keys.toList(growable: false)
            : null,
      );
    } on PlatformException catch (e) {
      // The code **and** the details: the plugin reports a picker that
      // would not open and a file it could not read through the same throw,
      // and only the code tells them apart. The details carry the system's
      // own error, which is the whole diagnosis when a creator says the
      // button did nothing.
      logger.w(
        'Media picker failed: ${e.code} — ${e.message}'
        '${e.details == null ? '' : ' (${e.details})'}',
      );
      return MediaPickResult.failed(readFailure(e.code));
    } catch (e) {
      // `pickFile` rethrows whatever the platform raised: a picker already
      // open, a provider that will not give the bytes up, a host activity
      // the system reclaimed while the picker was up. Unhandled, each of
      // those is a crash where a sentence will do.
      logger.w('Media picker failed', error: e);
      return const MediaPickResult.failed(MediaUploadFailure.pickerFailed);
    }
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

    // The length the ticket is minted against has to be the length that is
    // actually sent, so the file on disk is measured first; `length()` is
    // the picker's own answer and the fallback when it cannot be.
    final size = await _lengthOf(path) ?? await file.length() ?? 0;
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

  /// Which platform codes mean *picked, then unreadable* rather than *the
  /// picker would not open*.
  ///
  /// `load_failed` is what the picker answers when it could load none of
  /// the chosen items, and its `details` carry each one's `domain`, `code`
  /// and `message` plus the chain of errors underneath.
  ///
  /// **What this was actually hiding.** `file_picker` 8.3.7 raised it for
  /// every iPhone HEVC recording, through four separate faults: it asked
  /// for the abstract `public.movie` rather than the item's own type, so
  /// the picker had to transcode; it read the whole file into an `NSData`
  /// before writing it out again; it named any extension-less video
  /// `.jpg`; and it appended to a plain `NSMutableArray` from arbitrary
  /// completion queues, which is what crashed afterwards. A small test
  /// `.mp4` survived all four. Nothing in Dart could have fixed any of
  /// them — the upgrade did.
  ///
  /// `file_picker_error` was the 8.x name for the same thing, kept because
  /// a code that no longer arrives costs nothing and a mismapped one costs
  /// a creator the right sentence.
  ///
  /// Everything else — `already_active`, `no_activity`, an unsupported
  /// picker type — is the picker itself, and there is nothing to suggest.
  @visibleForTesting
  static MediaUploadFailure readFailure(String code) => switch (code) {
    'file_picker_error' || 'load_failed' => MediaUploadFailure.sourceUnreadable,
    _ => MediaUploadFailure.pickerFailed,
  };

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
