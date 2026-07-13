import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/logger.dart';
import '../features/discovery/models/vertical_feed_item.dart';
import '../features/discovery/repo/discovery_repo.dart';
import 'playback_info_cache.dart';

const _kPreloadCount = 3;

/// A player + controller pair that has already had [Player.open] called on it.
/// The caller that claims it via [VerticalFeedPreloader.takePlayer] owns it
/// and is responsible for disposal.
class PreloadedPlayer {
  final Player player;
  final VideoController controller;
  PreloadedPlayer._(this.player, this.controller);
}

/// Silently pre-fetches the first page of vertical feed data and opens
/// [media_kit] players for the first [_kPreloadCount] videos so they are
/// already buffering before the user navigates to [VerticalFeedScreen].
///
/// Register as a lazy singleton via GetIt and call [warmUp] from the home
/// screen's [initState]. The feed screen calls [reset] on dispose so the next
/// visit is equally instant.
class VerticalFeedPreloader {
  final DiscoveryRepo _repo;
  final PlaybackInfoCache _cache;

  VerticalFeedPreloader({required DiscoveryRepo repo, required PlaybackInfoCache cache})
      : _repo = repo,
        _cache = cache;

  List<VerticalFeedItem> _items = const [];
  String? _nextCursor;
  final Map<String, PreloadedPlayer> _players = {};
  bool _loading = false;
  String? _sessionId;

  List<VerticalFeedItem> get items => List.unmodifiable(_items);
  String? get nextCursor => _nextCursor;
  bool get hasData => _items.isNotEmpty;

  String _clientSessionId() =>
      _sessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

  /// Fetches feed items and silently initialises players for the first
  /// [_kPreloadCount] videos. Idempotent — does nothing if a load is already
  /// in progress or data is already present.
  Future<void> warmUp() async {
    if (_loading || _items.isNotEmpty) return;
    _loading = true;
    try {
      final result = await _repo.fetchVerticalFeed();
      _items = result.items;
      _nextCursor = result.nextCursor;
      for (var i = 0; i < _items.length && i < _kPreloadCount; i++) {
        unawaited(_initPlayer(_items[i]));
      }
    } catch (e) {
      logger.w('VerticalFeedPreloader: warmUp failed → $e');
    } finally {
      _loading = false;
    }
  }

  Future<void> _initPlayer(VerticalFeedItem item) async {
    if (_players.containsKey(item.mediaId)) return;
    try {
      String? url = _cache.get(item.mediaId)?.playbackUrl;
      if (url == null) {
        final info = await _repo.fetchPlaybackInfo(
          item.mediaId,
          clientSessionId: _clientSessionId(),
        );
        if (info != null) {
          _cache.put(item.mediaId, info);
          url = info.playbackUrl;
        }
      }
      if (url == null || url.isEmpty) return;
      if (_players.containsKey(item.mediaId)) return; // race guard

      final player = Player();
      final controller = VideoController(player);
      await player.open(Media(url), play: false);
      await player.setPlaylistMode(PlaylistMode.single);
      await player.setVolume(100);

      if (_players.containsKey(item.mediaId)) {
        // Concurrent call finished first — discard this duplicate.
        player.pause();
        player.dispose();
        return;
      }
      _players[item.mediaId] = PreloadedPlayer._(player, controller);
      logger.d('VerticalFeedPreloader: ready → ${item.mediaId}');
    } catch (e) {
      logger.w('VerticalFeedPreloader: init failed for ${item.mediaId} → $e');
    }
  }

  /// Removes and returns the pre-initialised player for [mediaId], transferring
  /// ownership to the caller. Returns null if not yet ready.
  PreloadedPlayer? takePlayer(String mediaId) => _players.remove(mediaId);

  /// Disposes all held players, clears cached feed data, then immediately
  /// starts a fresh [warmUp] so the next visit is equally fast.
  /// Call from [VerticalFeedScreen.dispose].
  void reset() {
    for (final p in _players.values) {
      p.player.pause();
      p.player.dispose();
    }
    _players.clear();
    _items = const [];
    _nextCursor = null;
    _sessionId = null;
    _loading = false;
    unawaited(warmUp());
  }
}
