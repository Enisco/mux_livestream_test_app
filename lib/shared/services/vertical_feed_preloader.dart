import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/models/discovery_models/vertical_feed_item.dart';
import 'package:test_app/shared/services/app_session_service.dart';
import 'package:test_app/shared/services/playback_info_cache.dart';
import 'package:test_app/shared/services/token_storage_service.dart';

const _kInitialPreloadCount = 3;

class PreloadedPlayer {
  final Player player;
  final VideoController controller;
  PreloadedPlayer._(this.player, this.controller);
}

class VerticalFeedPreloader {
  final DiscoveryRepo _repo;
  final PlaybackInfoCache _cache;
  final TokenStorageService _tokenStorage;
  final AppSessionService _session;

  VerticalFeedPreloader({
    required DiscoveryRepo repo,
    required PlaybackInfoCache cache,
    required TokenStorageService tokenStorage,
    required AppSessionService session,
  }) : _repo = repo,
       _cache = cache,
       _tokenStorage = tokenStorage,
       _session = session;

  List<VerticalFeedItem> _items = const [];
  String? _nextCursor;

  final Map<String, PreloadedPlayer> _players = {};
  final Set<String> _initializing = {};
  final Set<String> _claimed = {};

  final Map<String, Completer<PreloadedPlayer?>> _awaitingPlayer = {};
  Completer<void>? _warmupCompleter;

  bool _loading = false;
  bool _isAuthenticated = false;

  List<VerticalFeedItem> get items => List.unmodifiable(_items);
  String? get nextCursor => _nextCursor;
  bool get hasData => _items.isNotEmpty;

  bool get isAuthenticated => _isAuthenticated;

  bool get isWarmingUp => _loading;

  Future<void> get whenWarmedUp {
    if (!_loading) return Future.value();
    _warmupCompleter ??= Completer<void>();
    return _warmupCompleter!.future;
  }

  bool isInitializing(String mediaId) => _initializing.contains(mediaId);

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
          clientSessionId: _session.clientSessionId,
          usePublicRoute: !_isAuthenticated,
        );
        if (info != null) {
          _cache.put(item.mediaId, info);
          url = info.playbackUrl;
        }
      }
      if (url == null || url.isEmpty) return;
      if (_players.containsKey(item.mediaId) ||
          _claimed.contains(item.mediaId)) {
        return;
      }

      final player = Player();
      final controller = VideoController(player);
      await player.open(Media(url), play: false);
      await player.setPlaylistMode(PlaylistMode.single);
      await player.setVolume(100);

      if (_players.containsKey(item.mediaId) ||
          _claimed.contains(item.mediaId)) {
        player.pause();
        player.dispose();
        return;
      }

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
      _awaitingPlayer.remove(item.mediaId)?.complete(null);
    }
  }

  PreloadedPlayer? takePlayer(String mediaId) {
    _claimed.add(mediaId);
    return _players.remove(mediaId);
  }

  Future<PreloadedPlayer?> awaitPlayer(String mediaId) async {
    final existing = _players.remove(mediaId);
    if (existing != null) {
      _claimed.add(mediaId);
      return existing;
    }
    if (!_initializing.contains(mediaId)) return null;

    final completer = Completer<PreloadedPlayer?>();
    _awaitingPlayer[mediaId] = completer;
    return completer.future;
  }

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
    _loading = false;
    _isAuthenticated = false;
    unawaited(warmUp());
  }
}
