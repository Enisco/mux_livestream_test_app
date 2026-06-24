import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import '../core/app_styles.dart';
import '../widgets/player/controls_overlay.dart';

class PlayerScreen extends StatefulWidget {
  final String? filePath;
  final String? networkUrl;

  const PlayerScreen.file({super.key, required this.filePath})
    : networkUrl = null;

  const PlayerScreen.network({super.key, required this.networkUrl})
    : filePath = null;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isFullscreen = false;
  double _playbackSpeed = 1.0;

  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  String get _displayTitle {
    if (widget.networkUrl != null) {
      final segments = Uri.tryParse(
        widget.networkUrl!,
      )?.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments != null && segments.isNotEmpty) return segments.last;
      return widget.networkUrl!;
    }
    return widget.filePath!.split(Platform.pathSeparator).last;
  }

  Future<void> _initPlayer() async {
    try {
      final VideoPlayerController ctrl;
      if (widget.networkUrl != null) {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.networkUrl!));
      } else if (widget.filePath!.startsWith('content://')) {
        ctrl = VideoPlayerController.contentUri(Uri.parse(widget.filePath!));
      } else {
        ctrl = VideoPlayerController.file(File(widget.filePath!));
      }
      await ctrl.initialize();
      ctrl.addListener(_onUpdate);
      _controller = ctrl;
      setState(() => _isInitialized = true);
      ctrl.play();
      _scheduleHide();
    } catch (_) {
      setState(() => _hasError = true);
    }
  }

  void _onUpdate() {
    if (!mounted) return;
    setState(() {});
    if (_controller!.value.isCompleted) {
      setState(() => _showControls = true);
      _hideTimer?.cancel();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_controller?.value.isPlaying != true) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() => _showControls = false);
      }
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
    final ctrl = _controller;
    if (ctrl == null) return;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
      setState(() => _showControls = true);
      _hideTimer?.cancel();
    } else {
      ctrl.play();
      _scheduleHide();
    }
  }

  void _seek(Duration offset) {
    final ctrl = _controller;
    if (ctrl == null) return;
    final target = ctrl.value.position + offset;
    final dur = ctrl.value.duration;
    ctrl.seekTo(
      target < Duration.zero
          ? Duration.zero
          : target > dur
          ? dur
          : target,
    );
    _resetHide();
  }

  void _seekFraction(double fraction) {
    final ctrl = _controller;
    if (ctrl == null) return;
    ctrl.seekTo(
      Duration(
        milliseconds: (fraction * ctrl.value.duration.inMilliseconds).round(),
      ),
    );
  }

  void _setSpeed(double s) {
    setState(() => _playbackSpeed = s);
    _controller?.setPlaybackSpeed(s);
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
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    _resetHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_onUpdate);
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

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
        final v = ((_controller?.value.volume ?? 0) + 0.1).clamp(0.0, 1.0);
        _controller?.setVolume(v);
        _resetHide();
      case LogicalKeyboardKey.arrowDown:
        final v = ((_controller?.value.volume ?? 0) - 0.1).clamp(0.0, 1.0);
        _controller?.setVolume(v);
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

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(backgroundColor: Colors.black, body: _buildBody()),
    );
  }

  Widget _buildBody() {
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
          Text(AppStrings.loadingVideo, style: AppStyles.loadingLabel),
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
    final ctrl = _controller!;
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
          Container(color: Colors.black),
          Center(
            child: AspectRatio(
              aspectRatio: ctrl.value.aspectRatio,
              child: VideoPlayer(ctrl),
            ),
          ),
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: ControlsOverlay(
              title: _displayTitle,
              isPlaying: ctrl.value.isPlaying,
              isCompleted: ctrl.value.isCompleted,
              position: ctrl.value.position,
              duration: ctrl.value.duration,
              volume: ctrl.value.volume,
              playbackSpeed: _playbackSpeed,
              isFullscreen: _isFullscreen,
              speeds: _speeds,
              onBack: () => Navigator.of(context).pop(),
              onPlayPause: _togglePlay,
              onSeekBack: () => _seek(const Duration(seconds: -10)),
              onSeekForward: () => _seek(const Duration(seconds: 10)),
              onSeek: _seekFraction,
              onVolumeChanged: (v) {
                ctrl.setVolume(v);
                _resetHide();
              },
              onSpeedChanged: _setSpeed,
              onFullscreenToggle: _toggleFullscreen,
              onProgressDragStart: () => _hideTimer?.cancel(),
              onProgressDragEnd: _resetHide,
            ),
          ),
        ],
      ),
    );
  }
}
