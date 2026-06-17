import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_styles.dart';

class SpeedSelector extends StatelessWidget {
  final double current;
  final List<double> speeds;
  final ValueChanged<double> onSelected;

  const SpeedSelector({
    super.key,
    required this.current,
    required this.speeds,
    required this.onSelected,
  });

  String _label(double s) =>
      s == s.truncateToDouble() ? '${s.toInt()}x' : '${s}x';

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: AppColors.overlayLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      onPressed: () => _showMenu(context),
      child: Text(_label(current), style: AppStyles.speedLabel),
    );
  }

  void _showMenu(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    showMenu<double>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - (speeds.length * 40.0),
        offset.dx + size.width,
        offset.dy,
      ),
      items: speeds.reversed
          .map(
            (s) => PopupMenuItem<double>(
              value: s,
              height: 40,
              child: Row(
                children: [
                  if (s == current)
                    const Icon(
                      Icons.check_rounded,
                      size: 16.0,
                      color: AppColors.primary,
                    )
                  else
                    const SizedBox(width: 16.0),
                  const SizedBox(width: 8.0),
                  Text(
                    _label(s),
                    style: AppStyles.speedMenuItem.copyWith(
                      color: s == current
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    ).then((v) {
      if (v != null) onSelected(v);
    });
  }
}
