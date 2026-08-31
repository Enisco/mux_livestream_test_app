import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sizing/sizing.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/duration_format.dart';

/// The watching surface on a media detail — the video itself, with the full
/// set of controls the feed card deliberately withholds.
///
/// It is pinned by its parent so the rest of the page scrolls beneath it, which
/// is what keeps playback unbroken while the reader reads on. Nothing here
/// pushes a route to play, so arriving from a card continues mid-stream.
class VideoHero extends StatefulWidget {
  const VideoHero({
    super.key,
    required this.playback,
    required this.target,
    this.videoController,
    this.playbackUrl,
    this.thumbnailUrl,
    this.onBack,
  });

  final PlaybackHandle playback;
  final PlaybackTarget target;
  final VideoController? videoController;
  final String? playbackUrl;
  final String? thumbnailUrl;
  final VoidCallback? onBack;

  @override
  State<VideoHero> createState() => _VideoHeroState();
}

class _VideoHeroState extends State<VideoHero> {
  String get _mediaId => widget.target.mediaId;

  bool _showControls = true;
  Timer? _hide;
  bool _autoStarted = false;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
    _autoStart();
  }

  @override
  void didUpdateWidget(VideoHero old) {
    super.didUpdateWidget(old);
    // The URL arrives with the detail fetch, a beat after the screen opens.
    if (old.playbackUrl != widget.playbackUrl) _autoStart();
  }

  /// Opening a video means watching it, so it starts on arrival rather than
  /// asking for one more tap.
  ///
  /// A card that was already playing is left alone — [PlaybackController.play]
  /// would resume it anyway, but not touching it keeps the handover silent.
  void _autoStart() {
    if (_autoStarted) return;
    final url = widget.playbackUrl;
    if (url == null || url.isEmpty) return;
    _autoStarted = true;

    // Starting playback publishes new state synchronously, and this runs from
    // initState/didUpdateWidget — inside the build phase. Notifying listeners
    // there throws "setState() called during build", so it waits for the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.playback.isActive(_mediaId)) {
        if (!widget.playback.isPlaying(_mediaId)) widget.playback.resume();
        return;
      }
      widget.playback.play(
        target: widget.target,
        url: url,
        kind: PlaybackKind.video,
      );
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    // The visibility callback cannot help here — by the time it fires on
    // teardown this State is already unmounted.
    widget.playback.pauseIfActive(_mediaId);
    super.dispose();
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _togglePlay() {
    final url = widget.playbackUrl;
    if (widget.playback.isActive(_mediaId)) {
      widget.playback.togglePlayPause();
    } else if (url != null && url.isNotEmpty) {
      widget.playback.play(
        target: widget.target,
        url: url,
        kind: PlaybackKind.video,
      );
    }
    _scheduleHide();
  }

  void _openFullscreen() {
    _hide?.cancel();
    widget.playback.setFullscreen(true);
    Navigator.of(context)
        .push(
          PageRouteBuilder<void>(
            opaque: true,
            barrierColor: Colors.black,
            pageBuilder: (_, _, _) => FullscreenVideo(
              playback: widget.playback,
              mediaId: _mediaId,
              videoController: widget.videoController,
            ),
          ),
        )
        .whenComplete(() {
          widget.playback.setFullscreen(false);
          if (mounted) _scheduleHide();
        });
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video-hero-$_mediaId'),
      onVisibilityChanged: (info) {
        // Covered by another route, or gone from the tree: there is no longer a
        // surface showing this video, so it must not keep playing unseen.
        //
        // Fullscreen is the one cover that does not count — it is showing the
        // very same video, and pausing on the way into it would be absurd.
        if (!mounted || info.visibleFraction > 0) return;
        if (widget.playback.fullscreen.value) return;
        widget.playback.pauseIfActive(_mediaId);
      },
      child: _buildFrame(context),
    );
  }

  Widget _buildFrame(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: ValueListenableBuilder<PlaybackState>(
          valueListenable: widget.playback.state,
          builder: (context, state, _) {
            final active = state.isActive(_mediaId);
            return ValueListenableBuilder<bool>(
              valueListenable: widget.playback.fullscreen,
              builder: (context, fullscreen, _) => Stack(
                fit: StackFit.expand,
                children: [
                  // The fullscreen route holds the only allowed attachment
                  // while it is up, so the inline frame steps aside.
                  if (active && !fullscreen && widget.videoController != null)
                    Video(
                      controller: widget.videoController!,
                      controls: null,
                      fit: BoxFit.contain,
                    )
                  else
                    _HeroStill(url: widget.thumbnailUrl),

                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleControls,
                  ),

                  if (active && state.buffering && !state.playing)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                      ),
                    ),

                  AnimatedOpacity(
                    opacity: _showControls ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: _Controls(
                        playback: widget.playback,
                        state: state,
                        active: active,
                        onBack: widget.onBack,
                        onPlayPause: _togglePlay,
                        onFullscreen: _openFullscreen,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroStill extends StatelessWidget {
  const _HeroStill({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const ColoredBox(color: AppColors.surfaceVariant);
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const ColoredBox(color: AppColors.surfaceVariant),
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : const ColoredBox(color: Colors.black),
    );
  }
}

/// Back arrow, centre play, scrubber, clock, mute and fullscreen.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.playback,
    required this.state,
    required this.active,
    required this.onPlayPause,
    required this.onFullscreen,
    this.onBack,
    this.compact = false,
  });

  final PlaybackHandle playback;
  final PlaybackState state;
  final bool active;
  final VoidCallback onPlayPause;
  final VoidCallback onFullscreen;
  final VoidCallback? onBack;

  /// The fullscreen surface has no back arrow of its own — its close control
  /// is the same fullscreen button, toggled.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.35, 0.7, 1],
          colors: [
            Color(0x99000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xB3000000),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!compact)
            Positioned(
              left: 12.s,
              // Just inside the frame's corner. It used to add the status bar
              // height on top of this, from when the hero ran under the notch;
              // the screen now keeps the frame clear of system chrome, so
              // counting that inset here again pushed the arrow down into the
              // middle of the picture.
              top: 8.s,
              child: GTubeBackButton(onTap: onBack, size: 20, box: 32),
            ),
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPlayPause,
              child: Container(
                width: 56.s,
                height: 56.s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.55),
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(
                  state.isPlaying(state.mediaId ?? '') && active
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32.s,
                ),
              ),
            ),
          ),
          Positioned(
            left: 12.s,
            right: 12.s,
            bottom: 8.s,
            child: _BottomBar(
              playback: playback,
              state: state,
              active: active,
              onFullscreen: onFullscreen,
              fullscreenIcon: compact
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatefulWidget {
  const _BottomBar({
    required this.playback,
    required this.state,
    required this.active,
    required this.onFullscreen,
    required this.fullscreenIcon,
  });

  final PlaybackHandle playback;
  final PlaybackState state;
  final bool active;
  final VoidCallback onFullscreen;
  final IconData fullscreenIcon;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final total = widget.active
        ? widget.state.duration.inMilliseconds.toDouble()
        : 0.0;
    final position =
        _dragging ??
        widget.state.position.inMilliseconds.toDouble().clamp(
          0.0,
          total <= 0 ? 1.0 : total,
        );

    return Row(
      children: [
        Text(
          formatClock(
            _dragging == null
                ? (widget.active ? widget.state.position : Duration.zero)
                : Duration(milliseconds: _dragging!.round()),
          ),
          style: AppStyles.label(11, color: Colors.white),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2.5,
              activeTrackColor: AppColors.brandPrimary,
              inactiveTrackColor: Colors.white30,
              thumbColor: AppColors.brandPrimary,
              overlayColor: AppColors.brandPrimary.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              value: total <= 0 ? 0 : position.toDouble(),
              max: total <= 0 ? 1 : total,
              onChanged: total <= 0
                  ? null
                  : (v) => setState(() => _dragging = v),
              onChangeEnd: total <= 0
                  ? null
                  : (v) {
                      widget.playback.seek(Duration(milliseconds: v.round()));
                      setState(() => _dragging = null);
                    },
            ),
          ),
        ),
        Text(
          formatClock(widget.active ? widget.state.duration : Duration.zero),
          style: AppStyles.label(11, color: Colors.white),
        ),
        SizedBox(width: 4.s),
        ValueListenableBuilder<bool>(
          valueListenable: widget.playback.muted,
          builder: (context, muted, _) => _IconButton(
            icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            onTap: widget.playback.toggleMuted,
          ),
        ),
        _IconButton(icon: widget.fullscreenIcon, onTap: widget.onFullscreen),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      width: 34.s,
      height: 34.s,
      child: Icon(icon, color: Colors.white, size: 20.s),
    ),
  );
}

