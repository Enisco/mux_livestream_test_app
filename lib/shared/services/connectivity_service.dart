import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'package:test_app/core/logger.dart';

class ConnectivityService {
  static const _unknown = 'unknown';

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  String _networkType = _unknown;

  String get networkType => _networkType;

  bool get isOffline => _networkType == 'none';

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  Future<void> init() async {
    try {
      _apply(await _connectivity.checkConnectivity());
    } catch (e) {
      logger.w('Connectivity: initial check failed → $e');
    }
    _sub = _connectivity.onConnectivityChanged.listen(
      _apply,
      onError: (Object e) => logger.w('Connectivity: stream error → $e'),
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _apply(List<ConnectivityResult> results) {
    final resolved = _resolve(results);
    if (resolved == _networkType) return;
    _networkType = resolved;
    isOnline.value = resolved != 'none';
    logger.d('Connectivity: networkType → $resolved');
  }

  String _resolve(List<ConnectivityResult> results) {
    if (results.isEmpty) return _unknown;
    if (results.every((r) => r == ConnectivityResult.none)) return 'none';

    for (final result in results) {
      switch (result) {
        case ConnectivityResult.wifi:
          return 'wifi';
        case ConnectivityResult.mobile:
          return 'cellular';
        case ConnectivityResult.ethernet:
          return 'ethernet';
        default:
          continue;
      }
    }
    for (final result in results) {
      switch (result) {
        case ConnectivityResult.vpn:
          return 'vpn';
        case ConnectivityResult.bluetooth:
          return 'bluetooth';
        case ConnectivityResult.none:
          continue;
        default:
          return 'other';
      }
    }
    return _unknown;
  }
}
