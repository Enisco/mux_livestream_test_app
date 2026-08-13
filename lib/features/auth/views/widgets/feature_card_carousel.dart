import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Looping welcome-screen carousel. Four cards share one 8s timeline, each
/// owning a quarter: fade+scale in over 3.75%, hold to 21.25%, out by 25%.
class FeatureCardCarousel extends StatefulWidget {
  const FeatureCardCarousel({super.key});

  static const designWidth = 290.0;
  static const designHeight = 240.0;

  @override
  State<FeatureCardCarousel> createState() => _FeatureCardCarouselState();
}

class _FeatureCardCarouselState extends State<FeatureCardCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  // Keyframe offsets within a single card's quarter of the timeline.
  static const _fadeIn = 0.0375;
  static const _holdEnd = 0.2125;
  static const _slot = 0.25;

  static const _easeIn = Cubic(0, 0, 0.3, 1);
  static const _fadeOut = Cubic(0.6, 0, 1, 1);
  static const _scaleOut = Cubic(0.5, 0, 0.5, 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Progress of [index]'s card through its own slot, or null when idle.
  double? _localTime(int index, double t) {
    final start = index * _slot;
    final local = t - start;
    if (local < 0 || local > _slot) return null;
    return local;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: FeatureCardCarousel.designWidth,
      height: FeatureCardCarousel.designHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            children: [
              for (var i = 0; i < _cards.length; i++)
                _buildCard(_cards[i], _localTime(i, t)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(_FeatureCardData data, double? local) {
    if (local == null) return const SizedBox.shrink();

    final double opacity;
    final double scale;
    if (local <= _fadeIn) {
      final p = _easeIn.transform((local / _fadeIn).clamp(0.0, 1.0));
      opacity = p;
      scale = 0.75 + (1 - 0.75) * p;
    } else if (local <= _holdEnd) {
      opacity = 1;
      scale = 1;
    } else {
      final raw = ((local - _holdEnd) / (_slot - _holdEnd)).clamp(0.0, 1.0);
      opacity = 1 - _fadeOut.transform(raw);
      scale = 1 - (1 - 0.5) * _scaleOut.transform(raw);
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: _FeatureCard(data)),
        ),
      ),
    );
  }
}

