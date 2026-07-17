import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import '../core/logger.dart';
import '../features/discovery/models/media_detail.dart';
import '../features/discovery/models/vertical_feed_item.dart';
import '../features/discovery/repo/discovery_repo.dart';
import '../services/analytics_service.dart';
import '../services/playback_info_cache.dart';
import '../services/token_storage_service.dart';
import '../services/vertical_feed_preloader.dart';
import '../utils/auth_sheet.dart';

class VerticalFeedScreen extends StatefulWidget {
  const VerticalFeedScreen({super.key});

  @override
  State<VerticalFeedScreen> createState() => _VerticalFeedScreenState();
}

class _VerticalFeedScreenState extends State<VerticalFeedScreen> {
  final _repo = GetIt.instance<DiscoveryRepo>();
  final _cache = GetIt.instance<PlaybackInfoCache>();
  final _pageController = PageController();

  final List<VerticalFeedItem> _items = [];
  int _currentIndex = 0;
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _sessionId;
  bool _isLoggedIn = false;

  String _clientSessionId() =>
      _sessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> _checkAuth() async {
    final has = await GetIt.instance<TokenStorageService>().hasSession;
    if (mounted) setState(() => _isLoggedIn = has);
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final preloader = GetIt.instance<VerticalFeedPreloader>();
    if (preloader.hasData) {
      _usePreloaderData(preloader);
    } else if (preloader.isWarmingUp) {
      // Warmup started in main() but isn't done yet — wait for it instead of
      // running a separate fetch that would duplicate the network calls.
      unawaited(_waitForWarmup(preloader));
    } else {
      _load();
    }
  }

  void _usePreloaderData(VerticalFeedPreloader preloader) {
    _items.addAll(preloader.items);
    _nextCursor = preloader.nextCursor;
    _loading = false;
    // Items 0-2 are already in cache and their players are initialising; pre-fetch
    // URLs for 3 & 4 so the cache is warm for when advance() initialises them.
    _prefetch(3);
    _prefetch(4);
  }

