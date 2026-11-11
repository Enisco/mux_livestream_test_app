import 'package:permission_handler/permission_handler.dart';

/// Asking for the camera and the microphone, in one place.
///
/// Two screens go live and both used to ask for themselves, with the same
/// two lines and the same hole in them:
///
/// ```dart
/// final camera = await Permission.camera.request();
/// final mic = await Permission.microphone.request();
/// if (!camera.isGranted || !mic.isGranted) return _fail(...);
/// ```
///
/// That collapses two different refusals into one. A creator who has not
/// been asked yet can be asked, and "Try again" is exactly right for them.
/// A creator who said no once never sees the system dialog again — iOS asks
/// precisely once — so the same button is a loop with no exit, and the only
/// way back is Settings. The screens have to be able to tell those apart,
/// which means the request has to report three outcomes rather than a bool.
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
  ///
  /// Both are asked even when the first is refused: a creator who has
  /// blocked the camera and never been asked for the microphone should see
  /// one Settings screen with both switches on it, not discover the second
  /// refusal after fixing the first.
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