/// Converts a CSS `linear-gradient` angle (0deg = up, clockwise) into the
/// begin/end alignment pair Flutter expects.
({Alignment begin, Alignment end}) _gradientAxis(double degrees) {
  final radians = degrees * math.pi / 180;
  final x = math.sin(radians);
  final y = -math.cos(radians);
  return (begin: Alignment(-x, -y), end: Alignment(x, y));
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard(this.data);

  final _FeatureCardData data;

  @override
  Widget build(BuildContext context) {
    final axis = _gradientAxis(data.gradientAngle);
    return Stack(
      children: [
        Positioned(
          left: data.cardCenter.dx - data.size.width / 2,
          top: data.cardCenter.dy - data.size.height / 2,
          child: Transform.rotate(
            angle: data.rotation * math.pi / 180,
            child: Container(
              width: data.size.width,
              height: data.size.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(data.radius),
                gradient: LinearGradient(
                  begin: axis.begin,
                  end: axis.end,
                  colors: [data.gradientFrom, data.gradientTo],
                  stops: const [0.0, 0.70711],
                ),
              ),
              child: data.content,
            ),
          ),
        ),
        Positioned(
          left: data.captionCenter.dx - data.captionWidth / 2,
          top: data.captionCenter.dy - _captionHeight / 2,
          width: data.captionWidth,
          height: _captionHeight,
          child: Transform.rotate(
            angle: data.captionRotation * math.pi / 180,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                data.caption,
                style: AppStyles.caption(
                  11.043,
                  family: AppStyles.featureFont,
                  color: AppColors.neutral200,
                  weight: AppStyles.medium,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static const _captionHeight = 20.0;
}

class _FeatureCardData {
  const _FeatureCardData({
    required this.size,
    required this.radius,
    required this.rotation,
    required this.gradientAngle,
    required this.gradientFrom,
    required this.gradientTo,
    required this.cardCenter,
    required this.caption,
    required this.captionCenter,
    required this.captionWidth,
    required this.captionRotation,
    required this.content,
  });

  final Size size;
  final double radius;
  final double rotation;
  final double gradientAngle;
  final Color gradientFrom;
  final Color gradientTo;
  final Offset cardCenter;
  final String caption;
  final Offset captionCenter;
  final double captionWidth;
  final double captionRotation;
  final Widget content;
}

Widget _centredGlyph(String asset, double size, double padding) => Padding(
  padding: EdgeInsets.all(padding),
  child: Center(
    child: SvgPicture.asset(asset, width: size, height: size),
  ),
);

final _cards = <_FeatureCardData>[
  // Purple — The Audio Bible
  _FeatureCardData(
    size: const Size(262.176, 166.154),
    radius: 24.615,
    rotation: -10,
    gradientAngle: 147.63555,
    gradientFrom: AppColors.cardPurpleFrom,
    gradientTo: AppColors.cardPurpleTo,
    cardCenter: const Offset(145.00, 109.72),
    caption: AppStrings.featureAudioBible,
    captionCenter: const Offset(163.50, 213.08),
    captionWidth: 250.05,
    captionRotation: -7.04,
    content: _centredGlyph(AppAssets.iconPlay, 36.923, 24.615),
  ),
  // Red — live Sunday service
  _FeatureCardData(
    size: Size(262, 174.179),
    radius: 25.335,
    rotation: 6,
    gradientAngle: 146.38389,
    gradientFrom: AppColors.cardRedFrom,
    gradientTo: AppColors.cardRedTo,
    cardCenter: Offset(144.99, 106.97),
    caption: AppStrings.featureLiveService,
    captionCenter: Offset(144.99, 211.80),
    captionWidth: 278.771,
    captionRotation: 6,
    content: Stack(
      children: [
        _centredGlyph(AppAssets.iconCast, 38.003, 22.168),
        Positioned(left: 22.17, top: 22.17, child: _LiveBadge()),
      ],
    ),
  ),
  // Olive — daily devotional pull-quote
  _FeatureCardData(
    size: Size(262, 177.382),
    radius: 25.34,
    rotation: 4,
    gradientAngle: 145.90073,
    gradientFrom: AppColors.cardOliveFrom,
    gradientTo: AppColors.cardOliveTo,
    cardCenter: Offset(145.00, 103.97),
    caption: AppStrings.featureDevotional,
    captionCenter: Offset(145.00, 217.62),
    captionWidth: 273.735,
    captionRotation: 4,
    content: Stack(
      children: [
        Padding(
          padding: EdgeInsets.all(19.005),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.featureVerse,
                style: AppStyles.body(
                  17.421,
                  family: AppStyles.featureFont,
                  color: AppColors.textPrimary,
                  lineHeight: 1.25,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 19.005,
          top: 19.005,
          child: SvgPicture.asset(
            AppAssets.iconBookOpen,
            width: 25.34,
            height: 25.34,
          ),
        ),
      ],
    ),
  ),
  // Green — worship at midnight
  _FeatureCardData(
    size: const Size(262, 172.069),
    radius: 25.492,
    rotation: -6,
    gradientAngle: 146.70498,
    gradientFrom: AppColors.cardGreenFrom,
    gradientTo: AppColors.cardGreenTo,
    cardCenter: const Offset(145.00, 100.29),
    caption: AppStrings.featureWorship,
    captionCenter: const Offset(157.50, 219.26),
    captionWidth: 253.551,
    captionRotation: -6,
    content: _centredGlyph(AppAssets.iconHeadphones, 38.238, 25.492),
  ),
];

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.668, vertical: 3.167),
      decoration: BoxDecoration(
        color: AppColors.liveBadge,
        borderRadius: BorderRadius.circular(158.344),
      ),
      child: Text(
        AppStrings.liveBadge,
        style: AppStyles.overline(15.834, family: AppStyles.featureFont),
      ),
    );
  }
}
