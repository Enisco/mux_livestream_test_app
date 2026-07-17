import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/logger.dart';
import '../features/discovery/models/vertical_feed_item.dart';
import '../features/discovery/repo/discovery_repo.dart';
import 'playback_info_cache.dart';
import 'token_storage_service.dart';

const _kInitialPreloadCount = 3;

/// A player + controller pair that has already had [Player.open] called on it.
/// The caller that claims it via [VerticalFeedPreloader.takePlayer] owns it
/// and is responsible for disposal.
class PreloadedPlayer {
  final Player player;
  final VideoController controller;
  PreloadedPlayer._(this.player, this.controller);
}

/// Manages a rolling window of silently pre-initialised [media_kit] players so
/// vertical feed videos are ready the instant the user swipes to them.
///
/// Call [warmUp] as early as possible (e.g. in [main] after confirming the
/// user is authenticated). As the user scrolls, the feed screen calls [advance]
/// on every page change to keep 2 players ready ahead of the current position.
///
/// Ownership model: [takePlayer] / [awaitPlayer] transfer a player out of this
/// pool to the calling widget. Once transferred the preloader no longer manages
/// that player — the widget is responsible for disposal.
class VerticalFeedPreloader {
  final DiscoveryRepo _repo;
  final PlaybackInfoCache _cache;
  final TokenStorageService _tokenStorage;

  VerticalFeedPreloader({
    required DiscoveryRepo repo,
    required PlaybackInfoCache cache,
    required TokenStorageService tokenStorage,
  })  : _repo = repo,
        _cache = cache,
        _tokenStorage = tokenStorage;

  List<VerticalFeedItem> _items = const [];
  String? _nextCursor;

  // Players ready to be claimed, keyed by mediaId.
  final Map<String, PreloadedPlayer> _players = {};
  // MediaIds currently being initialised. Prevents concurrent double-init.
  final Set<String> _initializing = {};
  // MediaIds already transferred to a widget. Prevents re-initialisation.
  final Set<String> _claimed = {};

  // One Completer per waiting widget (only the active page ever waits).
  final Map<String, Completer<PreloadedPlayer?>> _awaitingPlayer = {};
  // Completed when the current warmUp() finishes.
  Completer<void>? _warmupCompleter;

  bool _loading = false;
  bool _isAuthenticated = false;
  String? _sessionId;

  List<VerticalFeedItem> get items => List.unmodifiable(_items);
  String? get nextCursor => _nextCursor;
  bool get hasData => _items.isNotEmpty;

  /// Whether the last [warmUp] ran with an authenticated session.
  /// Used by callers to select the appropriate playback-info route.
  bool get isAuthenticated => _isAuthenticated;

  /// True while [warmUp] is fetching feed data.
  bool get isWarmingUp => _loading;

  /// Completes when the current [warmUp] finishes (or immediately if idle).
  Future<void> get whenWarmedUp {
    if (!_loading) return Future.value();
    _warmupCompleter ??= Completer<void>();
    return _warmupCompleter!.future;
  }

  /// True while [_initPlayer] is running for [mediaId].
  bool isInitializing(String mediaId) => _initializing.contains(mediaId);

  String _clientSessionId() =>
      _sessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

  /// Fetches feed items and silently initialises players for the first
  /// [_kInitialPreloadCount] videos. Idempotent — does nothing if a load is
  /// already in progress or data is already present.
  ///
  /// Checks auth state internally: unauthenticated users get the feed metadata
  /// but player pre-init uses the public `/v1/public/media/:id/playback-info`
  /// route so no 401 is ever produced.
  Future<void> warmUp() async {
    if (_loading || _items.isNotEmpty) return;
    _loading = true;
    _isAuthenticated = await _tokenStorage.hasSession;
    try {
      final result = await _repo.fetchVerticalFeed();
      _items = result.items;
      _nextCursor = result.nextCursor;
      for (var i = 0; i < _items.length && i < _kInitialPreloadCount; i++) {
        unawaited(_initPlayer(_items[i]));
      }
    } catch (e) {
      logger.w('VerticalFeedPreloader: warmUp failed → $e');
    } finally {
      _loading = false;
      _warmupCompleter?.complete();
      _warmupCompleter = null;
    }
  }

