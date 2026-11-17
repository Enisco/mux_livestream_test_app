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

  group('reading the phone\'s own pictures', () {
    test('both sides of the Android 13 split are declared', () {
      // `LibraryPermissions` asks for photos at 33 and up and storage below
      // it. One without the other leaves half the fleet unable to pick.
      expect(manifest, contains('android.permission.READ_MEDIA_IMAGES'));
      expect(manifest, contains('android.permission.READ_EXTERNAL_STORAGE'));
    });

    test('and the old one stops at the version that still needs it', () {
      // Left open, Play Console rejects the upload and Android 13+ ignores
      // it anyway.
      expect(
        manifest,
        matches(
          RegExp(
            r'android\.permission\.READ_EXTERNAL_STORAGE"\s+'
            r'android:maxSdkVersion="32"',
          ),
        ),
      );
    });

    test('a partial grant is declared, so it can be told from a refusal', () {
      // Android 14's "Select photos". Without
      // READ_MEDIA_VISUAL_USER_SELECTED the plugin cannot report `limited`,
      // and a reader who allowed some photos is told they allowed none.
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
