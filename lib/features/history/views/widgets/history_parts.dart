import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// One part-watched item on the rail across the top of History.
class HistoryResumeCard extends StatelessWidget {
  const HistoryResumeCard({super.key, required this.item, this.onTap});

  static const double width = 235;

  final HistoryResumeItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width.s,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.s),
              child: SizedBox(
                height: 139.s,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.thumbnailAsset case final asset?)
                      Image.asset(asset, fit: BoxFit.cover)
                    else if (item.thumbnailUrl case final url?)
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: AppColors.base2),
                      )
                    else
                      const ColoredBox(color: AppColors.base2),
                    if (item.isAudio)
                      Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedMusicNote01,
                          color: AppColors.textPrimary,
                          size: 20.s,
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        height: 4.s,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ColoredBox(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: item.progress.clamp(0, 1),
                                child: const ColoredBox(
                                  color: AppColors.progressFill,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.s),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyles.label(13, weight: AppStyles.bold),
            ),
            SizedBox(height: 4.s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    item.creatorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.body(
                      12,
                      weight: AppStyles.regular,
                      color: AppColors.neutral200,
                      lineHeight: 16 / 12,
                    ),
                  ),
                ),
                if (item.creatorVerified) ...[
                  SizedBox(width: 4.s),
                  DesignIcon(
                    AppAssets.iconFeedVerified,
                    width: 14.s,
                    height: 14.s,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
