import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/explore/views/widgets/card_bits.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount;
import 'package:test_app/models/explore_models/explore_models.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// A ministry to follow: a large ringed avatar with a follow badge hung off
/// its lower edge, over name, handle and subscriber count.
///
/// The ring colour carries the account kind — purple for an organisation,
/// cyan for a person — which is the only thing distinguishing the design's two
/// variants.
class ExploreCreatorCard extends StatelessWidget {
  const ExploreCreatorCard({
    super.key,
    required this.creator,
    this.onTap,
    this.onFollow,
  });


  final ExploreCreatorRef creator;
  final VoidCallback? onTap;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final ring = creator.isOrganisation
        ? AppColors.purple500
        : AppColors.cyan500;
    final innerRing = creator.isOrganisation
        ? AppColors.purple500
        : AppColors.cyan400;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // The design sizes these to their content (144-170 wide). A cap keeps
        // one long ministry name from stretching the card across the rail.
        constraints: BoxConstraints(minWidth: 144.s, maxWidth: 220.s),
        padding: EdgeInsets.all(12.s),
        decoration: BoxDecoration(
          color: AppColors.brandTertiary,
          borderRadius: BorderRadius.circular(8.s),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.overlayLight,
              offset: const Offset(0, 4),
              blurRadius: 6.s,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sized to hold the badge as well as the avatar. A Stack does
            // not hit-test children drawn outside its bounds, so hanging the
            // badge off the edge with a negative offset would have left it
            // visible but dead to touch.
            SizedBox(
              height: 69.s,
              width: 62.s,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 62.s,
                    height: 62.s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ring, width: 2.s),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(1.s),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: innerRing, width: 3.s),
                          color: AppColors.brandPrimary,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ExploreThumb(
                          asset: creator.avatarAsset,
                          url: creator.avatarUrl,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 53.s,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onFollow,
                        child: DesignIcon(
                          AppAssets.iconFeedPlusCircle,
                          width: 16.s,
                          height: 16.s,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 5, not 12: the badge already spends 7 of the design's gap by
            // hanging below the avatar, and the card has to come to 158.
            SizedBox(height: 5.s),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    creator.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.label(
                      14,
                      weight: AppStyles.bold,
                      lineHeight: 20 / 14,
                    ),
                  ),
                ),
                if (creator.verified) ...[
                  SizedBox(width: 4.s),
                  DesignIcon(
                    AppAssets.iconFeedVerified,
                    width: 14.s,
                    height: 14.s,
                  ),
                ],
              ],
            ),
            SizedBox(height: 4.s),
            Text(
              '@${creator.handle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyles.body(
                12,
                color: AppColors.neutral200,
                lineHeight: 16 / 12,
              ),
            ),
            SizedBox(height: 4.s),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DesignIcon(AppAssets.iconFeedUsers, width: 14.s, height: 14.s),
                SizedBox(width: 4.s),
                Text(
                  '${formatCount(creator.subscribers)} '
                  '${AppStrings.exploreSubscribers}',
                  style: AppStyles.body(12, color: AppColors.neutral400),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