/// Landscape playback without touching the device orientation.
///
/// The app is portrait-locked on purpose, so instead of asking the system to
/// rotate, the video and its controls are turned a quarter turn inside a
/// full-bleed black page. The player never stops, so entering and leaving is
/// seamless.
class FullscreenVideo extends StatefulWidget {
  const FullscreenVideo({
    super.key,
    required this.playback,
    required this.mediaId,
    this.videoController,
  });

  final PlaybackHandle playback;
  final String mediaId;
  final VideoController? videoController;

  @override
  State<FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<FullscreenVideo> {
  @override
  void initState() {
    super.initState();
    // Nothing but the picture — the status and navigation bars would otherwise
    // sit across the rotated frame.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    final mediaId = widget.mediaId;
    final videoController = widget.videoController;
    return Scaffold(
      backgroundColor: Colors.black,
      body: RotatedBox(
        quarterTurns: 1,
        child: ValueListenableBuilder<PlaybackState>(
          valueListenable: playback.state,
          builder: (context, state, _) {
            final active = state.isActive(mediaId);
            return Stack(
              fit: StackFit.expand,
              children: [
                if (active && videoController != null)
                  Video(
                    controller: videoController,
                    controls: null,
                    fit: BoxFit.contain,
                  )
                else
                  const ColoredBox(color: Colors.black),
                _Controls(
                  playback: playback,
                  state: state,
                  active: active,
                  compact: true,
                  onPlayPause: playback.togglePlayPause,
                  onFullscreen: () => Navigator.of(context).maybePop(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
