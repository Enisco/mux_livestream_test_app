import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

enum ScanPermission { granted, denied, permanentlyDenied }

class VideoScannerService {
  static const _videoExts = {
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.webm',
    '.flv',
    '.wmv',
    '.m4v',
    '.3gp',
    '.ts',
    '.m2ts',
    '.vob',
    '.mpg',
    '.mpeg',
  };

  bool get _usesPhotoManager => Platform.isAndroid || Platform.isIOS;

  static const _permOption = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.video,
      mediaLocation: false,
    ),
  );

  Future<ScanPermission> checkPermission() async {
    if (!_usesPhotoManager) return ScanPermission.granted;
    final state = await PhotoManager.getPermissionState(
      requestOption: _permOption,
    );
    if (state.isAuth) return ScanPermission.granted;
    if (Platform.isAndroid) {
      // Android returns denied whether the user was never asked or denied once.
      return ScanPermission.denied;
    }
    if (state == PermissionState.notDetermined) return ScanPermission.denied;
    return ScanPermission.permanentlyDenied;
  }

  Future<ScanPermission> requestPermission() async {
    if (!_usesPhotoManager) return ScanPermission.granted;
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: _permOption,
    );
    if (state.isAuth) return ScanPermission.granted;
    return ScanPermission.permanentlyDenied;
  }

  Future<void> openSettings() async {
    if (_usesPhotoManager) await PhotoManager.openSetting();
  }

  Future<List<String>> scan() async {
    return _usesPhotoManager ? _scanViaPhotoManager() : _scanDirectories();
  }

  Future<List<String>> _scanViaPhotoManager() async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.video);
    final paths = <String>{};
    for (final album in albums) {
      final count = await album.assetCountAsync;
      if (count == 0) continue;
      final assets = await album.getAssetListRange(start: 0, end: count);
      for (final asset in assets) {
        final file = await asset.file;
        if (file != null) paths.add(file.path);
      }
    }
    return paths.toList()..sort();
  }

  Future<List<String>> _scanDirectories() async {
    final dirs = _searchDirectories();
    final paths = <String>{};
    for (final dir in dirs) {
      if (!dir.existsSync()) continue;
      try {
        await for (final entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File && _isVideo(entity.path)) {
            paths.add(entity.path);
          }
        }
      } catch (_) {}
    }
    return paths.toList()..sort();
  }

  List<Directory> _searchDirectories() {
    final s = Platform.pathSeparator;
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return [Directory('$home${s}Movies'), Directory('$home${s}Downloads')];
    }
    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Public';
      return [
        Directory('$home${s}Videos'),
        Directory('$home${s}Downloads'),
        Directory('$home${s}Desktop'),
        Directory('$home${s}Documents'),
      ];
    }
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '/home';
      return [
        Directory('$home${s}Videos'),
        Directory('$home${s}Downloads'),
        Directory('$home${s}Desktop'),
        Directory('$home${s}Documents'),
      ];
    }
    return [];
  }

  bool _isVideo(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    return _videoExts.contains(path.substring(dot).toLowerCase());
  }
}
