import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/models/discovery_models/vertical_feed_item.dart';
import 'package:test_app/shared/services/app_session_service.dart';
import 'package:test_app/shared/services/playback_info_cache.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/shared/services/vertical_feed_preloader.dart';

/// The vertical-feed preloader used to warm itself up on every launch, on
/// every `MainShell` mount and again on every sign-in and sign-out — fetching
/// the feed and opening three native players for a screen the new design has
/// no route to. Nothing read them, so they were three decoders and four
/// requests thrown away per launch.
///
/// The warm-up is opt-in now. This holds that line: the only thing that may
/// start one is a caller that actually wants the players.
class _CountingRepo implements DiscoveryRepo {
  int feedCalls = 0;

  @override
  Future<VerticalFeedResponse> fetchVerticalFeed({
    String? cursor,
    int limit = 15,
    String mode = 'mixed',
    List<String> excludeMediaIds = const [],
    String? anchorMediaId,
    String? anchorCreatorId,
    List<String> prioritizeMediaIds = const [],
    bool includeServerContinueWatching = false,
  }) async {
    feedCalls++;
    return VerticalFeedResponse(items: const [], nextCursor: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoSession extends TokenStorageService {
  @override
  Future<String?> get accessToken async => null;

  @override
  Future<String?> get refreshToken async => null;
}

VerticalFeedPreloader _preloader(_CountingRepo repo) => VerticalFeedPreloader(
  repo: repo,
  cache: PlaybackInfoCache(),
  tokenStorage: _NoSession(),
  session: AppSessionService(),
);

void main() {
  test('a reset does not quietly start another warm-up', () async {
    final repo = _CountingRepo();
    final preloader = _preloader(repo);

    preloader.reset();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(repo.feedCalls, 0);
    expect(preloader.isWarmingUp, isFalse);
    expect(preloader.hasData, isFalse);
  });

  test('a caller that asks for a warm-up still gets one', () async {
    final repo = _CountingRepo();
    final preloader = _preloader(repo);

    await preloader.warmUp();

    expect(repo.feedCalls, 1);
  });

  test('a reset clears the feed it was holding', () async {
    final repo = _CountingRepo();
    final preloader = _preloader(repo);

    await preloader.warmUp();
    preloader.reset();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Still one: the reset emptied it rather than refilling it.
    expect(repo.feedCalls, 1);
    expect(preloader.items, isEmpty);
    expect(preloader.nextCursor, isNull);
  });
}
