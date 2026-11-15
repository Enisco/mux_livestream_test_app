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
  };

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

  test('the app asks for the camera and the microphone, and no more', () {
    // If this changes, the two below cover the new one automatically — but
    // only if it is in `needs`, so a permission added without its build
    // settings stops here rather than shipping silently broken.
    expect(asked(), {'camera', 'microphone'});
  });

  test('every permission it asks for is compiled into the iOS binary', () {
    for (final name in asked()) {
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
    for (final name in asked()) {
      final key = needs[name]!.$2;
      if (key.isEmpty) continue;
      expect(plist, contains('<key>$key</key>'), reason: 'Permission.$name');
    }
  });

  test('nothing is compiled in that the app never asks for', () {
    // Each one carries its framework and its API usage into the binary,
    // and onto the App Store privacy report.
    final wanted = {for (final name in asked()) needs[name]!.$1};
    for (final (macro, _) in needs.values) {
      if (wanted.contains(macro)) continue;
      expect(podfile, isNot(contains('$macro=1')), reason: macro);
    }
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
