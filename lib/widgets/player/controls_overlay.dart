import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../core/app_styles.dart';
import 'play_pause_button.dart';
import 'quality_selector.dart';
import 'seek_button.dart';
import 'speed_selector.dart';
import 'video_progress_bar.dart';
import 'volume_control.dart';

class ControlsOverlay extends StatelessWidget {
  final String title;
  final bool isPlaying;
  final bool isCompleted;
  final Duration position;
  final Duration duration;
  final double volume;
  final double playbackSpeed;
  final bool isFullscreen;
  final List<double> speeds;
  final List<String> qualities;
  final String currentQuality;

  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<String> onQualityChanged;
  final VoidCallback onFullscreenToggle;
  final VoidCallback? onProgressDragStart;
  final VoidCallback? onProgressDragEnd;

  const ControlsOverlay({
    super.key,
    required this.title,
    required this.isPlaying,
    required this.isCompleted,
    required this.position,
    required this.duration,
    required this.volume,
    required this.playbackSpeed,
    required this.isFullscreen,
    required this.speeds,
    required this.qualities,
    required this.currentQuality,
    required this.onBack,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onSeek,
    required this.onVolumeChanged,
    required this.onSpeedChanged,
    required this.onQualityChanged,
    required this.onFullscreenToggle,
    this.onProgressDragStart,
    this.onProgressDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.25, 0.70, 1.0],
          colors: [
            AppColors.overlayDark,
            Colors.transparent,
            Colors.transparent,
            AppColors.overlayDark,
          ],
        ),
      ),
      child: Column(
        children: [
          _TopBar(title: title, onBack: onBack),
          const Spacer(),
          _CenterControls(
            isPlaying: isPlaying,
            isCompleted: isCompleted,
            onPlayPause: onPlayPause,
            onSeekBack: onSeekBack,
            onSeekForward: onSeekForward,
          ),
          const Spacer(),
          _BottomBar(
            position: position,
            duration: duration,
            volume: volume,
            playbackSpeed: playbackSpeed,
            isFullscreen: isFullscreen,
            speeds: speeds,
            qualities: qualities,
            currentQuality: currentQuality,
            onSeek: onSeek,
            onVolumeChanged: onVolumeChanged,
            onSpeedChanged: onSpeedChanged,
            onQualityChanged: onQualityChanged,
            onFullscreenToggle: onFullscreenToggle,
            onProgressDragStart: onProgressDragStart,
            onProgressDragEnd: onProgressDragEnd,
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _TopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20.0,
              ),
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                title,
                style: AppStyles.playerTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 48.0),
          ],
        ),
      ),
    );
  }
}

class _CenterControls extends StatelessWidget {
  final bool isPlaying;
  final bool isCompleted;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;

  const _CenterControls({
    required this.isPlaying,
    required this.isCompleted,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SeekButton(icon: Icons.replay_10_rounded, onTap: onSeekBack),
        const SizedBox(width: 32.0),
        PlayPauseButton(
          isPlaying: isPlaying,
          isCompleted: isCompleted,
          onTap: onPlayPause,
        ),
        const SizedBox(width: 32.0),
        SeekButton(icon: Icons.forward_10_rounded, onTap: onSeekForward),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final double volume;
  final double playbackSpeed;
  final bool isFullscreen;
  final List<double> speeds;
  final List<String> qualities;
  final String currentQuality;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<String> onQualityChanged;
  final VoidCallback onFullscreenToggle;
  final VoidCallback? onProgressDragStart;
  final VoidCallback? onProgressDragEnd;

  const _BottomBar({
    required this.position,
    required this.duration,
    required this.volume,
    required this.playbackSpeed,
    required this.isFullscreen,
    required this.speeds,
    required this.qualities,
    required this.currentQuality,
    required this.onSeek,
    required this.onVolumeChanged,
    required this.onSpeedChanged,
    required this.onQualityChanged,
    required this.onFullscreenToggle,
    this.onProgressDragStart,
    this.onProgressDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VideoProgressBar(
              position: position,
              duration: duration,
              onSeek: onSeek,
              onDragStart: onProgressDragStart,
              onDragEnd: onProgressDragEnd,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  VolumeControl(volume: volume, onChanged: onVolumeChanged),
                  const Spacer(),
                  QualitySelector(
                    qualities: qualities,
                    current: currentQuality,
                    onSelected: onQualityChanged,
                  ),
                  const SizedBox(width: 8.0),
                  SpeedSelector(
                    current: playbackSpeed,
                    speeds: speeds,
                    onSelected: onSpeedChanged,
                  ),
                  const SizedBox(width: 4.0),
                  IconButton(
                    icon: Icon(
                      isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: Colors.white,
                    ),
                    onPressed: onFullscreenToggle,
                    tooltip: isFullscreen
                        ? AppStrings.tooltipExitFullscreen
                        : AppStrings.tooltipFullscreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
