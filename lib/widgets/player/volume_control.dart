import 'package:flutter/material.dart';

import '../../core/app_strings.dart';

class VolumeControl extends StatefulWidget {
  final double volume;
  final ValueChanged<double> onChanged;

  const VolumeControl({
    super.key,
    required this.volume,
    required this.onChanged,
  });

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  bool _expanded = false;

  IconData get _icon {
    if (widget.volume == 0) return Icons.volume_off_rounded;
    if (widget.volume < 0.4) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_icon, color: Colors.white),
          onPressed: () => setState(() => _expanded = !_expanded),
          tooltip: AppStrings.tooltipVolume,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _expanded ? _buildSlider() : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSlider() {
    return SizedBox(
      width: 90.0,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          activeTrackColor: Colors.white,
          inactiveTrackColor: Colors.white24,
          thumbColor: Colors.white,
          overlayColor: Colors.white24,
        ),
        child: Slider(value: widget.volume, onChanged: widget.onChanged),
      ),
    );
  }
}
