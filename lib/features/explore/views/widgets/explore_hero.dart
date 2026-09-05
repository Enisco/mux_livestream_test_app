import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/explore/views/widgets/card_bits.dart';
import 'package:test_app/models/explore_models/explore_models.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The billboard at the top of Explore: one ministry, its pitch, and the two
/// things a reader can do about it.
///
/// The top inset is passed in rather than read here so the screen can keep the
/// artwork clear of the status bar and the search field that floats over it.
class ExploreHeroPanel extends StatelessWidget {
  const ExploreHeroPanel({
    super.key,
    required this.hero,
    required this.topInset,
    this.onWatch,
    this.onAddToPlaylist,
    this.onCreatorTap,
  });

  static const double height = 360;

  final ExploreHero hero;
  final double topInset;
  final VoidCallback? onWatch;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onCreatorTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.s)),
      child: SizedBox(
        height: height.s + topInset,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.base2),
            ExploreThumb(asset: hero.backdropAsset, url: hero.backdropUrl),
            // The lower half is darkened so the copy stays legible whatever
            // the artwork happens to be.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.overlayDark],
                  stops: [0.35, 1],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(19.s, 0, 19.s, 40.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onCreatorTap,
                    child: Row(
                      children: [
                        ExploreAvatar(creator: hero.creator, size: 16.s),
                        SizedBox(width: 6.s),
                        Flexible(
                          child: Text(
                            hero.creator.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyles.label(
                              12,
                              weight: AppStyles.bold,
                              color: AppColors.neutral300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.s),
                  Text(
                    hero.title,
                    style: AppStyles.heading(
                      24,
                      lineHeight: 32 / 24,
                      letterSpacing: -0.8,
                    ),
                  ),
                  SizedBox(height: 10.s),
                  Text(
                    hero.description,
                    style: AppStyles.body(
                      14,
                      color: AppColors.textPrimary,
                      lineHeight: 20 / 14,
                    ),
                  ),
                  SizedBox(height: 24.s),
                  Row(
                    children: [
                      Expanded(child: _WatchButton(onTap: onWatch)),
                      SizedBox(width: 10.s),
                      Expanded(child: _PlaylistButton(onTap: onAddToPlaylist)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchButton extends StatelessWidget {
  const _WatchButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.s),
        decoration: BoxDecoration(
          gradient: AppStyles.primaryButtonGradient,
          borderRadius: BorderRadius.circular(22.s),
          boxShadow: AppStyles.primaryButtonShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DesignIcon(AppAssets.iconPlay, width: 20.s, height: 20.s),
            SizedBox(width: 5.s),
            Text(
              AppStrings.exploreWatch,
              style: AppStyles.button(13),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistButton extends StatelessWidget {
  const _PlaylistButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 15.s),
        decoration: BoxDecoration(
          color: AppColors.buttonSecondaryActive.withValues(alpha: 0.29),
          borderRadius: BorderRadius.circular(38.s),
          border: Border.all(color: AppColors.neutral700, width: 1.5.s),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedPlayListAdd,
              color: AppColors.textPrimary,
              size: 20.s,
            ),
            SizedBox(width: 4.s),
            Flexible(
              child: Text(
                AppStrings.exploreAddToPlaylist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.button(13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tap target that opens search. It is a button, not a field — typing
/// happens on the search screen, which owns the query and its results.
class ExploreSearchBar extends StatelessWidget {
  const ExploreSearchBar({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 8.s),
        decoration: BoxDecoration(
          color: AppColors.fieldBg,
          borderRadius: BorderRadius.circular(18.s),
          border: Border.all(color: AppColors.neutral900, width: 2.s),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              color: AppColors.neutral300,
              size: 18.s,
            ),
            SizedBox(width: 5.s),
            Text(
              AppStrings.exploreSearchHint,
              style: AppStyles.label(
                12,
                color: AppColors.neutral300,
                lineHeight: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