  /// Advances the rolling preload window. Call on every page-index change.
  ///
  /// Triggers player init for [currentIndex + 1] and [currentIndex + 2] and
  /// disposes unclaimed players outside that window.
  void advance(int currentIndex, List<VerticalFeedItem> items) {
    for (final delta in [1, 2]) {
      final idx = currentIndex + delta;
      if (idx >= 0 && idx < items.length) {
        unawaited(_initPlayer(items[idx]));
      }
    }
    _players.removeWhere((mediaId, preloaded) {
      final idx = items.indexWhere((item) => item.mediaId == mediaId);
      final delta = idx == -1 ? -999 : idx - currentIndex;
      if (delta < 0 || delta > 2) {
        preloaded.player.pause();
        preloaded.player.dispose();
        return true;
      }
      return false;
    });
  }

  Future<void> _initPlayer(VerticalFeedItem item) async {
    if (_players.containsKey(item.mediaId) ||
        _initializing.contains(item.mediaId) ||
        _claimed.contains(item.mediaId)) {
      return;
    }
    _initializing.add(item.mediaId);
    try {
      String? url = _cache.get(item.mediaId)?.playbackUrl;
      if (url == null) {
        final info = await _repo.fetchPlaybackInfo(
          item.mediaId,
          clientSessionId: _clientSessionId(),
          usePublicRoute: !_isAuthenticated,
        );
        if (info != null) {
          _cache.put(item.mediaId, info);
          url = info.playbackUrl;
        }
      }
      if (url == null || url.isEmpty) return;
      if (_players.containsKey(item.mediaId) || _claimed.contains(item.mediaId)) return;

      final player = Player();
      final controller = VideoController(player);
      await player.open(Media(url), play: false);
      await player.setPlaylistMode(PlaylistMode.single);
      await player.setVolume(100);

      // After the async open, re-check for races.
      if (_players.containsKey(item.mediaId) || _claimed.contains(item.mediaId)) {
        player.pause();
        player.dispose();
        return;
      }

      // If a widget is waiting for this player, transfer directly.
      final waiter = _awaitingPlayer.remove(item.mediaId);
      if (waiter != null && !waiter.isCompleted) {
        _claimed.add(item.mediaId);
        waiter.complete(PreloadedPlayer._(player, controller));
      } else {
        _players[item.mediaId] = PreloadedPlayer._(player, controller);
        logger.d('VerticalFeedPreloader: ready → ${item.mediaId}');
      }
    } catch (e) {
      logger.w('VerticalFeedPreloader: init failed for ${item.mediaId} → $e');
    } finally {
      _initializing.remove(item.mediaId);
      // Complete any waiter that wasn't handled above (error / early-exit path).
      _awaitingPlayer.remove(item.mediaId)?.complete(null);
    }
  }

  /// Immediately claims the ready player for [mediaId]. Returns null if not ready.
  PreloadedPlayer? takePlayer(String mediaId) {
    _claimed.add(mediaId);
    return _players.remove(mediaId);
  }

  /// Claims the player for [mediaId], waiting if it is still being initialised.
  /// Returns null if initialisation was never started or fails.
  /// The caller must not also call [takePlayer] for the same [mediaId].
  Future<PreloadedPlayer?> awaitPlayer(String mediaId) async {
    // May have become ready between takePlayer() and awaitPlayer() calls.
    final existing = _players.remove(mediaId);
    if (existing != null) {
      _claimed.add(mediaId);
      return existing;
    }
    if (!_initializing.contains(mediaId)) return null;

    final completer = Completer<PreloadedPlayer?>();
    _awaitingPlayer[mediaId] = completer; // one waiter per mediaId
    return completer.future;
  }

  /// Disposes all held players, clears all state, then immediately re-warms
  /// so the next visit is equally instant. Call from [VerticalFeedScreen.dispose].
  void reset() {
    for (final p in _players.values) {
      p.player.pause();
      p.player.dispose();
    }
    _players.clear();
    for (final w in _awaitingPlayer.values) {
      if (!w.isCompleted) w.complete(null);
    }
    _awaitingPlayer.clear();
    _warmupCompleter?.complete();
    _warmupCompleter = null;
    _initializing.clear();
    _claimed.clear();
    _items = const [];
    _nextCursor = null;
    _sessionId = null;
    _loading = false;
    _isAuthenticated = false;
    unawaited(warmUp());
  }
}
