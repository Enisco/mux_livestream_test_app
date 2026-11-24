import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The iOS build settings a permission needs before it can be asked for.
void main() {
  /// Permission.x in Dart -> (its Podfile macro, its Info.plist key).
  const needs = <String, (String, String)>{
    'camera': ('PERMISSION_CAMERA', 'NSCameraUsageDescription'),
    'microphone': ('PERMISSION_MICROPHONE', 'NSMicrophoneUsageDescription'),
    'photos': ('PERMISSION_PHOTOS', 'NSPhotoLibraryUsageDescription'),
    'location': ('PERMISSION_LOCATION', 'NSLocationWhenInUseUsageDescription'),
    'contacts': ('PERMISSION_CONTACTS', 'NSContactsUsageDescription'),
    'notification': ('PERMISSION_NOTIFICATIONS', ''),
    'speech': (
      'PERMISSION_SPEECH_RECOGNIZER',
      'NSSpeechRecognitionUsageDescription',
    ),
    'calendar': ('PERMISSION_EVENTS', 'NSCalendarsUsageDescription'),
    // `Permission.storage` is `READ_EXTERNAL_STORAGE` on Android 12 and
    // below; on iOS the plugin folds it into the photo library.
    'storage': ('PERMISSION_PHOTOS', 'NSPhotoLibraryUsageDescription'),
  };

  /// Named in Dart, asked only on Android. The Podfile macro would compile a
  /// framework and an App Store privacy entry into the iOS binary for a
  /// prompt that is never shown — iOS picks through `PHPicker`, which hands
  /// one file over without the app holding library access, and posts
  /// notifications without asking. The guard is checked below, not trusted.
  const androidOnly = {'photos', 'storage', 'notification'};

  late final String podfile = File('ios/Podfile').readAsStringSync();
  late final String plist = File('ios/Runner/Info.plist').readAsStringSync();

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
    // `Permission.values` and friends are not permissions.
    return found..removeWhere((name) => !needs.containsKey(name));
  }

  /// The ones iOS itself has to be built for.
  Set<String> askedOnIos() => asked().difference(androidOnly);

  test('the app asks for the camera and the microphone, and no more', () {
    // If this changes, the three below cover the new one automatically — but
    // only if it is in `needs`, so a permission added without its build
    // settings stops here rather than shipping silently broken.
    expect(askedOnIos(), {'camera', 'microphone'});
  });

  test('every permission it asks for is compiled into the iOS binary', () {
    for (final name in askedOnIos()) {
      expect(
        podfile,
        contains('${needs[name]!.$1}=1'),
        reason:
            'Permission.$name is requested in Dart but ${needs[name]!.$1} is '
            'not set in ios/Podfile, so iOS answers permanentlyDenied '
            'without ever showing the prompt',
      );
    }
  });

  test('and has the usage string iOS refuses a build without', () {
    for (final name in askedOnIos()) {
      final key = needs[name]!.$2;
      if (key.isEmpty) continue;
      expect(plist, contains('<key>$key</key>'), reason: 'Permission.$name');
    }
  });

  test('nothing is compiled in that the app never asks for', () {
    // Each one carries its framework and its API usage into the binary,
    // and onto the App Store privacy report.
    final wanted = {for (final name in askedOnIos()) needs[name]!.$1};
    for (final (macro, _) in needs.values) {
      if (wanted.contains(macro)) continue;
      expect(podfile, isNot(contains('$macro=1')), reason: macro);
    }
  });

  test('and an Android-only one is never asked for on iOS', () {
    // Without its Podfile macro the plugin answers permanentlyDenied without
    // a prompt, so an ask that reached iOS would be a dead end rather than a
    // dialog. Every file that names one has to rule iOS out first.
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final name in androidOnly) {
        if (!source.contains('Permission.$name')) continue;
        expect(
          source.contains('Platform.isAndroid') ||
              source.contains('TargetPlatform.android'),
          isTrue,
          reason:
              'Permission.$name is asked for in ${file.path} without an '
              'Android guard',
        );
      }
    }
  });

  group('the photo library, which nothing reachable reads', () {
    test('its usage string is there, because the plugin is still linked', () {
      // `photo_manager` ships PhotoKit regardless of whether anything
      // calls it, and iOS kills the app on the spot if a prompt it can
      // reach has no string to show.
      expect(plist, contains('<key>NSPhotoLibraryUsageDescription</key>'));
    });

    test('but no permission_handler macro, because nothing uses one', () {
      // `photo_manager` carries its own iOS implementation of the prompt.
      // Compiling `PERMISSION_PHOTOS` in as well would add a second,
      // unused strategy and its framework to the binary.
      expect(podfile, isNot(contains('PERMISSION_PHOTOS=1')));
    });

    test('and the one caller of the library scan is still dormant', () {
      // `VideoScannerService` lists the whole video library, which is what
      // the usage string describes. It is reached only from
      // `home_screen.dart`, which nothing routes. If that changes, the
      // string is still right — but the App Store privacy answers are not,
      // so this is worth knowing about.
      final routed = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .any(
            (f) =>
                !f.path.endsWith('home_screen.dart') &&
                f.readAsStringSync().contains('HomeScreen'),
          );
      expect(
        routed,
        isFalse,
        reason:
            'home_screen.dart is now reachable, so the library scan can '
            'run — revisit the App Store privacy answers',
      );
    });
  });

  group('the deployment target Apple will insist on', () {
    /// April 2027: below 15.0 is refused by App Store Connect.
    const floor = 15.0;

    test('the Xcode project is at or above it, in every configuration', () {
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final targets = RegExp(
        r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);',
      ).allMatches(project).map((m) => double.parse(m.group(1)!)).toList();

      expect(targets, isNotEmpty);
      for (final target in targets) {
        expect(target, greaterThanOrEqualTo(floor));
      }
    });

    test('and so is the Podfile, which the pods inherit', () {
      final platform = RegExp(r"platform :ios, '([\d.]+)'").firstMatch(podfile);
      expect(platform, isNotNull);
      expect(double.parse(platform!.group(1)!), greaterThanOrEqualTo(floor));
    });
  });
}
