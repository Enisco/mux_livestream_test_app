import 'package:uuid/uuid.dart';

import 'package:test_app/utils/helpers/local_storage.dart';

/// Owns the three identifiers the analytics contract expects the client to
/// generate and reuse. Exactly one of each per app run — every surface must
/// share them or the backend sees separate sessions.
class AppSessionService {
  static const _anonViewerIdKey = 'gtube_anon_viewer_id';

  late final String _analyticsSessionId;
  late final String _clientSessionId;
  late final String _anonymousViewerId;

  /// `identity.sessionId`. New per launch — the unit paid impressions
  /// de-duplicate within.
  String get analyticsSessionId => _analyticsSessionId;

  /// Sent on detail/playback-info requests. Must match `[A-Za-z0-9_-]{8,128}`.
  String get clientSessionId => _clientSessionId;

  /// Durable anonymous identity — mobile's stand-in for web's `gt_anon_viewer`
  /// cookie.
  String get anonymousViewerId => _anonymousViewerId;

  Future<void> init() async {
    const uuid = Uuid();
    _analyticsSessionId = uuid.v4();
    _clientSessionId = uuid.v4();

    final stored = LocalStorage.getString(_anonViewerIdKey);
    if (stored != null && stored.isNotEmpty) {
      _anonymousViewerId = stored;
    } else {
      _anonymousViewerId = uuid.v4();
      await LocalStorage.setString(_anonViewerIdKey, _anonymousViewerId);
    }
  }
}
