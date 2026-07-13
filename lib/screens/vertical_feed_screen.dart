import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import '../core/logger.dart';
import '../features/discovery/models/vertical_feed_item.dart';
import '../features/discovery/repo/discovery_repo.dart';
import '../services/analytics_service.dart';
import '../services/playback_info_cache.dart';

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

  String _clientSessionId() =>
      _sessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _load();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
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
    try {
      final info = await _repo.fetchPlaybackInfo(
        item.mediaId,
        clientSessionId: _clientSessionId(),
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
    if (index >= _items.length - 3) _loadMore();
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
              preload: i == _currentIndex + 1,
              clientSessionId: _clientSessionId(),
              cache: _cache,
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
  });

  final VerticalFeedItem item;
  final bool isActive;
  final bool preload;
  final String clientSessionId;
  final PlaybackInfoCache cache;

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
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool get _isPlaying => _player?.state.playing ?? false;
  bool get _isBuffering => _player?.state.buffering ?? false;

  // Analytics
  bool _analyticsViewStarted = false;
  double _lastProgressPos = 0;
  bool? _wasPlaying;

  @override
  void initState() {
    super.initState();
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
    await _resolveAndStart(play: true);
  }

  Future<void> _preloadPlayer() async {
    if (_player != null || _phase == _PagePhase.loading) return;
    await _resolveAndStart(play: false);
  }

  void _deactivate() {
    _player?.pause();
  }

  void _disposePlayer() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
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
    if (cached != null) return cached.playbackUrl;
    final info = await GetIt.instance<DiscoveryRepo>().fetchPlaybackInfo(
      widget.item.mediaId,
      clientSessionId: widget.clientSessionId,
    );
    if (info != null) widget.cache.put(widget.item.mediaId, info);
    return info?.playbackUrl;
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
        if (!mounted) return;
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
        source: 'vertical_feed',
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
          source: 'vertical_feed',
        );
      } else {
        analytics.trackPause(
          mediaId: widget.item.mediaId,
          creatorId: widget.item.creatorId,
          positionSeconds: pos,
          source: 'vertical_feed',
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
        source: 'vertical_feed',
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
                displayName: item.creatorDisplayName ?? item.creatorId,
              ),
              const SizedBox(height: 24),
              _FeedActionButton(
                icon: Icons.favorite_rounded,
                label: _formatCount(item.likeCount),
                color: Colors.white,
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _FeedActionButton(
                icon: Icons.chat_bubble_rounded,
                label: _formatCount(item.commentCount),
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _FeedActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _FeedActionButton(
                icon: _isMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
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
              Text(
                '@${item.creatorHandle ?? item.creatorId}',
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
    // Offset above the system gesture bar so it's always visible.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset,
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.white24,
        color: Colors.white70,
        minHeight: 2,
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
  const _AvatarButton({required this.displayName});

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
