import 'dart:io';
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

class DeviceInfoService {
  static const _deviceIdKey = 'gtube_device_id';

  late final String _deviceId;
  late final String _deviceName;
  late final String _appVersion;
  late final String _platform;

  Future<void> init() async {
    final plugin = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();
    _appVersion = packageInfo.version;

    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      _deviceName = info.utsname.machine;
      _platform = 'ios';
    } else if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      _deviceName = '${info.brand} ${info.model}';
      _platform = 'android';
    } else if (Platform.isMacOS) {
      final info = await plugin.macOsInfo;
      _deviceName = info.computerName;
      _platform = 'macos';
    } else if (Platform.isWindows) {
      final info = await plugin.windowsInfo;
      _deviceName = info.computerName;
      _platform = 'windows';
    } else {
      _deviceName = 'unknown';
      _platform = Platform.operatingSystem;
    }

    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    String storedId = await storage.read(key: _deviceIdKey) ?? '';
    if (storedId.isEmpty) {
      storedId = const Uuid().v4();
      await storage.write(key: _deviceIdKey, value: storedId);
    }
    _deviceId = storedId;
  }

  String get platform => _platform;
  String get appVersion => _appVersion;

  String get deviceType {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return 'desktop';
    }
    final view = ui.PlatformDispatcher.instance.implicitView;
    if (view == null) return 'phone';
    final logical = view.physicalSize / view.devicePixelRatio;
    return logical.shortestSide >= 600 ? 'tablet' : 'phone';
  }

  Map<String, String> get headers => {
    'x-device-id': _deviceId,
    'x-device-name': _deviceName,
    'x-app-version': _appVersion,
    'x-client-platform': _platform,
    'x-requested-with': 'XMLHttpRequest',
  };
}
