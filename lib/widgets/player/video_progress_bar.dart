import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_styles.dart';

class VideoProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const VideoProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  bool _dragging = false;
  double _dragValue = 0.0;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final dur = widget.duration;
    final displayed = _dragging
        ? Duration(milliseconds: (_dragValue * dur.inMilliseconds).round())
        : widget.position;
    final fraction = dur.inMilliseconds > 0
        ? (displayed.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(displayed), style: AppStyles.timeLabel),
              Text(_fmt(dur), style: AppStyles.timeLabelDim),
            ],
          ),
        ),
        const SizedBox(height: 2.0),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.0,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 7.0,
            ),
            overlayShape: const RoundSliderOverlayShape(
              overlayRadius: 16.0,
            ),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: Colors.white,
            overlayColor: AppColors.primary.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: _dragging ? _dragValue : fraction,
            onChangeStart: (v) {
              setState(() {
                _dragging = true;
                _dragValue = v;
              });
              widget.onDragStart?.call();
            },
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) {
              widget.onSeek(v);
              setState(() => _dragging = false);
              widget.onDragEnd?.call();
            },
          ),
        ),
      ],
    );
  }
}
