import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final bool isCompleted;
  final VoidCallback onTap;

  const PlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.isCompleted,
    required this.onTap,
  });

  IconData get _icon {
    if (isCompleted) return Icons.replay_rounded;
    if (isPlaying) return Icons.pause_rounded;
    return Icons.play_arrow_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68.0,
        height: 68.0,
        decoration: BoxDecoration(
          color: AppColors.overlayMid,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Icon(_icon, color: Colors.white, size: 32.0),
      ),
    );
  }
}
