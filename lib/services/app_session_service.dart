import 'package:uuid/uuid.dart';

import '../utils/local_storage.dart';

/// Owns the three identifiers the media/analytics contract expects the client
/// to generate and reuse.
///
/// Previously each screen minted its own `clientSessionId` from
/// `DateTime.now().millisecondsSinceEpoch`, which meant the detail screen, the
/// vertical feed, and the preloader all looked like different sessions to the
/// backend — breaking live playback session tracking and per-session
/// de-duplication. There is now exactly one of each per app run.
class AppSessionService {
  static const _anonViewerIdKey = 'gtube_anon_viewer_id';

  late final String _analyticsSessionId;
  late final String _clientSessionId;
  late final String _anonymousViewerId;

  /// `identity.sessionId` on every beacon. New per app launch — this is the
  /// unit the backend de-duplicates paid impressions within.
  String get analyticsSessionId => _analyticsSessionId;

  /// Sent on detail/playback-info requests. Must match `[A-Za-z0-9_-]{8,128}`;
  /// a v4 UUID satisfies that and is stable for the whole app run, which is what
  /// anonymous livestream playback sessions need.
  String get clientSessionId => _clientSessionId;

  /// Durable anonymous viewer identity. Web gets this from the `gt_anon_viewer`
  /// cookie; mobile has no cookie jar, so we persist our own and send it on
  /// anonymous beacons.
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
