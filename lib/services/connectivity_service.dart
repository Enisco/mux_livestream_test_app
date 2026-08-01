import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/logger.dart';

/// Tracks the active network transport so analytics beacons can report
/// `client.networkType`.
///
/// The value is cached and updated from a subscription rather than queried per
/// event: [AnalyticsService._build] is synchronous and runs on every beacon, so
/// an async platform-channel round-trip there would be both wrong and wasteful.
///
/// This is what lets the backend separate genuine abandonment from cellular
/// buffering stalls — a `pause` followed by `view_ended` on `cellular` reads
/// very differently from the same pair on `wifi`.
class ConnectivityService {
  static const _unknown = 'unknown';

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  String _networkType = _unknown;

  /// Current transport: `wifi`, `cellular`, `ethernet`, `vpn`, `bluetooth`,
  /// `other`, `none` (device offline), or `unknown` (not yet resolved).
  String get networkType => _networkType;

  /// True when the platform reports no usable transport. Callers can use this
  /// to skip doomed network work rather than waiting for a timeout.
  bool get isOffline => _networkType == 'none';

  Future<void> init() async {
    try {
      _apply(await _connectivity.checkConnectivity());
    } catch (e) {
      // Never let a connectivity probe block startup — beacons just carry
      // `unknown` until the first stream event lands.
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
    logger.d('Connectivity: networkType → $resolved');
  }

  /// The platform can report several transports at once (e.g. VPN over Wi-Fi).
  /// We report the most specific physical transport, because that is what
  /// actually explains playback quality.
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
    // No physical transport identified — fall back to whatever was reported.
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
