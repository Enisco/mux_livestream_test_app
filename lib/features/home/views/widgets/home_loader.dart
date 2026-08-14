import 'package:flutter/material.dart';

import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';

/// The branded first-load screen (Figma "Pre loader", `10638-86488`).
///
/// A bare spinner reads as a stall on a cold feed; the mark breathing keeps the
/// wait on-brand and shows the app is alive.
class HomeLoader extends StatefulWidget {
  const HomeLoader({super.key});

  @override
  State<HomeLoader> createState() => _HomeLoaderState();
}

class _HomeLoaderState extends State<HomeLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _pulse = Tween<double>(
    begin: 0.86,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.base1,
      child: Center(
        child: FadeTransition(
          opacity: _pulse,
          child: ScaleTransition(
            scale: _pulse,
            child: const GTubeLogoMark.plain(scale: 0.42),
          ),
        ),
      ),
    );
  }
}
