import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/creator/services/creator_media_picker.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';

/// How the picker asks the platform for a file.
void main() {
  group('the picker asks the way the image picker does', () {
    void on(TargetPlatform platform) {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
    }

    test('video asks for video, not a list of extensions', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        on(platform);
        expect(
          CreatorMediaPicker.fileTypeFor(MediaUploadKind.video),
          FileType.video,
          reason: '$platform',
        );
      }
    });

    test('and on Android audio asks for audio', () {
      on(TargetPlatform.android);
      expect(
        CreatorMediaPicker.fileTypeFor(MediaUploadKind.music),
        FileType.audio,
      );
    });

    test('neither asks for custom there, which is what emptied the sheet', () {
      on(TargetPlatform.android);
      for (final kind in MediaUploadKind.values) {
        expect(
          CreatorMediaPicker.fileTypeFor(kind),
          isNot(FileType.custom),
          reason: kind.slug,
        );
      }
    });

    test('audio on iOS goes to the document picker instead', () {
      // `FileType.audio` opens `MPMediaPickerController` there, which reads
      // the Apple Music library: without `NSAppleMusicUsageDescription` iOS
      // kills the app the moment it is presented, and the tracks it returns
      // are mostly DRM-protected with no file to upload.
      on(TargetPlatform.iOS);
      expect(
        CreatorMediaPicker.fileTypeFor(MediaUploadKind.music),
        FileType.custom,
      );
    });

    test('and the extensions it offers there are ones iOS can resolve', () {
      // `FileType.custom` turns each extension into a UTI and drops the ones
      // it cannot. All of them dropped would leave the picker with nothing
      // to show.
      on(TargetPlatform.iOS);
      final offered = uploadMimeTypes(
        MediaUploadKind.music,
        MediaUploadTarget.ios,
      ).keys;
      expect(offered, containsAll(['mp3', 'm4a', 'wav']));
    });

    test('the iOS binary is never asked for the music library', () {
      // The usage string is the thing that stops the crash, and the point of
      // the document picker is that it is not needed. If the picker ever goes
      // back, this says so before a creator finds out.
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, isNot(contains('NSAppleMusicUsageDescription')));
      expect(plist, contains('<key>NSPhotoLibraryUsageDescription</key>'));
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
      // API will not take.
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
