import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/duration_format.dart';

/// The listening surface for a track — artwork, transport and scrubber.
///
/// An audio detail must not borrow the video layout: there is nothing to watch,
/// so the space goes to the artwork and the controls instead of a 16:9 frame.
/// Playback lives in the shared controller, so arriving here while the track is
/// already playing simply picks it up mid-stream.
class AudioHero extends StatelessWidget {
  const AudioHero({
    super.key,
    required this.playback,
    required this.target,
    required this.title,
    this.creatorName,
    this.artworkUrl,
    this.playbackUrl,
  });

  final PlaybackHandle playback;
  final PlaybackTarget target;
  final String title;
  final String? creatorName;
  final String? artworkUrl;
  final String? playbackUrl;

  String get mediaId => target.mediaId;

  @override
  Widget build(BuildContext context) {
    final art = artworkUrl;
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.base1),
      child: Stack(
        children: [
          // The artwork, blurred, doubles as the backdrop so the screen takes
          // its colour from the track rather than sitting on flat black.
          if (art != null && art.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Opacity(
                  opacity: 0.45,
                  child: Image.network(
                    art,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x800D0D0D), AppColors.base1],
                ),
              ),
            ),
          ),
          Padding(
            // No status-bar inset here: the screen holds this hero clear of
            // system chrome, so adding it again pushed the whole layout —
            // back arrow, artwork, title — a notch's height down the screen.
            padding: EdgeInsets.fromLTRB(20.s, 12.s, 20.s, 24.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GTubeBackButton(size: 20, box: 32),
                ),
                SizedBox(height: 12.s),
                Center(child: _Artwork(url: art)),
                SizedBox(height: 24.s),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.heading(18, lineHeight: 24 / 18),
                ),
                if (creatorName case final name? when name.isNotEmpty) ...[
                  SizedBox(height: 6.s),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.label(13, color: AppColors.neutral400),
                  ),
                ],
                SizedBox(height: 20.s),
                ValueListenableBuilder<PlaybackState>(
                  valueListenable: playback.state,
                  builder: (context, state, _) {
                    final active = state.isActive(mediaId);
                    return Column(
                      children: [
                        _Scrubber(
                          position: active ? state.position : Duration.zero,
                          duration: active ? state.duration : Duration.zero,
                          onSeek: active ? playback.seek : null,
                        ),
                        SizedBox(height: 12.s),
                        _Transport(
                          playing: state.isPlaying(mediaId),
                          buffering:
                              active && state.buffering && !state.playing,
                          enabled: playbackUrl?.isNotEmpty == true,
                          onPlayPause: _togglePlay,
                          onSkip: active
                              ? (by) => playback.seek(_clamped(state, by))
                              : null,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Duration _clamped(PlaybackState state, Duration by) {
    final target = state.position + by;
    if (target < Duration.zero) return Duration.zero;
    if (state.duration > Duration.zero && target > state.duration) {
      return state.duration;
    }
    return target;
  }

  void _togglePlay() {
    final url = playbackUrl;
    if (url == null || url.isEmpty) return;
    // `play` resumes when this track is already loaded, so a listener arriving
    // mid-stream never restarts it from the top.
    if (playback.isPlaying(mediaId)) {
      playback.pause();
    } else {
      playback.play(target: target, url: url, kind: PlaybackKind.audio);
    }
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final side = 220.s;
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.s),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF64618E), Color(0xFF2A2754)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url!.isEmpty
          ? Icon(
              Icons.music_note_rounded,
              size: 72.s,
              color: AppColors.textPrimary,
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.music_note_rounded,
                size: 72.s,
                color: AppColors.textPrimary,
              ),
            ),
    );
  }
}

/// Seek bar with the drag held locally, so the thumb follows the finger
/// instead of snapping back to the last position tick.
class _Scrubber extends StatefulWidget {
  const _Scrubber({
    required this.position,
    required this.duration,
    this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final void Function(Duration)? onSeek;

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds.toDouble();
    final value =
        _dragging ??
        widget.position.inMilliseconds.toDouble().clamp(
          0,
          total <= 0 ? 1 : total,
        );

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            activeTrackColor: AppColors.brandPrimary,
            inactiveTrackColor: AppColors.neutral700,
            thumbColor: AppColors.brandPrimary,
            overlayColor: AppColors.brandPrimary.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: total <= 0 ? 0 : value.toDouble(),
            max: total <= 0 ? 1 : total,
            onChanged: widget.onSeek == null || total <= 0
                ? null
                : (v) => setState(() => _dragging = v),
            onChangeEnd: widget.onSeek == null
                ? null
                : (v) {
                    widget.onSeek!(Duration(milliseconds: v.round()));
                    setState(() => _dragging = null);
                  },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatClock(
                  _dragging == null
                      ? widget.position
                      : Duration(milliseconds: _dragging!.round()),
                ),
                style: AppStyles.label(11, color: AppColors.neutral400),
              ),
              Text(
                formatClock(widget.duration),
                style: AppStyles.label(11, color: AppColors.neutral400),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({
    required this.playing,
    required this.buffering,
    required this.enabled,
    required this.onPlayPause,
    this.onSkip,
  });

  final bool playing;
  final bool buffering;
  final bool enabled;
  final VoidCallback onPlayPause;
  final void Function(Duration)? onSkip;

  static const _skip = Duration(seconds: 15);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SkipButton(
          icon: HugeIcons.strokeRoundedGoBackward15Sec,
          onTap: onSkip == null ? null : () => onSkip!(-_skip),
        ),
        SizedBox(width: 28.s),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onPlayPause : null,
          child: Container(
            width: 64.s,
            height: 64.s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? AppColors.brandPrimary : AppColors.neutral700,
            ),
            child: buffering
                ? Padding(
                    padding: EdgeInsets.all(20.s),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.textPrimary,
                    ),
                  )
                : Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppColors.textPrimary,
                    size: 34.s,
                  ),
          ),
        ),
        SizedBox(width: 28.s),
        _SkipButton(
          icon: HugeIcons.strokeRoundedGoForward15Sec,
          onTap: onSkip == null ? null : () => onSkip!(_skip),
        ),
      ],
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.icon, this.onTap});

  final List<List<dynamic>> icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44.s,
        height: 44.s,
        child: Center(
          child: HugeIcon(
            icon: icon,
            color: onTap == null ? AppColors.neutral700 : AppColors.textPrimary,
            size: 26,
          ),
        ),
      ),
    );
  }
}
