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

/// *Picking* a picture or a video asks for nothing, and that is deliberate.
///
/// There was a `LibraryPermissions` here that asked for `READ_MEDIA_IMAGES`
/// before an image pick on Android. It was needed once: `file_picker` 8
/// opened `ACTION_PICK` against MediaStore, which is a direct read of the
/// library. Both pickers are now out-of-process — `PHPickerViewController`
/// on iOS, `ACTION_GET_CONTENT` on Android — and hand one file over with a
/// grant attached, without the app ever holding library access.
///
/// So the ask was not merely redundant: refused, it returned `noAccess` and
/// never opened a picker that would have worked. A permission the picker
/// does not use is a way for picking to fail and no way for it to succeed.
///
/// `VideoScannerService` does read the library, through `photo_manager`'s
/// own native prompt rather than `permission_handler` — which is why
/// `PERMISSION_PHOTOS` stays out of the Podfile. It is only reached from
/// `home_screen.dart`, which nothing routes, so it does not run today.
///
/// The camera and the microphone are different again, and still asked for
/// in `live_broadcast_screen` — a capture session reads the hardware
/// directly, and iOS and Android both require the prompt.
