import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:test_app/shared/services/media_permissions.dart';

/// Telling "ask me again" apart from "the system will never ask again".
void main() {
  group('what came back', () {
    test('both yes is a yes', () {
      expect(
        MediaPermissions.read(
          PermissionStatus.granted,
          PermissionStatus.granted,
        ),
        MediaAccess.granted,
      );
    });

    test('a plain refusal can be asked again', () {
      expect(
        MediaPermissions.read(
          PermissionStatus.denied,
          PermissionStatus.granted,
        ),
        MediaAccess.denied,
      );
    });

    test('a standing refusal needs Settings', () {
      expect(
        MediaPermissions.read(
          PermissionStatus.permanentlyDenied,
          PermissionStatus.granted,
        ),
        MediaAccess.blocked,
      );
    });

    test('and so does the microphone on its own', () {
      // A broadcast needs both, so either one being out of reach is the
      // whole answer.
      expect(
        MediaPermissions.read(
          PermissionStatus.granted,
          PermissionStatus.permanentlyDenied,
        ),
        MediaAccess.blocked,
      );
    });

    test('a restricted device does too', () {
      // Parental controls or an MDM policy. Nothing the prompt can fix.
      expect(
        MediaPermissions.read(
          PermissionStatus.restricted,
          PermissionStatus.granted,
        ),
        MediaAccess.blocked,
      );
    });

    test('the standing refusal outranks the askable one', () {
      expect(
        MediaPermissions.read(
          PermissionStatus.denied,
          PermissionStatus.permanentlyDenied,
        ),
        MediaAccess.blocked,
      );
    });

    test('only granted is granted', () {
      for (final status in PermissionStatus.values) {
        final access = MediaPermissions.read(status, PermissionStatus.granted);
        expect(
          access.isGranted,
          status == PermissionStatus.granted,
          reason: '$status',
        );
        expect(() => access.needsSettings, returnsNormally, reason: '$status');
      }
    });
  });

  group('asking', () {
    test('asks for both, even when the first says no', () async {
      // A creator who blocked the camera and was never asked for the
      // microphone should meet one Settings screen with both switches on
      // it, not find the second refusal after fixing the first.
      final asked = <Permission>[];
      final access = await MediaPermissions.cameraAndMicrophone(
        ask: (permission) async {
          asked.add(permission);
          return permission == Permission.camera
              ? PermissionStatus.permanentlyDenied
              : PermissionStatus.denied;
        },
      );

      expect(asked, [Permission.camera, Permission.microphone]);
      expect(access, MediaAccess.blocked);
    });

    test('and reports a clean yes', () async {
      final access = await MediaPermissions.cameraAndMicrophone(
        ask: (_) async => PermissionStatus.granted,
      );

      expect(access.isGranted, isTrue);
      expect(access.needsSettings, isFalse);
    });
  });

  /// The platform the pickers and the notification ask on.
  void onAndroid() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
  }

  // The group that was here exercised `LibraryPermissions`, which asked
  // for the photo library before an image pick on Android. Nothing asks
  // now: both pickers are out-of-process and hand one file over with a
  // grant, so there is no permission left to read an answer from. See the
  // note at the foot of media_permissions.dart.

  group('posting a notification', () {
    test('a yes, or a partial one, is a yes', () {
      expect(NotificationPermission.reads(PermissionStatus.granted), isTrue);
      expect(NotificationPermission.reads(PermissionStatus.limited), isTrue);
    });

    test('and a refusal is reported rather than swallowed', () {
      // The preference would otherwise be saved on a server and the phone
      // would post nothing, which reads as a feature that does not work.
      expect(NotificationPermission.reads(PermissionStatus.denied), isFalse);
      expect(
        NotificationPermission.reads(PermissionStatus.permanentlyDenied),
        isFalse,
      );
    });

    test('only Android is asked', () {
      onAndroid();
      expect(NotificationPermission.isAsked, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(NotificationPermission.isAsked, isFalse);
    });

    test('and nothing is asked where nothing is asked', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final asked = <Permission>[];
      final allowed = await NotificationPermission.ensure(
        ask: (permission) async {
          asked.add(permission);
          return PermissionStatus.permanentlyDenied;
        },
      );

      expect(asked, isEmpty);
      expect(allowed, isTrue);
    });

    test('an ask that cannot be made does not block the preference', () async {
      onAndroid();
      expect(
        await NotificationPermission.ensure(
          ask: (_) async => throw Exception('no platform here'),
        ),
        isTrue,
      );
    });
  });
}
