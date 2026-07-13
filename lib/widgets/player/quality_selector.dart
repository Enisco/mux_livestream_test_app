import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_styles.dart';

class QualitySelector extends StatelessWidget {
  final List<String> qualities;
  final String current;
  final ValueChanged<String> onSelected;

  const QualitySelector({
    super.key,
    required this.qualities,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (qualities.length <= 1) return const SizedBox.shrink();
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: AppColors.overlayLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      onPressed: () => _showMenu(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hd_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(current, style: AppStyles.speedLabel),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached) return;
    final box = ro;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - (qualities.length * 40.0),
        offset.dx + size.width,
        offset.dy,
      ),
      items: qualities.reversed
          .map(
            (q) => PopupMenuItem<String>(
              value: q,
              height: 40,
              child: Row(
                children: [
                  if (q == current)
                    const Icon(Icons.check_rounded, size: 16, color: AppColors.primary)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(
                    q,
                    style: AppStyles.speedMenuItem.copyWith(
                      color: q == current ? AppColors.primary : AppColors.textPrimary,
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
