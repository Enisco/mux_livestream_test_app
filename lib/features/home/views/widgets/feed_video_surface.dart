import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sizing/sizing.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:test_app/features/home/data/feed_autoplay_coordinator.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';

/// A feed card's video area: thumbnail until the card earns playback, then the
/// shared player in the same frame.
///
/// The mute button is deliberately the only thing here that reacts to a touch.
/// Everything else falls through to the card, so a tap opens the detail and the
/// video carries on from where it had reached.
class FeedVideoSurface extends StatefulWidget {
  const FeedVideoSurface({
    super.key,
    required this.target,
    required this.child,
    this.playback,
    this.coordinator,
    this.videoController,
  });

  final PlaybackTarget target;

  /// The thumbnail, shown until this card is the one playing.
  final Widget child;

  final PlaybackHandle? playback;
  final FeedAutoplayCoordinator? coordinator;

  /// Only the real controller can render frames; left null in tests and in
  /// surfaces that show cards without playing them.
  final VideoController? videoController;

  @override
  State<FeedVideoSurface> createState() => _FeedVideoSurfaceState();
}

class _FeedVideoSurfaceState extends State<FeedVideoSurface> {
  String get _mediaId => widget.target.mediaId;

  @override
  void dispose() {
    // The card is leaving the tree; it must not keep a claim on the viewport.
    widget.coordinator?.remove(_mediaId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    final coordinator = widget.coordinator;

    // Without a coordinator this surface never autoplays, so it must not show
    // a live frame or a mute toggle it cannot act on — search results and
    // "Up next" rows are stills that open on tap.
    if (playback == null || coordinator == null) return widget.child;

    return VisibilityDetector(
      key: Key('feed-video-$_mediaId'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        coordinator.report(widget.target, info.visibleFraction);
      },
      child: ValueListenableBuilder<PlaybackState>(
        valueListenable: playback.state,
        builder: (context, state, thumbnail) {
          final active =
              state.isActive(_mediaId) && state.kind == PlaybackKind.video;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (active && widget.videoController != null)
                Video(
                  controller: widget.videoController!,
                  controls: null,
                  fit: BoxFit.cover,
                  // The thumbnail stays behind the frame so the swap has
                  // nothing black to show through while the first frame lands.
                  filterQuality: FilterQuality.medium,
                )
              else
                thumbnail!,
              if (active)
                Positioned(
                  right: 8.s,
                  bottom: 8.s,
                  child: _MuteButton(playback: playback),
                ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Toggles the app-wide mute. Every video surface reads the same flag, so
/// unmuting here keeps the next card audible too.
class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.playback});

  final PlaybackHandle playback;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: playback.muted,
      builder: (context, muted, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: playback.toggleMuted,
        child: Container(
          width: 32.s,
          height: 32.s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.55),
          ),
          child: Icon(
            muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: AppColors.textPrimary,
            size: 18.s,
          ),
        ),
      ),
    );
  }
}
