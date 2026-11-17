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

  group('reading the phone\'s own pictures', () {
    test('a full yes lets the picker open', () {
      final access = LibraryPermissions.read(PermissionStatus.granted);
      expect(access, LibraryAccess.granted);
      expect(access.allowsPicking, isTrue);
      expect(access.needsSettings, isFalse);
    });

    test('and so does "Select photos", which is not a refusal', () {
      // Android 14 and iOS both offer partial access. The picker only ever
      // needs the one file the reader chooses, so this is a yes — treating
      // it as a no told a reader they had said no when they had said yes.
      final access = LibraryPermissions.read(PermissionStatus.limited);
      expect(access, LibraryAccess.limited);
      expect(access.allowsPicking, isTrue);
      expect(access.needsSettings, isFalse);
    });

    test('a plain refusal can be asked again', () {
      final access = LibraryPermissions.read(PermissionStatus.denied);
      expect(access, LibraryAccess.denied);
      expect(access.allowsPicking, isFalse);
      expect(
        access.needsSettings,
        isFalse,
        reason: 'the system will ask again; Settings is the longer road',
      );
    });

    test('a standing refusal needs Settings', () {
      final access = LibraryPermissions.read(
        PermissionStatus.permanentlyDenied,
      );
      expect(access, LibraryAccess.blocked);
      expect(access.needsSettings, isTrue);
    });

    test('and so does a device under policy', () {
      expect(
        LibraryPermissions.read(PermissionStatus.restricted),
        LibraryAccess.blocked,
      );
    });

    test('every status has an answer', () {
      for (final status in PermissionStatus.values) {
        final access = LibraryPermissions.read(status);
        expect(
          access.allowsPicking,
          status == PermissionStatus.granted ||
              status == PermissionStatus.limited,
          reason: '$status',
        );
      }
    });

    test('nothing is asked where the pick needs no permission', () async {
      // Video and audio go through the storage-access framework, and every
      // kind goes through PHPicker on iOS: those hand one file over without
      // the app holding library access. A prompt there is a prompt for
      // nothing, and a refused one would block a pick that would have worked.
      final asked = <Permission>[];
      final access = await LibraryPermissions.ensure(
        LibraryMedia.videos,
        ask: (permission) async {
          asked.add(permission);
          return PermissionStatus.denied;
        },
      );

      expect(asked, isEmpty);
      expect(access, LibraryAccess.granted);
    });

    test('a picture on Android is the one pick that does ask', () async {
      // `file_picker` opens ACTION_PICK against MediaStore for images, which
      // is a direct read of the library. Nothing else in the app is.
      onAndroid();
      LibraryPermissions.androidSdkOverride = () async => 34;
      addTearDown(() => LibraryPermissions.androidSdkOverride = null);

      final asked = <Permission>[];
      final access = await LibraryPermissions.ensure(
        LibraryMedia.images,
        ask: (permission) async {
          asked.add(permission);
          return PermissionStatus.granted;
        },
      );

      expect(asked, [Permission.photos]);
      expect(access, LibraryAccess.granted);
    });

    test('and before Android 13 it is the storage permission', () async {
      // READ_MEDIA_IMAGES does not exist below 33, and asking for it there
      // answers denied for good on every device.
      onAndroid();
      LibraryPermissions.androidSdkOverride = () async => 32;
      addTearDown(() => LibraryPermissions.androidSdkOverride = null);

      final asked = <Permission>[];
      await LibraryPermissions.ensure(
        LibraryMedia.images,
        ask: (permission) async {
          asked.add(permission);
          return PermissionStatus.granted;
        },
      );

      expect(asked, [Permission.storage]);
    });

    test('an ask that cannot be made does not stop the picker', () async {
      // A platform channel that throws is not a refusal. The pick itself is
      // guarded either way, so the honest answer is to let it try.
      onAndroid();
      LibraryPermissions.androidSdkOverride = () async => 34;
      addTearDown(() => LibraryPermissions.androidSdkOverride = null);

      final access = await LibraryPermissions.ensure(
        LibraryMedia.images,
        ask: (_) async => throw Exception('no platform here'),
      );

      expect(access.allowsPicking, isTrue);
    });
  });

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
