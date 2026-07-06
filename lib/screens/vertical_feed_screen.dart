import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:video_player/video_player.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import '../core/app_styles.dart';
import '../core/logger.dart';
import '../features/discovery/models/vertical_feed_item.dart';
import '../features/discovery/repo/discovery_repo.dart';
import '../services/analytics_service.dart';

class VerticalFeedScreen extends StatefulWidget {
  const VerticalFeedScreen({super.key});

  @override
  State<VerticalFeedScreen> createState() => _VerticalFeedScreenState();
}

class _VerticalFeedScreenState extends State<VerticalFeedScreen> {
  final _repo = GetIt.instance<DiscoveryRepo>();
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

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    if (index >= _items.length - 3) {
      _loadMore();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Loading & error states get a simple scaffold so the back button is visible.
    if (_loading && _items.isEmpty) {
      return _buildShell(
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return _buildShell(child: _buildError());
    }

    if (_items.isEmpty) {
      return _buildShell(
        child: const Center(
          child: Text(
            'No videos available',
            style: TextStyle(color: Colors.white70),
          ),
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
              clientSessionId: _clientSessionId(),
            ),
          ),
          _buildTopOverlay(context),
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

  Widget _buildTopOverlay(BuildContext context) {
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
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: Colors.white38,
            ),
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
    required this.clientSessionId,
  });

  final VerticalFeedItem item;
  final bool isActive;
  final String clientSessionId;

  @override
  State<_VerticalFeedPage> createState() => _VerticalFeedPageState();
}

class _VerticalFeedPageState extends State<_VerticalFeedPage> {
  VideoPlayerController? _controller;
  _PagePhase _phase = _PagePhase.idle;
  bool _isMuted = false;

  bool get _isPlaying => _controller?.value.isPlaying ?? false;

  bool _analyticsViewStarted = false;
  double _lastProgressPos = 0;
  bool? _wasPlaying;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _activate();
  }

  @override
  void didUpdateWidget(_VerticalFeedPage old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _activate();
    } else if (!widget.isActive && old.isActive) {
      _deactivate();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    if (_analyticsViewStarted) GetIt.instance<AnalyticsService>().flush();
    super.dispose();
  }

  // ── Playback control ──────────────────────────────────────────────────────────

  Future<void> _activate() async {
    // Already have a controller — just resume.
    if (_controller != null) {
      _controller!.play();
      return;
    }
    // Already fetching — don't start a second request.
    if (_phase == _PagePhase.loading) return;

    setState(() => _phase = _PagePhase.loading);
    try {
      final repo = GetIt.instance<DiscoveryRepo>();
      final info = await repo.fetchPlaybackInfo(
        widget.item.mediaId,
        clientSessionId: widget.clientSessionId,
      );
      if (!mounted) return;
      final url = info?.playbackUrl;
      if (url == null || url.isEmpty) {
        setState(() => _phase = _PagePhase.error);
        return;
      }
      await _startController(url);
    } catch (e) {
      logger.e('VerticalFeedPage: activate failed for ${widget.item.mediaId}', error: e);
      if (mounted) setState(() => _phase = _PagePhase.error);
    }
  }

  void _deactivate() {
    _controller?.pause();
  }

  Future<void> _startController(String url) async {
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = ctrl;
    ctrl.addListener(_onControllerUpdate);

    try {
      await ctrl.initialize();
      if (!mounted) {
        ctrl.removeListener(_onControllerUpdate);
        ctrl.dispose();
        _controller = null;
        return;
      }
      // Don't play if the page was deactivated while we were initializing.
      if (!widget.isActive) {
        setState(() => _phase = _PagePhase.playing); // ready but paused
        return;
      }
      await ctrl.setLooping(true);
      await ctrl.setVolume(_isMuted ? 0 : 1);
      await ctrl.play();
      if (mounted) setState(() => _phase = _PagePhase.playing);
    } catch (e) {
      logger.e('VerticalFeedPage: controller init failed', error: e);
      ctrl.removeListener(_onControllerUpdate);
      ctrl.dispose();
      _controller = null;
      if (mounted) setState(() => _phase = _PagePhase.error);
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final value = _controller?.value;
    if (value != null) _trackAnalytics(value);
    setState(() {});
  }

  void _trackAnalytics(VideoPlayerValue value) {
    final analytics = GetIt.instance<AnalyticsService>();
    final mediaId = widget.item.mediaId;
    final creatorId = widget.item.creatorId;
    final position = value.position.inMilliseconds / 1000.0;
    final isPlaying = value.isPlaying;

    if (!_analyticsViewStarted && isPlaying) {
      _analyticsViewStarted = true;
      analytics.trackViewStarted(
        mediaId: mediaId,
        creatorId: creatorId,
        source: 'vertical_feed',
        positionSeconds: position,
      );
      _wasPlaying = isPlaying;
      return;
    }
    if (_wasPlaying != null && _wasPlaying != isPlaying) {
      if (isPlaying) {
        analytics.trackPlay(
          mediaId: mediaId,
          creatorId: creatorId,
          positionSeconds: position,
          source: 'vertical_feed',
        );
      } else {
        analytics.trackPause(
          mediaId: mediaId,
          creatorId: creatorId,
          positionSeconds: position,
          source: 'vertical_feed',
        );
      }
    }
    _wasPlaying = isPlaying;
    if (isPlaying && (position - _lastProgressPos) >= 10.0) {
      _lastProgressPos = position;
      analytics.trackProgress(
        mediaId: mediaId,
        creatorId: creatorId,
        positionSeconds: position,
        source: 'vertical_feed',
      );
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _toggleMute() {
    _isMuted = !_isMuted;
    _controller?.setVolume(_isMuted ? 0 : 1);
    setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          _buildMedia(),
          _buildGradients(),
          if (_phase == _PagePhase.loading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
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
          // Pause icon flash
          if (_phase == _PagePhase.playing && !_isPlaying)
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pause_rounded,
                  color: Colors.white70,
                  size: 40,
                ),
              ),
            ),
          _buildInfoOverlay(),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    // Show thumbnail until video is ready.
    if (_phase != _PagePhase.playing && widget.item.thumbnailUrl != null) {
      return Image.network(
        widget.item.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : const SizedBox.shrink(),
      );
    }

    if (_phase == _PagePhase.playing && _controller != null) {
      final size = _controller!.value.size;
      if (size == Size.zero) return const SizedBox.shrink();
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildGradients() => const Positioned.fill(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.35, 0.65, 1.0],
          colors: [
            Colors.black38,
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
          ],
        ),
      ),
    ),
  );

  Widget _buildInfoOverlay() {
    return Positioned(
      left: 16,
      right: 72,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.item.isLiveNow)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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
                  ),
                ),
              Text(
                widget.item.title,
                style: AppStyles.playerTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Positioned(
      right: 8,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: _isMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                label: _isMuted ? 'Unmute' : 'Mute',
                onTap: _toggleMute,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small action button (right-side column) ───────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black87)]),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
