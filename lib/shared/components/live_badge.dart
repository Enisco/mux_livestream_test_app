import 'package:flutter/widgets.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The red "LIVE" pill a viewer already knows from the live card on the
/// home feed.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.fontSize = cardFontSize});

  /// What the feed card draws, and the size the proportions came from.
  static const cardFontSize = 5.924;

  /// Legible beside a title or inside a player's controls.
  static const readingFontSize = 11.0;

  final double fontSize;

  double get _scale => fontSize / cardFontSize;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('live-badge'),
    padding: EdgeInsets.symmetric(
      horizontal: (7.109 * _scale).s,
      vertical: (1.777 * _scale).s,
    ),
    decoration: BoxDecoration(
      color: AppColors.livePillFill,
      borderRadius: BorderRadius.circular((10.663 * _scale).s),
      border: Border.all(color: AppColors.red500, width: (1.185 * _scale).s),
    ),
    child: Text(
      AppStrings.liveBadge,
      style: AppStyles.label(
        fontSize,
        weight: AppStyles.bold,
        lineHeight: 9.478 / 5.924,
      ),
    ),
  );
}
