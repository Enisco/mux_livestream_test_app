import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import '../core/app_styles.dart';
import '../core/logger.dart';
import '../services/analytics_service.dart';
import '../widgets/player/controls_overlay.dart';

class PlayerScreen extends StatefulWidget {
  final String? filePath;
  final String? networkUrl;
  final String? title;
  final String? mediaId;
  final String? creatorId;
  final String source;

  const PlayerScreen.file({super.key, required this.filePath, this.title})
    : networkUrl = null,
      mediaId = null,
      creatorId = null,
      source = 'unknown';

  const PlayerScreen.network({
    super.key,
    required this.networkUrl,
    this.title,
    this.mediaId,
    this.creatorId,
    this.source = 'unknown',
  }) : filePath = null;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late Player _player;
  late VideoController _videoController;
  final List<StreamSubscription<dynamic>> _subs = [];

  // Initialisation
  bool _isInitialized = false;
  bool _isBuffering = true;
  bool _hasError = false;
  bool _isStreamInactive = false;
  bool _isRetrying = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  // Playback state (mirrored from player streams for build)
  bool _isPlaying = false;
  bool _isCompleted = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0; // 0–1 for UI; multiply ×100 for player API

  // Controls
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isFullscreen = false;
  double _playbackSpeed = 1.0;

  // Quality
  List<String> _qualityLabels = const ['Auto'];
  String _currentQuality = 'Auto';
  final Map<String, VideoTrack> _qualityTrackMap = {
    'Auto': VideoTrack.auto(),
  };
  // HLS streams: label → bandwidth in bps (0 = Auto/no preference).
  // Populated by _loadHlsQualities() from the master playlist.
  final Map<String, int> _hlsBitrateMap = {};

  // Analytics
  bool _analyticsViewStarted = false;
  bool _analyticsCompleted = false;
  double _lastProgressPos = 0;

  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  static const _maxRetries = 6;
  static const _retryDelay = Duration(seconds: 5);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _listenStreams();
    _initPlayer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _retryTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    // Pause first so libmpv reaches an idle state before shutdown; disposing
    // while a network operation is in-flight causes core_thread to fire a
    // cleanup event into Dart after the FFI callbacks are already freed.
    _player.pause();
    _player.dispose();
    _restorePortrait();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _mediaUri {
    if (widget.networkUrl != null) return widget.networkUrl!;
    final p = widget.filePath!;
    if (p.startsWith('content://') || p.startsWith('file://')) return p;
    return File(p).uri.toString();
  }

  String get _displayTitle {
    if (widget.title != null && widget.title!.isNotEmpty) return widget.title!;
    if (widget.networkUrl != null) return '';
    return widget.filePath!.split(Platform.pathSeparator).last;
  }

  bool get _isHlsStream => widget.networkUrl != null;

  // ── Stream wiring ──────────────────────────────────────────────────────────

  void _listenStreams() {
    _subs.addAll([
      _player.stream.playing.listen(_onPlaying),
      _player.stream.completed.listen(_onCompleted),
      _player.stream.position.listen(_onPosition),
      _player.stream.duration.listen(
        (v) { if (mounted) setState(() => _duration = v); },
      ),
      _player.stream.volume.listen(
        (v) { if (mounted) setState(() => _volume = v / 100.0); },
      ),
      _player.stream.buffering.listen(
        (v) { if (mounted) setState(() => _isBuffering = v); },
      ),
      _player.stream.error.listen(_onError),
      _player.stream.tracks.listen(_onTracksChanged),
      _player.stream.track.listen(_onTrackChanged),
    ]);
  }

  // ── Player init / retry ────────────────────────────────────────────────────

