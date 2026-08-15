import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';

/// The branded first-load screen (Figma "Pre loader", `10638-86488`).
///
/// The mark breathes inside a sweeping arc, so the wait reads as progress
/// rather than a stalled screen.
class HomeLoader extends StatefulWidget {
  const HomeLoader({super.key});

  @override
  State<HomeLoader> createState() => _HomeLoaderState();
}

class _HomeLoaderState extends State<HomeLoader> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  late final Animation<double> _pulse = Tween<double>(
    begin: 0.94,
    end: 1.06,
  ).animate(CurvedAnimation(parent: _breathe, curve: Curves.easeInOut));

  late final Animation<double> _glow = Tween<double>(
    begin: 0.18,
    end: 0.42,
  ).animate(CurvedAnimation(parent: _breathe, curve: Curves.easeInOut));

  @override
  void dispose() {
    _spin.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = 132.s;
    return ColoredBox(
      color: AppColors.base1,
      child: Center(
        child: SizedBox(
          width: ring,
          height: ring,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _breathe,
                builder: (_, _) => Container(
                  width: ring * 0.78,
                  height: ring * 0.78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandPrimary.withValues(
                          alpha: _glow.value,
                        ),
                        blurRadius: 42,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              RotationTransition(
                turns: _spin,
                child: CustomPaint(
                  size: Size(ring, ring),
                  painter: _ArcPainter(),
                ),
              ),
              ScaleTransition(
                scale: _pulse,
                child: const GTubeLogoMark.plain(scale: 1.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single brand-coloured arc that fades out along its tail.
class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          AppColors.brandPrimary.withValues(alpha: 0),
          AppColors.brandPrimary,
        ],
      ).createShader(rect);
    canvas.drawArc(
      rect.deflate(1.5),
      -math.pi / 2,
      math.pi * 1.35,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) => false;
}
