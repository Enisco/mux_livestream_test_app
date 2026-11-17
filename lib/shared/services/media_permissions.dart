import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:test_app/core/logger.dart';

/// Asking for the camera and the microphone, in one place.
enum MediaAccess {
  granted,

  /// Refused, but the system will ask again. Worth another go.
  denied,

  /// The system will not ask again: denied once already, or restricted by
  /// a device policy or parental controls. Only Settings can change it.
  blocked;

  bool get isGranted => this == MediaAccess.granted;

  /// Whether a button into Settings is the only thing that can help.
  bool get needsSettings => this == MediaAccess.blocked;
}

/// How a permission is asked for. Supplied by a test; otherwise the plugin.
typedef PermissionAsk = Future<PermissionStatus> Function(Permission);

abstract final class MediaPermissions {
  /// Ask for both, and say which of the three answers came back.
  static Future<MediaAccess> cameraAndMicrophone({PermissionAsk? ask}) async {
    final request = ask ?? (permission) => permission.request();
    final camera = await request(Permission.camera);
    final microphone = await request(Permission.microphone);
    return read(camera, microphone);
  }

  /// The mapping on its own, so it can be tested without a platform.
  static MediaAccess read(PermissionStatus camera, PermissionStatus mic) {
    if (camera.isGranted && mic.isGranted) return MediaAccess.granted;
    // Either one being out of reach is enough: a broadcast needs both, and
    // sending the creator round the "try again" loop for the half that
    // cannot answer would be the original bug.
    if (_blocked(camera) || _blocked(mic)) return MediaAccess.blocked;
    return MediaAccess.denied;
  }

  static bool _blocked(PermissionStatus status) =>
      status.isPermanentlyDenied || status.isRestricted;
}

/// Posting notifications, which Android 13 made a runtime question.
///
/// Nothing is asked at launch: a prompt before the reader has asked for a
/// notification is a prompt they have no reason to accept, and Android only
/// offers it twice. It is asked where the intent is plain — switching
/// reminders on — and nowhere else.
abstract final class NotificationPermission {
  /// Whether this platform asks at all. Android 13 made it a runtime
  /// question; iOS posts the app's own media notification without one, and
  /// the Podfile macro it would need is deliberately not compiled in.
  static bool get isAsked =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// True when notifications may now be posted: granted here, granted
  /// already, or a platform that does not ask.
  static Future<bool> ensure({PermissionAsk? ask}) async {
    if (!isAsked) return true;
    final request = ask ?? (permission) => permission.request();
    try {
      return reads(await request(Permission.notification));
    } catch (e) {
      // The preference itself is the thing being saved; a permission that
      // could not be asked for must not take the save down with it.
      logger.w('Could not ask about notifications', error: e);
      return true;
    }
  }

  /// The mapping on its own, so it can be tested without a platform.
  static bool reads(PermissionStatus status) =>
      status.isGranted || status.isLimited;
}

/// What the app may read of the phone's own pictures and videos.
enum LibraryAccess {
  /// The whole library, or nothing to ask for on this platform.
  granted,

  /// Android 14's "Select photos", and iOS's limited library: only what the
  /// reader chose is visible — which is all a picker needs.
  limited,

  /// Refused, and the system will ask again. Worth another go.
  denied,

  /// The system will not ask again. Only Settings can change it.
  blocked;

  /// Whether opening the picker can work at all.
  bool get allowsPicking =>
      this == LibraryAccess.granted || this == LibraryAccess.limited;

  bool get needsSettings => this == LibraryAccess.blocked;
}

/// Which part of the library a pick reads.
enum LibraryMedia { images, videos }

/// Reading the phone's own pictures, on the one platform that asks.
///
/// `file_picker` opens `ACTION_PICK` against MediaStore for images, which is
/// a direct read of the library and needs the media permission of the day.
/// Video and audio go through Android's storage-access framework, and every
/// kind goes through `PHPicker` on iOS: those hand one file over without the
/// app ever holding library access, so asking there is a prompt for nothing.
abstract final class LibraryPermissions {
  /// Overridable so a test can reach both branches without a device.
  @visibleForTesting
  static Future<int> Function()? androidSdkOverride;

  /// Whether this kind of pick, on this platform, reads the library itself.
  static bool isAsked(LibraryMedia media) =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      media == LibraryMedia.images;

  /// Asks if asking is needed, and says what the answer leaves possible.
  static Future<LibraryAccess> ensure(
    LibraryMedia media, {
    PermissionAsk? ask,
  }) async {
    if (!isAsked(media)) return LibraryAccess.granted;
    final request = ask ?? (permission) => permission.request();
    try {
      return read(await request(await _permission()));
    } catch (e) {
      // A permission that cannot be asked for must not stop the picker: the
      // pick itself is still guarded, and on a device where this fails it is
      // likelier to work than to throw.
      logger.w('Could not ask for library access', error: e);
      return LibraryAccess.granted;
    }
  }

  /// The mapping on its own, so it can be tested without a platform.
  static LibraryAccess read(PermissionStatus status) {
    if (status.isGranted) return LibraryAccess.granted;
    if (status.isLimited) return LibraryAccess.limited;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return LibraryAccess.blocked;
    }
    return LibraryAccess.denied;
  }

  /// `READ_MEDIA_IMAGES` from Android 13; `READ_EXTERNAL_STORAGE` before it.
  /// Asking for the wrong one answers `denied` for good on every device.
  static Future<Permission> _permission() async =>
      await _androidSdk() >= 33 ? Permission.photos : Permission.storage;

  static Future<int> _androidSdk() async {
    if (androidSdkOverride case final override?) return override();
    return (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  }
}