  Future<void> _initPlayer() async {
    final uri = _mediaUri;
    logger.d(
      'PlayerScreen: opening → $uri (attempt ${_retryCount + 1}/${_maxRetries + 1})',
    );
    try {
      await _player.open(Media(uri));
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isRetrying = false;
          _hasError = false;
          _isStreamInactive = false;
        });
        if (_isHlsStream) unawaited(_loadHlsQualities());
        _scheduleHide();
      }
    } catch (e, st) {
      logger.e('PlayerScreen: open() threw\n$uri', error: e, stackTrace: st);
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _retry() {
    _retryTimer?.cancel();
    // Tear down the old player fully before retrying — calling open() on a
    // completed player while old FFI callbacks are still wired causes a
    // use-after-free in libmpv's event thread.
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player.pause();
    _player.dispose();
    _player = Player();
    _videoController = VideoController(_player);
    _listenStreams();
    _qualityTrackMap
      ..clear()
      ..['Auto'] = VideoTrack.auto();
    _hlsBitrateMap.clear();
    setState(() {
      _hasError = false;
      _isStreamInactive = false;
      _isRetrying = false;
      _retryCount = 0;
      _isInitialized = false;
      _isBuffering = true;
      _isPlaying = false;
      _isCompleted = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _lastProgressPos = 0;
      _qualityLabels = const ['Auto'];
      _currentQuality = 'Auto';
    });
    _initPlayer();
  }

  // ── Stream callbacks ───────────────────────────────────────────────────────

  void _onPlaying(bool v) {
    if (!mounted) return;
    final prev = _isPlaying;
    setState(() => _isPlaying = v);
    // Schedule auto-hide whenever playback actually starts (including replay).
    // _togglePlay() can't do this reliably because _isPlaying is still false
    // at the point it calls _scheduleHide().
    if (v) _scheduleHide();
    _trackPlayPause(wasPlaying: prev, nowPlaying: v);
  }

  void _onCompleted(bool v) {
    if (!mounted) return;
    if (v) {
      _hideTimer?.cancel();
      setState(() {
        _isCompleted = true;
        _showControls = true;
      });
      _trackCompletion();
    } else {
      setState(() => _isCompleted = false);
    }
  }

  void _onPosition(Duration v) {
    if (!mounted) return;
    setState(() => _position = v);
    _trackProgress(v);
  }

  void _onError(String error) {
    if (!mounted || error.isEmpty) return;
    // libmpv fires this on iOS when the audio session isn't ready yet; the
    // video decoder continues regardless and the player recovers on its own.
    if (error.contains('audio device') || error.contains('no sound')) {
      logger.d('PlayerScreen: non-fatal audio init warning (ignored) → $error');
      return;
    }
    logger.e('PlayerScreen: playback error → $error');
    final inactive = error.contains('412') ||
        error.contains('-16845') ||
        error.contains('Precondition Failed');
    // CDN/network blips (TCP timeout, connection reset, etc.) are transient —
    // retry rather than surfacing a hard "Failed to load" immediately.
    final transient = !inactive &&
        (error.contains('timed out') ||
            error.contains('timeout') ||
            error.contains('Operation timed out') ||
            error.contains('Connection reset') ||
            error.contains('Connection refused') ||
            error.contains('Network is unreachable') ||
            error.contains('tcp:'));
    if ((inactive || transient) && _retryCount < _maxRetries) {
      _retryCount++;
      logger.d(
        'PlayerScreen: ${transient ? 'transient network error' : 'stream inactive'}, '
        'retrying ($_retryCount/$_maxRetries)',
      );
      setState(() => _isRetrying = true);
      _retryTimer?.cancel();
      _retryTimer = Timer(_retryDelay, _initPlayer);
    } else if (!_hasError) {
      setState(() {
        _hasError = true;
        _isStreamInactive = inactive;
        _isRetrying = false;
      });
    }
  }

  void _onTracksChanged(Tracks tracks) {
    if (!mounted) return;
    // For HLS network streams libmpv doesn't surface per-rendition resolution
    // metadata through its track API. Quality options come from the manifest
    // parsed in _loadHlsQualities() instead.
    if (_isHlsStream) return;
    final labels = <String>[];
    final map = <String, VideoTrack>{};
    for (var i = 0; i < tracks.video.length; i++) {
      final t = tracks.video[i];
      final label = _trackLabel(t, i);
      if (!map.containsKey(label)) {
        labels.add(label);
        map[label] = t;
      }
    }
    // Always include Auto so the player can pick the best rendition,
    // and so _currentQuality == 'Auto' is always a valid map key.
    if (!map.containsKey('Auto')) {
      labels.insert(0, 'Auto');
      map['Auto'] = VideoTrack.auto();
    }
    setState(() {
      _qualityLabels = labels;
      _qualityTrackMap
        ..clear()
        ..addAll(map);
      if (!_qualityLabels.contains(_currentQuality)) {
        _currentQuality = 'Auto';
      }
    });
  }

  void _onTrackChanged(Track t) {
    if (!mounted) return;
    // For HLS streams quality is managed via hls-bitrate; internal ABR switches
    // must not reset the label the user explicitly chose.
    if (_isHlsStream) return;
    final vt = t.video;
    String label = 'Auto';
    for (final e in _qualityTrackMap.entries) {
      if (e.value.id == vt.id) {
        label = e.key;
        break;
      }
    }
    setState(() => _currentQuality = label);
  }

  String _trackLabel(VideoTrack t, int index) {
    if (t.id == 'auto') return 'Auto';
    if (t.title != null && t.title!.isNotEmpty) return t.title!;
    // Use the track height (e.g. 1080 → "1080p") from the HLS manifest.
    if (t.h != null && t.h! > 0) return '${t.h}p';
    if (t.w != null && t.w! > 0) return '${t.w}p';
    return 'Track ${index + 1}';
  }

  // ── HLS quality (manifest-based) ──────────────────────────────────────────

  Future<void> _loadHlsQualities() async {
    final uri = _mediaUri;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(uri));
      final response = await request.close();
      if (response.statusCode != 200) {
        logger.w(
          'PlayerScreen: HLS manifest returned ${response.statusCode}, skipping',
        );
        return;
      }
      final content = await response.transform(utf8.decoder).join();
      if (mounted) _parseAndApplyHlsQualities(content);
    } catch (e) {
      logger.w('PlayerScreen: HLS manifest fetch failed → $e');
    } finally {
      client.close();
    }
  }

  void _parseAndApplyHlsQualities(String content) {
    final seenLabels = <String>{};
    final renditions = <MapEntry<int, String>>[]; // bandwidth → label
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('#EXT-X-STREAM-INF:')) continue;
      final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(trimmed);
      final resMatch = RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(trimmed);
      if (bwMatch == null) continue;
      final bw = int.parse(bwMatch.group(1)!);
      final height = resMatch != null ? int.tryParse(resMatch.group(1)!) : null;
      final label = height != null ? '${height}p' : '${(bw / 1000).round()}k';
      if (seenLabels.add(label)) {
        renditions.add(MapEntry(bw, label));
      }
    }
    if (renditions.isEmpty) {
      logger.w('PlayerScreen: no HLS renditions found in manifest');
      return;
    }
    renditions.sort((a, b) => a.key.compareTo(b.key));
    logger.d(
      'PlayerScreen: HLS renditions → '
      '${renditions.map((r) => '${r.value}@${r.key}bps').join(', ')}',
    );
    final newMap = <String, int>{'Auto': 0};
    for (final r in renditions) {
      newMap[r.value] = r.key;
    }
    setState(() {
      _hlsBitrateMap
        ..clear()
        ..addAll(newMap);
      _qualityLabels = ['Auto', ...renditions.map((r) => r.value)];
      _currentQuality = 'Auto';
    });
  }

  Future<void> _setHlsQuality(String label) async {
    final bw = _hlsBitrateMap[label];
    if (bw == null) return;
    // 'no' lets libmpv resume automatic ABR; a number forces the nearest
    // rendition by bandwidth.
    final value = bw == 0 ? 'no' : bw.toString();
    try {
      await (_player.platform as NativePlayer).setProperty('hls-bitrate', value);
      logger.d('PlayerScreen: HLS quality → $label (hls-bitrate=$value)');
    } catch (e) {
      logger.e('PlayerScreen: hls-bitrate set failed → $e');
    }
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_isPlaying) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) setState(() => _showControls = false);
    });
  }

  void _resetHide() {
    if (!_showControls) setState(() => _showControls = true);
    _scheduleHide();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _player.pause();
      setState(() => _showControls = true);
      _hideTimer?.cancel();
    } else {
      if (_isCompleted) {
        // libmpv stays at EOF after completion; seek to start before replaying.
        _player.seek(Duration.zero);
        setState(() => _isCompleted = false);
      }
      _player.play();
      _scheduleHide();
    }
  }

  void _seek(Duration offset) {
    // No seeking on livestreams or before duration is known
    if (_duration == Duration.zero) return;
    final t = _position + offset;
    final Duration target;
    if (t < Duration.zero) {
      target = Duration.zero;
    } else if (t > _duration) {
      target = _duration;
    } else {
      target = t;
    }
    _player.seek(target);
    _resetHide();
  }

  void _seekFraction(double fraction) {
    if (_duration == Duration.zero) return;
    _player.seek(
      Duration(milliseconds: (fraction * _duration.inMilliseconds).round()),
    );
  }

  void _setSpeed(double s) {
    setState(() => _playbackSpeed = s);
    _player.setRate(s);
    _resetHide();
  }

  void _setQuality(String label) {
    if (_isHlsStream && _hlsBitrateMap.isNotEmpty) {
      unawaited(_setHlsQuality(label));
    } else {
      final track = _qualityTrackMap[label];
      if (track != null) _player.setVideoTrack(track);
    }
    setState(() => _currentQuality = label);
    _resetHide();
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      _restorePortrait();
    }
    _resetHide();
  }

  void _restorePortrait() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // ── Analytics ──────────────────────────────────────────────────────────────

  void _trackPlayPause({required bool wasPlaying, required bool nowPlaying}) {
    final mid = widget.mediaId;
    final cid = widget.creatorId;
    if (mid == null || cid == null) return;
    final analytics = GetIt.instance<AnalyticsService>();
    final pos = _position.inMilliseconds / 1000.0;

    if (!_analyticsViewStarted && nowPlaying) {
      _analyticsViewStarted = true;
      analytics.trackViewStarted(
        mediaId: mid,
        creatorId: cid,
        source: widget.source,
        positionSeconds: pos,
      );
      return;
    }
    if (wasPlaying == nowPlaying) return;
    if (nowPlaying) {
      analytics.trackPlay(
        mediaId: mid,
        creatorId: cid,
        positionSeconds: pos,
        source: widget.source,
      );
    } else if (!_isCompleted) {
      analytics.trackPause(
        mediaId: mid,
        creatorId: cid,
        positionSeconds: pos,
        source: widget.source,
      );
    }
  }

  void _trackProgress(Duration position) {
    final mid = widget.mediaId;
    final cid = widget.creatorId;
    if (mid == null || cid == null || !_analyticsViewStarted || !_isPlaying) {
      return;
    }
    final pos = position.inMilliseconds / 1000.0;
    if ((pos - _lastProgressPos) >= 10.0) {
      _lastProgressPos = pos;
      GetIt.instance<AnalyticsService>().trackProgress(
        mediaId: mid,
        creatorId: cid,
        positionSeconds: pos,
        source: widget.source,
      );
    }
  }

  void _trackCompletion() {
    final mid = widget.mediaId;
    final cid = widget.creatorId;
    if (mid == null || cid == null || _analyticsCompleted) return;
    _analyticsCompleted = true;
    final analytics = GetIt.instance<AnalyticsService>();
    analytics.trackCompletion(
      mediaId: mid,
      creatorId: cid,
      positionSeconds: _position.inMilliseconds / 1000.0,
      source: widget.source,
    );
    analytics.flush();
  }

  // ── Keyboard ───────────────────────────────────────────────────────────────

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _togglePlay();
      case LogicalKeyboardKey.arrowLeft:
        _seek(const Duration(seconds: -5));
      case LogicalKeyboardKey.arrowRight:
        _seek(const Duration(seconds: 5));
      case LogicalKeyboardKey.arrowUp:
        _player.setVolume((_volume + 0.1).clamp(0.0, 1.0) * 100);
        _resetHide();
      case LogicalKeyboardKey.arrowDown:
        _player.setVolume((_volume - 0.1).clamp(0.0, 1.0) * 100);
        _resetHide();
      case LogicalKeyboardKey.keyF:
        _toggleFullscreen();
      case LogicalKeyboardKey.escape:
        if (_isFullscreen) {
          _toggleFullscreen();
        } else {
          Navigator.of(context).pop();
        }
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(backgroundColor: Colors.black, body: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_hasError && _isStreamInactive) return _buildStreamInactive();
    if (_hasError) return _buildError();
    if (!_isInitialized) return _buildLoading();
    return _buildPlayer();
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16.0),
          Text(
            _isRetrying
                ? 'Stream is starting… ($_retryCount/$_maxRetries)'
                : AppStrings.loadingVideo,
            style: AppStyles.loadingLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildStreamInactive() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_tethering_off_rounded,
            color: AppColors.primary,
            size: 56.0,
          ),
          const SizedBox(height: 16.0),
          Text(AppStrings.streamNotLive, style: AppStyles.errorTitle),
          const SizedBox(height: 8.0),
          Text(
            AppStrings.streamNotLiveDesc,
            style: AppStyles.errorPath,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24.0),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text(AppStrings.goBack),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 48.0,
          ),
          const SizedBox(height: 16.0),
          Text(AppStrings.failedToLoad, style: AppStyles.errorTitle),
          const SizedBox(height: 8.0),
          Text(_displayTitle, style: AppStyles.errorPath),
          const SizedBox(height: 24.0),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text(AppStrings.goBack),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      onDoubleTapDown: (d) {
        final halfW = MediaQuery.of(context).size.width / 2;
        _seek(
          d.localPosition.dx < halfW
              ? const Duration(seconds: -10)
              : const Duration(seconds: 10),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video — fills screen, BoxFit.contain keeps aspect ratio
          Video(
            controller: _videoController,
            controls: NoVideoControls,
            fit: BoxFit.contain,
          ),
          // Buffering spinner
          if (_isBuffering && !_isCompleted)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 2.5,
              ),
            ),
          // Controls overlay — IgnorePointer prevents hidden controls from
          // intercepting taps while faded out.
          IgnorePointer(
            ignoring: !_showControls,
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: ControlsOverlay(
                title: _displayTitle,
                isPlaying: _isPlaying,
                isCompleted: _isCompleted,
                position: _position,
                duration: _duration,
                volume: _volume,
                playbackSpeed: _playbackSpeed,
                isFullscreen: _isFullscreen,
                speeds: _speeds,
                qualities: _qualityLabels,
                currentQuality: _currentQuality,
                onBack: () => Navigator.of(context).pop(),
                onPlayPause: _togglePlay,
                onSeekBack: () => _seek(const Duration(seconds: -10)),
                onSeekForward: () => _seek(const Duration(seconds: 10)),
                onSeek: _seekFraction,
                onVolumeChanged: (v) {
                  _player.setVolume(v * 100);
                  _resetHide();
                },
                onSpeedChanged: _setSpeed,
                onQualityChanged: _setQuality,
                onFullscreenToggle: _toggleFullscreen,
                onProgressDragStart: () => _hideTimer?.cancel(),
                onProgressDragEnd: _resetHide,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