  Future<void> _waitForWarmup(VerticalFeedPreloader preloader) async {
    // 8-second ceiling — if the network is very slow, fall back to our own load.
    await preloader.whenWarmedUp.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
    if (!mounted) return;
    if (preloader.hasData && _items.isEmpty) {
      setState(() {
        _items.addAll(preloader.items);
        _nextCursor = preloader.nextCursor;
        _loading = false;
      });
      _prefetch(3);
      _prefetch(4);
    } else if (_items.isEmpty) {
      // Warmup timed out or failed — fetch independently.
      _load();
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    // Dispose held players and immediately re-warm for the next visit.
    GetIt.instance<VerticalFeedPreloader>().reset();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _nextCursor = null;
      _currentIndex = 0;
    });
    try {
      final result = await _repo.fetchVerticalFeed();
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _nextCursor = result.nextCursor;
        _loading = false;
      });
      _prefetch(0);
      _prefetch(1);
      _prefetch(2);
    } catch (e) {
      logger.e('VerticalFeed: load failed', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final seenIds = _items.map((i) => i.mediaId).toList();
      final result = await _repo.fetchVerticalFeed(
        cursor: _nextCursor,
        excludeMediaIds: seenIds,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _nextCursor = result.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      logger.e('VerticalFeed: loadMore failed', error: e);
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _prefetch(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    if (_cache.get(item.mediaId) != null) return;
    final usePublic = !GetIt.instance<VerticalFeedPreloader>().isAuthenticated;
    try {
      final info = await _repo.fetchPlaybackInfo(
        item.mediaId,
        clientSessionId: _clientSessionId(),
        usePublicRoute: usePublic,
      );
      if (info != null) _cache.put(item.mediaId, info);
    } catch (e) {
      logger.w('VerticalFeed: prefetch failed for ${item.mediaId}', error: e);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _prefetch(index + 1);
    _prefetch(index + 2);
    if (index >= _items.length - 3) { _loadMore(); }
    // Advance the rolling player window: initialise N+1 & N+2, dispose stale ones.
    GetIt.instance<VerticalFeedPreloader>().advance(index, _items);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return _buildShell(
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_error != null && _items.isEmpty) {
      return _buildShell(child: _buildError());
    }
    if (_items.isEmpty) {
      return _buildShell(
        child: const Center(
          child: Text('No videos available', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemCount: _items.length,
            itemBuilder: (context, i) => _VerticalFeedPage(
              key: ValueKey(_items[i].mediaId),
              item: _items[i],
              isActive: i == _currentIndex,
              // Keep currentIndex-1 (previous) alive for instant back-scroll.
              // Pre-init currentIndex+1 and currentIndex+2 (upcoming).
              preload: i != _currentIndex &&
                  i >= _currentIndex - 1 &&
                  i <= _currentIndex + 2,
              clientSessionId: _clientSessionId(),
              cache: _cache,
              isLoggedIn: _isLoggedIn,
            ),
          ),
          _buildTopBar(context),
        ],
      ),
    );
  }

  Widget _buildShell({required Widget child}) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(AppStrings.shortVideos),
        elevation: 0,
      ),
      body: child,
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                AppStrings.shortVideos,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'Could not load videos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual feed page ───────────────────────────────────────────────────────

enum _PagePhase { idle, loading, playing, error }

class _VerticalFeedPage extends StatefulWidget {
  const _VerticalFeedPage({
    super.key,
    required this.item,
    required this.isActive,
    required this.preload,
    required this.clientSessionId,
    required this.cache,
    required this.isLoggedIn,
  });

  final VerticalFeedItem item;
  final bool isActive;
  final bool preload;
  final String clientSessionId;
  final PlaybackInfoCache cache;
  final bool isLoggedIn;

  @override
  State<_VerticalFeedPage> createState() => _VerticalFeedPageState();
}

class _VerticalFeedPageState extends State<_VerticalFeedPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Player? _player;
  VideoController? _videoController;
  final List<StreamSubscription<dynamic>> _subs = [];
  _PagePhase _phase = _PagePhase.idle;
  bool _isMuted = false;
  bool _isDragging = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Creator info fetched from media detail endpoint (not in feed response)
  String? _creatorHandle;
  String? _creatorDisplayName;

  bool get _isPlaying => _player?.state.playing ?? false;
  bool get _isBuffering => _player?.state.buffering ?? false;

  // Analytics
  bool _analyticsViewStarted = false;
  double _lastProgressPos = 0;
  bool? _wasPlaying;

  @override
  void initState() {
    super.initState();
    _creatorHandle = widget.item.creatorHandle;
    _creatorDisplayName = widget.item.creatorDisplayName;
    if (widget.isActive) {
      _activate();
    } else if (widget.preload) {
      _preloadPlayer();
    }
  }

  @override
  void didUpdateWidget(_VerticalFeedPage old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _activate();
    } else if (!widget.isActive && old.isActive) {
      _deactivate();
    } else if (widget.preload && !old.preload && !widget.isActive) {
      _preloadPlayer();
    }
    // Dispose player when page falls outside the active+preload window
    // to limit native decoder slots held in memory.
    if (!widget.isActive && !widget.preload && (old.isActive || old.preload)) {
      _disposePlayer();
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.pause();
    _player?.dispose();
    if (_analyticsViewStarted) GetIt.instance<AnalyticsService>().flush();
    super.dispose();
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  Future<void> _activate() async {
    if (_player != null) {
      await _player!.play();
      return;
    }
    if (_phase == _PagePhase.loading) return;

    final preloader = GetIt.instance<VerticalFeedPreloader>();

    // Try an immediate claim first.
    var preloaded = preloader.takePlayer(widget.item.mediaId);

    // If the preloader is still opening the player, wait for it rather than
    // spawning a duplicate. This avoids duplicate network calls and gives the
    // fastest possible start when the user taps in before init completes.
    if (preloaded == null && preloader.isInitializing(widget.item.mediaId)) {
      setState(() => _phase = _PagePhase.loading);
      preloaded = await preloader.awaitPlayer(widget.item.mediaId);
      if (!mounted || _player != null) return;
      if (_phase != _PagePhase.loading) return; // _disposePlayer() ran while waiting
    }

    if (preloaded != null) {
      await _attachPreloaded(preloaded, play: true);
      return;
    }
    await _resolveAndStart(play: true);
  }

  Future<void> _preloadPlayer() async {
    if (_player != null || _phase == _PagePhase.loading) return;

    final preloader = GetIt.instance<VerticalFeedPreloader>();
    final preloaded = preloader.takePlayer(widget.item.mediaId);

    if (preloaded != null) {
      await _attachPreloaded(preloaded, play: false);
      return;
    }
    // If the preloader is already initialising this item, don't race with it —
    // leave the player in _players so _activate() can claim it instantly.
    if (preloader.isInitializing(widget.item.mediaId)) return;
    await _resolveAndStart(play: false);
  }

  /// Attaches a player that was already opened by [VerticalFeedPreloader].
  /// Skips the loading phase entirely — the player is already buffering.
  Future<void> _attachPreloaded(PreloadedPlayer preloaded, {required bool play}) async {
    final player = preloaded.player;
    final controller = preloaded.controller;
    _player = player;
    _videoController = controller;

    // Sync whatever state the player already accumulated while preloading.
    _position = player.state.position;
    _duration = player.state.duration;

    _subs.addAll([
      player.stream.playing.listen((v) {
        if (!mounted) return;
        _trackPlayAnalytics(playing: v);
        setState(() {});
      }),
      player.stream.position.listen((v) {
        if (!mounted || _isDragging) return;
        _trackProgressAnalytics(v);
        setState(() => _position = v);
      }),
      player.stream.duration.listen((v) {
        if (mounted) setState(() => _duration = v);
      }),
      player.stream.buffering.listen((_) {
        if (mounted) setState(() {});
      }),
      player.stream.error.listen((e) {
        if (!mounted) return;
        if (e.contains('audio device') || e.contains('no sound')) {
          logger.d('VerticalFeedPage: non-fatal audio init warning (ignored) → $e');
          return;
        }
        logger.e('VerticalFeedPage: player error → $e');
        setState(() => _phase = _PagePhase.error);
      }),
    ]);

    if (!mounted) {
      _disposePlayer();
      return;
    }

    setState(() => _phase = _PagePhase.playing);
    unawaited(_fetchCreatorInfo());

    await player.setVolume(_isMuted ? 0 : 100);
    if (!mounted || _player != player) return;

    if (play) {
      await player.play();
    } else if (widget.isActive) {
      // Preload→activate race: page became active while attaching with play:false.
      await _player?.play();
    }
  }

  void _deactivate() {
    _player?.pause();
  }

  void _disposePlayer() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player?.pause();
    _player?.dispose();
    _player = null;
    _videoController = null;
    if (mounted) {
      setState(() {
        _phase = _PagePhase.idle;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
    }
  }

  Future<String?> _resolveUrl() async {
    final cached = widget.cache.get(widget.item.mediaId);
    if (cached != null) {
      // URL is cached but creator info may not be — fetch it now without blocking.
      unawaited(_fetchCreatorInfo());
      return cached.playbackUrl;
    }
    final detail = await GetIt.instance<DiscoveryRepo>().fetchMediaDetail(
      widget.item.mediaId,
      clientSessionId: widget.clientSessionId,
      includeSuggestions: false,
    );
    if (detail.playback != null) widget.cache.put(widget.item.mediaId, detail.playback!);
    _applyCreatorInfo(detail.creator);
    return detail.playback?.playbackUrl;
  }

  Future<void> _fetchCreatorInfo() async {
    if (_creatorHandle != null || _creatorDisplayName != null) return;
    try {
      final detail = await GetIt.instance<DiscoveryRepo>().fetchMediaDetail(
        widget.item.mediaId,
        clientSessionId: widget.clientSessionId,
        includeSuggestions: false,
      );
      if (mounted) _applyCreatorInfo(detail.creator);
    } catch (e) {
      logger.w('VerticalFeedPage: creator info fetch failed → $e');
    }
  }

  void _applyCreatorInfo(MediaCreatorInfo? creator) {
    if (creator == null) return;
    final handle = creator.handle.isNotEmpty ? creator.handle : null;
    final name = creator.displayName.isNotEmpty ? creator.displayName : null;
    if (handle == _creatorHandle && name == _creatorDisplayName) return;
    if (mounted) setState(() { _creatorHandle = handle; _creatorDisplayName = name; });
  }

  Future<void> _resolveAndStart({required bool play}) async {
    setState(() => _phase = _PagePhase.loading);
    try {
      final url = await _resolveUrl();
      if (!mounted) return;
      // Guard: _disposePlayer() may have been called while the URL was being
      // fetched (e.g. the user scrolled rapidly). It resets _phase to idle,
      // so if we're no longer in loading state, abandon this initialisation.
      if (_phase != _PagePhase.loading) return;
      if (url == null || url.isEmpty) {
        setState(() => _phase = _PagePhase.error);
        return;
      }
      // Re-derive play intent from the current widget state after the async
      // gap — guards the deactivate-during-fetch and activate-during-preload races.
      await _startPlayer(url, play: widget.isActive);
    } catch (e) {
      logger.e(
        'VerticalFeedPage: resolveAndStart failed for ${widget.item.mediaId}',
        error: e,
      );
      if (mounted) setState(() => _phase = _PagePhase.error);
    }
  }

  Future<void> _startPlayer(String url, {required bool play}) async {
    final player = Player();
    final controller = VideoController(player);
    _player = player;
    _videoController = controller;

    _subs.addAll([
      player.stream.playing.listen((v) {
        if (!mounted) return;
        _trackPlayAnalytics(playing: v);
        setState(() {});
      }),
      player.stream.position.listen((v) {
        if (!mounted || _isDragging) return;
        _trackProgressAnalytics(v);
        setState(() => _position = v);
      }),
      player.stream.duration.listen((v) {
        if (mounted) setState(() => _duration = v);
      }),
      player.stream.buffering.listen((_) {
        if (mounted) setState(() {});
      }),
      player.stream.error.listen((e) {
        if (!mounted) return;
        if (e.contains('audio device') || e.contains('no sound')) {
          logger.d('VerticalFeedPage: non-fatal audio init warning (ignored) → $e');
          return;
        }
        logger.e('VerticalFeedPage: player error → $e');
        setState(() => _phase = _PagePhase.error);
      }),
    ]);

    try {
      await player.open(Media(url), play: play);
      await player.setPlaylistMode(PlaylistMode.single);
      await player.setVolume(_isMuted ? 0 : 100);
      // Guard: _disposePlayer() sets _player = null while open() is awaiting.
      // If _player no longer matches our local reference, we've been cancelled.
      // The subs and player were already cleaned up by _disposePlayer; just return.
      if (!mounted || _player != player) {
        return;
      }
      setState(() => _phase = _PagePhase.playing);
      // Handle preload→activate race: page became active while we were
      // initializing with play: false, so start playing now.
      if (!play && widget.isActive) {
        await _player?.play();
      }
    } catch (e) {
      logger.e('VerticalFeedPage: startPlayer failed', error: e);
      for (final s in _subs) {
        s.cancel();
      }
      _subs.clear();
      player.dispose();
      _player = null;
      _videoController = null;
      if (mounted) setState(() => _phase = _PagePhase.error);
    }
  }

  void _togglePlayPause() {
    if (_player == null) return;
    if (_isPlaying) {
      _player!.pause();
    } else {
      _player!.play();
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _player?.setVolume(_isMuted ? 0 : 100);
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  void _trackPlayAnalytics({required bool playing}) {
    final analytics = GetIt.instance<AnalyticsService>();
    final pos = (_player?.state.position.inMilliseconds ?? 0) / 1000.0;
    if (!_analyticsViewStarted && playing) {
      _analyticsViewStarted = true;
      analytics.trackViewStarted(
        mediaId: widget.item.mediaId,
        creatorId: widget.item.creatorId,
        source: 'home_feed',
        positionSeconds: pos,
      );
      _wasPlaying = playing;
      return;
    }
    if (_wasPlaying != null && _wasPlaying != playing) {
      if (playing) {
        analytics.trackPlay(
          mediaId: widget.item.mediaId,
          creatorId: widget.item.creatorId,
          positionSeconds: pos,
          source: 'home_feed',
        );
      } else {
        analytics.trackPause(
          mediaId: widget.item.mediaId,
          creatorId: widget.item.creatorId,
          positionSeconds: pos,
          source: 'home_feed',
        );
      }
    }
    _wasPlaying = playing;
  }

  void _trackProgressAnalytics(Duration position) {
    if (!_analyticsViewStarted || !_isPlaying) return;
    final pos = position.inMilliseconds / 1000.0;
    if ((pos - _lastProgressPos) >= 10.0) {
      _lastProgressPos = pos;
      GetIt.instance<AnalyticsService>().trackProgress(
        mediaId: widget.item.mediaId,
        creatorId: widget.item.creatorId,
        positionSeconds: pos,
        source: 'home_feed',
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          _buildMedia(),
          // Bottom-heavy gradient for text readability
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.45, 1.0],
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),
          // Loading / buffering spinner
          if (_phase == _PagePhase.loading ||
              (_phase == _PagePhase.playing && _isBuffering))
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          // Error state
          if (_phase == _PagePhase.error)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_off_rounded,
                    color: Colors.white38,
                    size: 48,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Playback unavailable',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          // Pause flash — only show when user manually paused (not during buffering)
          if (_phase == _PagePhase.playing && !_isPlaying && !_isBuffering)
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pause_rounded,
                  color: Colors.white70,
                  size: 36,
                ),
              ),
            ),
          _buildRightActions(),
          _buildBottomInfo(),
          _buildScrubber(context),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    if (_phase != _PagePhase.playing || _videoController == null) {
      if (widget.item.thumbnailUrl != null) {
        return Image.network(
          widget.item.thumbnailUrl!,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : const SizedBox.shrink(),
        );
      }
      return const SizedBox.shrink();
    }
    // BoxFit.contain: video keeps its native aspect ratio centered in the frame.
    // Landscape (16:9) videos get letterboxed; portrait fills the screen.
    return Video(
      controller: _videoController!,
      controls: NoVideoControls,
      fit: BoxFit.contain,
    );
  }

  Widget _buildRightActions() {
    final item = widget.item;
    return Positioned(
      right: 8,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AvatarButton(
                displayName: _creatorDisplayName ?? _creatorHandle ?? '',
                onFollow: () {
                  if (!widget.isLoggedIn) {
                    showAuthSheet(context, 'follow this creator');
                    return;
                  }
                  // TODO: implement follow
                },
              ),
              const SizedBox(height: 24),
              _FeedActionButton(
                icon: IconsaxPlusLinear.heart,
                label: _formatCount(item.likeCount),
                color: Colors.white,
                onTap: () {
                  if (!widget.isLoggedIn) {
                    showAuthSheet(context, 'like this video');
                    return;
                  }
                  // TODO: implement like
                },
              ),
              const SizedBox(height: 20),
              _FeedActionButton(
                icon: IconsaxPlusLinear.message,
                label: _formatCount(item.commentCount),
                onTap: () {
                  if (!widget.isLoggedIn) {
                    showAuthSheet(context, 'comment on this video');
                    return;
                  }
                  // TODO: open comment sheet
                },
              ),
              const SizedBox(height: 20),
              _FeedActionButton(
                icon: IconsaxPlusLinear.send,
                label: 'Share',
                onTap: () {
                  // Share is available to all users
                },
              ),
              const SizedBox(height: 20),
              _FeedActionButton(
                icon: _isMuted
                    ? IconsaxPlusLinear.volume_slash
                    : IconsaxPlusLinear.volume_high,
                label: _isMuted ? 'Unmute' : 'Sound',
                onTap: _toggleMute,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInfo() {
    final item = widget.item;
    final channelLabel = _creatorHandle != null
        ? '@$_creatorHandle'
        : _creatorDisplayName;
    return Positioned(
      left: 12,
      right: 80,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.isLiveNow)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: _LiveBadge(),
                ),
              if (channelLabel != null)
                Text(
                  channelLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrubber(BuildContext context) {
    if (_duration == Duration.zero) return const SizedBox.shrink();
    final progress =
        (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2.5,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          activeTrackColor: Colors.white,
          inactiveTrackColor: Colors.white30,
          thumbColor: Colors.white,
          overlayColor: Colors.white24,
          trackShape: const RectangularSliderTrackShape(),
        ),
        child: Slider(
          value: progress,
          onChangeStart: (_) => setState(() => _isDragging = true),
          onChanged: (v) {
            final pos = Duration(
              milliseconds: (v * _duration.inMilliseconds).round(),
            );
            setState(() => _position = pos);
          },
          onChangeEnd: (v) {
            final pos = Duration(
              milliseconds: (v * _duration.inMilliseconds).round(),
            );
            _player?.seek(pos);
            setState(() => _isDragging = false);
          },
        ),
      ),
    );
  }

  String _formatCount(int? count) {
    if (count == null) return '';
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _AvatarButton extends StatelessWidget {
  final String displayName;
  final VoidCallback onFollow;
  const _AvatarButton({required this.displayName, required this.onFollow});

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return SizedBox(
      width: 52,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              color: AppColors.surfaceVariant,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: onFollow,
              child: Center(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _FeedActionButton({
    required this.icon,
    this.label = '',
    this.color = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 30,
            shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.white, size: 7),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
