import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The manifest entries a permission needs before Android will grant it.
///
/// A permission asked for without being declared does not prompt: the system
/// answers "denied, for good" straight away. That is exactly the shape of the
/// bug readers reported — the picker opening and then failing, or the prompt
/// never appearing at all — so it is worth a test rather than a careful read
/// of the manifest.
void main() {
  /// Permission.x in Dart -> the manifest permissions it maps to on Android.
  ///
  /// The SDK split matters: `Permission.photos` is `READ_MEDIA_IMAGES` from
  /// API 33 and `Permission.storage` is `READ_EXTERNAL_STORAGE` below it, so
  /// both have to be declared for one code path.
  const needs = <String, List<String>>{
    'camera': ['android.permission.CAMERA'],
    'microphone': ['android.permission.RECORD_AUDIO'],
    'photos': ['android.permission.READ_MEDIA_IMAGES'],
    'videos': ['android.permission.READ_MEDIA_VIDEO'],
    'audio': ['android.permission.READ_MEDIA_AUDIO'],
    'storage': ['android.permission.READ_EXTERNAL_STORAGE'],
    'notification': ['android.permission.POST_NOTIFICATIONS'],
    'location': ['android.permission.ACCESS_FINE_LOCATION'],
    'contacts': ['android.permission.READ_CONTACTS'],
    'calendar': ['android.permission.READ_CALENDAR'],
    'speech': ['android.permission.RECORD_AUDIO'],
  };

  late final String manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  /// Every `Permission.x` named anywhere in lib/.
  Set<String> asked() {
    final found = <String>{};
    final pattern = RegExp(r'\bPermission\.([a-zA-Z]+)\b');
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        found.add(match.group(1)!);
      }
    }
    return found..removeWhere((name) => !needs.containsKey(name));
  }

  test('every permission the app asks for is declared', () {
    for (final name in asked()) {
      for (final permission in needs[name]!) {
        expect(
          manifest,
          contains('android:name="$permission"'),
          reason:
              'Permission.$name is requested in Dart but $permission is not '
              'declared in AndroidManifest.xml, so Android answers '
              'permanentlyDenied without ever showing the prompt',
        );
      }
    }
  });

  test('the ones a known permission maps to are all in `needs`', () {
    // A guard on the guard: a permission added to the app but not to the map
    // above would otherwise pass this file by in silence.
    final pattern = RegExp(r'\bPermission\.([a-zA-Z]+)\b');
    const notPermissions = {'values', 'byValue', 'request', 'status'};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        final name = match.group(1)!;
        if (notPermissions.contains(name)) continue;
        expect(
          needs.containsKey(name),
          isTrue,
          reason:
              'Permission.$name is used in ${file.path} and this test does '
              'not know which manifest entry it needs',
        );
      }
    }
  });

  group("reading the phone's own pictures", () {
    test('the picker needs nothing declared, and nothing is', () {
      // `android_file_picker` opens ACTION_GET_CONTENT for images, video
      // and audio alike. The system picker hands one file back with a
      // grant attached, so the app never holds library access — and a
      // permission declared for it would be a line on the Play listing
      // that nothing reads. READ_MEDIA_IMAGES and READ_EXTERNAL_STORAGE
      // were declared for `file_picker` 8's ACTION_PICK, which did read
      // MediaStore directly, and went with it.
      expect(manifest, isNot(contains('android.permission.READ_MEDIA_IMAGES')));
      expect(
        manifest,
        isNot(contains('android.permission.READ_EXTERNAL_STORAGE')),
      );
    });

    test('and the gallery scan still has the two it does need', () {
      // `VideoScannerService` reads the library itself through
      // `photo_manager`, which is a different thing from picking one file.
      // READ_MEDIA_VISUAL_USER_SELECTED is Android 14's "Select videos":
      // without it the plugin cannot report a partial grant, and a reader
      // who allowed some videos is told they allowed none.
      expect(manifest, contains('android.permission.READ_MEDIA_VIDEO'));
      expect(
        manifest,
        contains('android.permission.READ_MEDIA_VISUAL_USER_SELECTED'),
      );
    });
  });

  test('nothing is declared that the app never asks for', () {
    // Each one is a line on the Play Store listing and a question at
    // install time.
    final declared = RegExp(
      r'<uses-permission android:name="([^"]+)"',
    ).allMatches(manifest).map((m) => m.group(1)!).toSet();
    final wanted = {
      for (final name in asked()) ...needs[name]!,
      // Not asked for through permission_handler: the broadcast and the
      // player need these and the system grants them at install.
      'android.permission.INTERNET',
      'android.permission.WAKE_LOCK',
      'android.permission.FOREGROUND_SERVICE',
      'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
      'android.permission.ACCESS_NETWORK_STATE',
      'android.permission.MODIFY_AUDIO_SETTINGS',
      // The gallery scan and the video pick read what the reader hands over.
      'android.permission.READ_MEDIA_VIDEO',
      'android.permission.READ_MEDIA_VISUAL_USER_SELECTED',
    };
    for (final permission in declared) {
      expect(
        wanted.contains(permission),
        isTrue,
        reason: '$permission is declared but nothing in lib/ asks for it',
      );
    }
  });
}
