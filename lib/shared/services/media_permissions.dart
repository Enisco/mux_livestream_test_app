import 'package:permission_handler/permission_handler.dart';

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
