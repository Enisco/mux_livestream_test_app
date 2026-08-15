import 'package:flutter/cupertino.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';

abstract final class AppIcons {
  static const back = HugeIcons.strokeRoundedArrowLeft02;
  static const forward = HugeIcons.strokeRoundedArrowRight01;
  static const tick = HugeIcons.strokeRoundedTick02;
  static const tickCircle = HugeIcons.strokeRoundedCheckmarkCircle02;

  static const chevronDown = CupertinoIcons.chevron_down;
  static const chevronRight = CupertinoIcons.chevron_forward;
}

class GTubeBackButton extends StatelessWidget {
  const GTubeBackButton({
    super.key,
    this.onTap,
    this.color = AppColors.textPrimary,
    this.size = 18,
    this.box = 24,
  });

  final VoidCallback? onTap;
  final Color color;
  final double size;
  final double box;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: SizedBox(
        width: box,
        height: box,
        child: Center(
          child: HugeIcon(icon: AppIcons.back, color: color, size: size),
        ),
      ),
    );
  }
}
