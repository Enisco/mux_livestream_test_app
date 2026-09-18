import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/models/explore_models/explore_models.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The small parts every Explore rail repeats.
///
/// They are shared rather than copied because the design draws them
/// identically on eight different cards — a change to the creator line or the
/// sponsored marker should land everywhere at once.

/// Artwork, from a bundled placeholder or the network, whichever the row has.
class ExploreThumb extends StatelessWidget {
  const ExploreThumb({
    super.key,
    this.asset,
    this.url,
    this.fit = BoxFit.cover,
  });

  final String? asset;
  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (asset != null) {
      return Image.asset(asset!, fit: fit, width: double.infinity);
    }
    if (url != null && url!.isNotEmpty) {
      return Image.network(
        url!,
        fit: fit,
        width: double.infinity,
        errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.base2),
      );
    }
    return const ColoredBox(color: AppColors.base2);
  }
}

/// The ringed circle a creator is represented by throughout Explore.
class ExploreAvatar extends StatelessWidget {
  const ExploreAvatar({
    super.key,
    required this.creator,
    required this.size,
    this.ringWidth,
    this.ringColor,
  });

  final ExploreCreatorRef creator;
  final double size;
  final double? ringWidth;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandPrimary,
        border: Border.all(
          color: ringColor ?? AppColors.purple400,
          width: ringWidth ?? size / 16,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExploreThumb(asset: creator.avatarAsset, url: creator.avatarUrl),
    );
  }
}

/// Avatar, name and verification tick — the line under a card's title.
class ExploreCreatorLine extends StatelessWidget {
  const ExploreCreatorLine({
    super.key,
    required this.creator,
    this.showAvatar = true,
  });

  final ExploreCreatorRef creator;

  /// "Continue watching" prints the name alone; every other rail leads with
  /// the avatar.
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showAvatar) ...[
          ExploreAvatar(creator: creator, size: 14.s),
          SizedBox(width: 4.s),
        ],
        Flexible(
          child: Text(
            creator.name,
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
        if (creator.verified) ...[
          SizedBox(width: 4.s),
          DesignIcon(AppAssets.iconFeedVerified, width: 14.s, height: 14.s),
        ],
      ],
    );
  }
}

/// The promoted marker. Sits under the card rather than on the artwork so it
/// cannot be mistaken for part of the picture.
class ExploreSponsoredTag extends StatelessWidget {
  const ExploreSponsoredTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesignIcon(AppAssets.iconFeedLoudspeaker, width: 12.s, height: 12.s),
        SizedBox(width: 2.s),
        Text(
          AppStrings.exploreSponsored,
          style: AppStyles.label(
            10,
            weight: AppStyles.black,
            color: AppColors.brandPrimary,
            lineHeight: 16 / 10,
          ),
        ),
      ],
    );
  }
}

/// Runtime, series length or reading time, bottom-right on the artwork.
class ExploreBadge extends StatelessWidget {
  const ExploreBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.s, vertical: 2.s),
      decoration: BoxDecoration(
        color: AppColors.overlayDark,
        borderRadius: BorderRadius.circular(4.s),
      ),
      child: Text(
        label,
        style: AppStyles.label(
          9,
          family: AppStyles.featureFont,
          weight: AppStyles.semiBold,
        ),
      ),
    );
  }
}

/// The red LIVE flag, which replaces the badge on a live rail.
class ExploreLiveFlag extends StatelessWidget {
  const ExploreLiveFlag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.s, vertical: 2.s),
      decoration: BoxDecoration(
        color: AppColors.liveBadge,
        borderRadius: BorderRadius.circular(4.s),
      ),
      child: Text(
        AppStrings.exploreLiveBadge,
        style: AppStyles.label(
          9,
          family: AppStyles.featureFont,
          weight: AppStyles.bold,
        ),
      ),
    );
  }
}

/// Title over creator line, the block under every card's artwork.
class ExploreCardMeta extends StatelessWidget {
  const ExploreCardMeta({
    super.key,
    required this.card,
    this.showAvatar = true,
  });

  final ExploreCard card;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppStyles.label(13, weight: AppStyles.bold),
        ),
        SizedBox(height: 4.s),
        ExploreCreatorLine(creator: card.creator, showAvatar: showAvatar),
      ],
    );
  }
}
