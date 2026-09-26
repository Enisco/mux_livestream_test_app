import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/creator/services/creator_media_picker.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';

/// How the picker asks the platform for a file.
///
/// Reported from the app: "Select video" opened a sheet with **nothing in it**,
/// while "Upload thumbnail" showed the gallery properly. The two asked
/// differently — the thumbnail used `FileType.image`, the video used
/// `FileType.custom` with `allowedExtensions: [mp4, mov, m4v, webm]`.
///
/// Android turns a custom list into a SAF intent built from whatever MIME
/// types it can derive from those extensions. `mov` and `m4v` have no
/// dependable mapping, so the intent filtered down to nothing and the browser
/// opened empty.
///
/// The picker is wide now and the *acceptance* stays narrow — which is the
/// distinction worth keeping, and what these cover.
void main() {
  group('the picker asks the way the image picker does', () {
    test('video asks for video, not a list of extensions', () {
      expect(
        CreatorMediaPicker.fileTypeFor(MediaUploadKind.video),
        FileType.video,
      );
    });

    test('audio asks for audio', () {
      expect(
        CreatorMediaPicker.fileTypeFor(MediaUploadKind.music),
        FileType.audio,
      );
    });

    test('neither asks for custom, which is what emptied the sheet', () {
      for (final kind in MediaUploadKind.values) {
        expect(
          CreatorMediaPicker.fileTypeFor(kind),
          isNot(FileType.custom),
          reason: kind.slug,
        );
      }
    });
  });

  group('audio asks and refuses the same way video does', () {
    test('the accepted audio containers are unchanged, on every platform', () {
      for (final target in MediaUploadTarget.values) {
        expect(uploadMimeTypes(MediaUploadKind.music, target), {
          'mp3': 'audio/mpeg',
          'm4a': 'audio/mp4',
          'wav': 'audio/wav',
          'webm': 'audio/webm',
        }, reason: target.name);
      }
    });

    test('something the audio picker now allows through is still refused', () {
      // `.flac`, `.ogg` and `.aac` are all things an audio picker will offer
      // and the API will not take.
      final types = uploadMimeTypes(
        MediaUploadKind.music,
        MediaUploadTarget.android,
      );
      for (final ext in ['flac', 'ogg', 'aac', 'wma', 'aiff']) {
        expect(types[ext], isNull, reason: ext);
      }
    });

    test('a video cannot be passed off as audio', () {
      final audio = uploadMimeTypes(
        MediaUploadKind.music,
        MediaUploadTarget.android,
      );
      for (final ext in ['mp4', 'mov', 'm4v']) {
        expect(audio[ext], isNull, reason: ext);
      }
    });

    test('webm is the one extension both kinds take, to different types', () {
      // The same container, and the MIME must follow the kind or Mux is
      // handed a video where a track was promised.
      expect(
        uploadMimeTypes(
          MediaUploadKind.video,
          MediaUploadTarget.android,
        )['webm'],
        'video/webm',
      );
      expect(
        uploadMimeTypes(
          MediaUploadKind.music,
          MediaUploadTarget.android,
        )['webm'],
        'audio/webm',
      );
    });

    test('audio has its own, smaller ceiling', () {
      expect(MediaUploadKind.music.maxBytes, 1024 * 1024 * 1024);
      expect(
        MediaUploadKind.music.maxBytes,
        lessThan(MediaUploadKind.video.maxBytes),
      );
      expect(MediaUploadKind.music.isAudio, isTrue);
      expect(MediaUploadKind.video.isAudio, isFalse);
    });
  });

  group('a wider picker does not mean a wider upload', () {
    test('the accepted video containers are unchanged', () {
      final android = uploadMimeTypes(
        MediaUploadKind.video,
        MediaUploadTarget.android,
      );
      expect(android, {
        'mp4': 'video/mp4',
        'mov': 'video/quicktime',
        'm4v': 'video/x-m4v',
        'webm': 'video/webm',
      });
      // webm is Android's alone.
      expect(
        uploadMimeTypes(
          MediaUploadKind.video,
          MediaUploadTarget.ios,
        ).containsKey('webm'),
        isFalse,
      );
    });

    test('something the picker now allows through is still refused', () {
      // `.mkv` and `.3gp` are videos the gallery will happily offer and the
      // API will not take. They resolve to no MIME type, which is what the
      // caller turns into "Choose an MP4 or MOV".
      final types = uploadMimeTypes(
        MediaUploadKind.video,
        MediaUploadTarget.android,
      );
      for (final ext in ['mkv', '3gp', 'avi', 'wmv']) {
        expect(types[ext], isNull, reason: ext);
      }
    });

    test('and an audio file cannot be passed off as a video', () {
      final video = uploadMimeTypes(
        MediaUploadKind.video,
        MediaUploadTarget.android,
      );
      for (final ext in ['mp3', 'm4a', 'wav']) {
        expect(video[ext], isNull, reason: ext);
      }
    });

    test(
      'extensions are matched in lower case, so .MOV from an iPhone works',
      () {
        final types = uploadMimeTypes(
          MediaUploadKind.video,
          MediaUploadTarget.ios,
        );
        expect(types['MOV'.toLowerCase()], 'video/quicktime');
      },
    );
  });
}
