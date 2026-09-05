import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/explore/views/widgets/card_bits.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/models/explore_models/explore_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// A card on the Live rail: a red-ringed still with a LIVE flag on it.
class ExploreLiveCard extends StatelessWidget {
  const ExploreLiveCard({super.key, required this.card, this.onTap});

  static const double width = 213;

  final ExploreCard card;
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
            Container(
              height: 130.s,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.s),
                border: Border.all(color: AppColors.liveBadge, width: 2.s),
                // The design's glow is two stacked shadows at the same colour;
                // a live card is meant to read as lit from behind.
                boxShadow: [
                  BoxShadow(color: AppColors.liveBadge, blurRadius: 12.s),
                  BoxShadow(color: AppColors.liveBadge, blurRadius: 6.s),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.s),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ExploreThumb(
                      asset: card.thumbnailAsset,
                      url: card.thumbnailUrl,
                    ),
                    Positioned(
                      right: 2.s,
                      bottom: 2.s,
                      child: const ExploreLiveFlag(),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.s),
            SizedBox(width: 149.s, child: ExploreCardMeta(card: card)),
          ],
        ),
      ),
    );
  }
}

/// A part-watched poster, with how far the viewer got along its bottom edge.
class ExploreContinueCard extends StatelessWidget {
  const ExploreContinueCard({super.key, required this.card, this.onTap});

  static const double width = 213;

  final ExploreCard card;
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
                height: 312.s,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ExploreThumb(
                      asset: card.thumbnailAsset,
                      url: card.thumbnailUrl,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _Progress(value: card.progress ?? 0),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.s),
            SizedBox(
              width: 149.s,
              // No avatar here: the design gives this rail the creator's name
              // on its own, so the poster keeps the reader's eye.
              child: ExploreCardMeta(card: card, showAvatar: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4.s,
      child: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(color: AppColors.progressTrack),
          ),
          FractionallySizedBox(
            widthFactor: value.clamp(0, 1),
            child: const ColoredBox(color: AppColors.progressFill),
          ),
        ],
      ),
    );
  }
}

/// A ranked card: the position is drawn oversized behind the artwork's
/// top-left corner and clipped by it, so the number reads as part of the art.
class ExploreTrendingCard extends StatelessWidget {
  const ExploreTrendingCard({
    super.key,
    required this.card,
    required this.rank,
    this.onTap,
  });

  static const double width = 153;

  final ExploreCard card;
  final int rank;
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
                height: 205.s,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ExploreThumb(
                      asset: card.thumbnailAsset,
                      url: card.thumbnailUrl,
                    ),
                    Positioned(
                      left: -20.s,
                      top: -17.s,
                      width: 61.s,
                      child: _RankNumeral(rank: rank),
                    ),
                    Positioned(
                      left: 5.s,
                      bottom: 6.s,
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedMusicNote01,
                        color: AppColors.textPrimary,
                        size: 12.538.s,
                      ),
                    ),
                    if (card.badge case final badge?)
                      Positioned(
                        right: 4.s,
                        bottom: 4.s,
                        child: ExploreBadge(label: badge),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10.s),
            SizedBox(width: 149.s, child: ExploreCardMeta(card: card)),
            if (card.sponsored) ...[
              SizedBox(height: 10.s),
              const ExploreSponsoredTag(),
            ],
          ],
        ),
      ),
    );
  }
}

class _RankNumeral extends StatelessWidget {
  const _RankNumeral({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      // White at the top fading to near-black at the bottom, so the digit
      // sinks into the artwork rather than sitting on it.
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.textPrimary, Color(0xAB000000)],
      ).createShader(bounds),
      child: Text(
        '$rank',
        textAlign: TextAlign.center,
        style: AppStyles.heading(
          61,
          family: AppStyles.featureFont,
          weight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// The card shape shared by Devotionals and Articles: a wide still, a corner
/// glyph naming the kind, and a length badge.
class ExplorePosterCard extends StatelessWidget {
  const ExplorePosterCard({
    super.key,
    required this.card,
    required this.kindIcon,
    this.onTap,
  });

  static const double width = 153;

  final ExploreCard card;

  /// Bible for a devotional, open book for an article.
  final String kindIcon;

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
                height: 130.s,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ExploreThumb(
                      asset: card.thumbnailAsset,
                      url: card.thumbnailUrl,
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: DesignIcon(
                        kindIcon,
                        width: 12.538.s,
                        height: 12.538.s,
                        color: AppColors.brandGold,
                      ),
                    ),
                    if (card.badge case final badge?)
                      Positioned(
                        right: 4.s,
                        bottom: 4.s,
                        child: ExploreBadge(label: badge),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8.s),
            SizedBox(width: 149.s, child: ExploreCardMeta(card: card)),
            if (card.sponsored) ...[
              SizedBox(height: 8.s),
              const ExploreSponsoredTag(),
            ],
          ],
        ),
      ),
    );
  }
}
