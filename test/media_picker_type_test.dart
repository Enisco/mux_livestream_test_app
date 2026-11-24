import 'dart:io';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
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

  group('what the platform refused, and whether there is anything to say', () {
    test(
      'a file that was picked and then could not be read is its own case',
      () {
        // iOS answers `file_picker_error` — its own message is "Failed to
        // process any images", whatever was picked — when it could load
        // none of the chosen items. In this app it meant one thing almost
        // every time: an iPhone HEVC recording that `file_picker` 8.3.7
        // could not hand over. See `CreatorMediaPicker.readFailure` for the
        // four faults behind it. Reporting it as "the gallery would not
        // open" sent creators looking for a permission that was never the
        // problem.
        expect(
          CreatorMediaPicker.readFailure('file_picker_error'),
          MediaUploadFailure.sourceUnreadable,
        );
        expect(
          CreatorMediaPicker.readFailure('load_failed'),
          MediaUploadFailure.sourceUnreadable,
        );
      },
    );

    test('while the picker refusing to open at all stays what it was', () {
      for (final code in [
        'already_active',
        'no_activity',
        'Unsupported picker type',
      ]) {
        expect(
          CreatorMediaPicker.readFailure(code),
          MediaUploadFailure.pickerFailed,
          reason: code,
        );
      }
    });
  });

  group('what a phone can actually hand over', () {
    test('an iPhone recording resolves whatever case it arrives in', () {
      // The camera writes IMG_1234.MOV, upper case, and the picker hands
      // the name through unchanged. A lookup that did not fold case would
      // reject every iPhone video as an unknown format after the pick had
      // already succeeded.
      final types = uploadMimeTypes(
        MediaUploadKind.video,
        MediaUploadTarget.ios,
      );
      expect(types['MOV'.toLowerCase()], 'video/quicktime');
    });

    test('and the map says no more than the API does', () {
      // The server answers `constraints.allowedMimeTypes` with exactly
      // these. Widening the client alone turns a clear refusal before the
      // upload into a failure after one.
      const fromStaging = {
        'video/mp4',
        'video/quicktime',
        'video/x-m4v',
        'video/webm',
      };
      final android = uploadMimeTypes(
        MediaUploadKind.video,
        MediaUploadTarget.android,
      );
      expect(android.values.toSet().difference(fromStaging), isEmpty);
    });
  });

  group('the packages the pick goes through', () {
    late final String pubspec = File('pubspec.yaml').readAsStringSync();

    test('the platform implementations are depended on directly', () {
      // `file_picker` 13 is federated, and its umbrella pulls
      // `windows_file_picker` -> `win32 ^6`, which this app cannot take:
      // `flutter_secure_storage` 9 pins `win32 ^5` through its own Windows
      // implementation, so the umbrella forces a 9 -> 11 jump on the
      // package that holds the session tokens. That release rewrote the
      // Android keystore layer and ships `checkUpgradeStatus()` to report
      // what a direct major upgrade lost — a signed-out fleet in exchange
      // for a Windows picker this app does not ship.
      //
      // Depending on the two implementations instead keeps `win32` at 5
      // and every stored token where it is. Both declare
      // `implements: file_picker`, so Flutter still registers them:
      // `FilePickerAndroid.registerWith()` and
      // `FilePickerDarwin.registerWith()` are in the generated Dart plugin
      // registrant, which is what sets `FilePickerPlatform.instance`.
      expect(pubspec, contains('file_picker_darwin:'));
      expect(pubspec, contains('android_file_picker:'));
      expect(pubspec, contains('file_picker_platform_interface:'));
    });

    test('and the umbrella is not, which is what keeps win32 at 5', () {
      // `flutter pub add file_picker` would undo all of the above without
      // saying so. The pick would still work; the sign-ins would not.
      expect(
        RegExp(r'^  file_picker:', multiLine: true).hasMatch(pubspec),
        isFalse,
        reason:
            'the file_picker umbrella is back, which drags win32 ^6 and '
            'forces flutter_secure_storage to 11',
      );
      expect(
        RegExp(
          r'^  flutter_secure_storage: \^9\.',
          multiLine: true,
        ).hasMatch(pubspec),
        isTrue,
        reason: 'the token store moved major versions',
      );
    });
  });
}
