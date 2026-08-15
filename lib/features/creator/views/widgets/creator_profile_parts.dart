import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/discovery/views/widgets/detail_sections.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount, relativeAge;
import 'package:test_app/models/creator_models/creator_profile.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

enum CreatorTab {
  latest,
  library,
  live,
  testimonies,
  about;

  static const librarySections = [
    'series',
    'videos',
    'music',
    'devotionals',
    'posts',
    'events',
  ];

  String get label => switch (this) {
    latest => AppStrings.tabLatest,
    library => AppStrings.tabLibrary,
    live => AppStrings.tabLive,
    testimonies => AppStrings.tabTestimonies,
    about => AppStrings.tabAbout,
  };

  String get emptyTitle => switch (this) {
    latest => AppStrings.creatorEmptyLatestTitle,
    library => AppStrings.creatorEmptyLibraryTitle,
    live => AppStrings.creatorEmptyLiveTitle,
    testimonies => AppStrings.creatorEmptyTestimoniesTitle,
    about => '',
  };

  String get emptyBody => switch (this) {
    latest => AppStrings.creatorEmptyLatestBody,
    library => AppStrings.creatorEmptyLibraryBody,
    live => AppStrings.creatorEmptyLiveBody,
    testimonies => AppStrings.creatorEmptyTestimoniesBody,
    about => '',
  };

  String get emptyAction => switch (this) {
    live => AppStrings.notifyMeWhenLive,
    testimonies => AppStrings.shareYourTestimony,
    _ => AppStrings.subscribeFollow,
  };

  String get emptyActionFeature => switch (this) {
    live => 'get live alerts',
    testimonies => 'share a testimony',
    _ => 'follow creators',
  };

  String get emptyIcon => switch (this) {
    library => AppAssets.iconBookOpen,
    live => AppAssets.iconEmptyLiveOff,
    testimonies => AppAssets.iconCatHeartHand,
    _ => AppAssets.iconCatDove,
  };
}

/// Banner, avatar, identity and the Follow / Give Now / more actions.
class CreatorProfileHeader extends StatelessWidget {
  const CreatorProfileHeader({
    super.key,
    required this.profile,
    required this.busy,
    this.onBack,
    this.onFollow,
    this.onGive,
    this.onMore,
  });

  final CreatorProfile profile;
  final bool busy;
  final VoidCallback? onBack;
  final VoidCallback? onFollow;
  final VoidCallback? onGive;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150.s + topInset,
          child: Stack(
            children: [
              // TODO(api): bannerKey has no resolvable URL yet, so the banner
              // falls back to the brand gradient.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.brandPrimaryDeep,
                        AppColors.brandSecondary,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 15.s,
                top: topInset + 12.s,
                child: _CircleButton(
                  icon: AppAssets.iconArrowLeft,
                  width: 20,
                  height: 14,
                  onTap: onBack,
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: Offset(0, -26.s),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DetailAvatar(
                  name: profile.displayName,
                  isOrganization: profile.isOrganization,
                  size: 56,
                ),
                SizedBox(height: 9.s),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.heading(20, lineHeight: 20 / 20),
                      ),
                    ),
                    if (profile.isVerified) ...[
                      SizedBox(width: 4.s),
                      DesignIcon(
                        AppAssets.iconFeedVerified,
                        width: 16.s,
                        height: 16.s,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2.s),
                Text(
                  '@${profile.handle}',
                  style: AppStyles.label(
                    13,
                    weight: AppStyles.bold,
                    color: AppColors.neutral400,
                  ),
                ),
                if (profile.bio case final bio? when bio.trim().isNotEmpty) ...[
                  SizedBox(height: 9.s),
                  Text(
                    bio,
                    style: AppStyles.body(
                      13,
                      color: AppColors.neutral300,
                      lineHeight: 18 / 13,
                    ),
                  ),
                ],
                SizedBox(height: 9.s),
                Row(
                  children: [
                    DesignIcon(
                      AppAssets.iconFeedUsers,
                      width: 16.s,
                      height: 16.s,
                    ),
                    SizedBox(width: 4.s),
                    Text(
                      '${formatCount(profile.subscriberCount)} '
                      '${AppStrings.subscribers}',
                      style: AppStyles.label(
                        12,
                        weight: AppStyles.bold,
                        color: AppColors.neutral500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.s),
                _Actions(
                  following: profile.isFollowing,
                  busy: busy,
                  onFollow: onFollow,
                  onGive: onGive,
                  onMore: onMore,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.following,
    required this.busy,
    this.onFollow,
    this.onGive,
    this.onMore,
  });

  final bool following;
  final bool busy;
  final VoidCallback? onFollow;
  final VoidCallback? onGive;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    // Following reads as "Unfollow" in red — the action, not the state.
    final followColour = following ? AppColors.red500 : AppColors.textPrimary;
    return Row(
      children: [
        Expanded(
          child: _OutlineButton(
            label: following ? AppStrings.unfollow : AppStrings.follow,
            colour: followColour,
            borderColour: following ? AppColors.red500 : AppColors.neutral700,
            busy: busy,
            onTap: onFollow,
          ),
        ),
        SizedBox(width: 10.s),
        Expanded(
          child: _OutlineButton(
            label: AppStrings.giveNow,
            colour: AppColors.textPrimary,
            borderColour: AppColors.neutral700,
            onTap: onGive,
          ),
        ),
        SizedBox(width: 10.s),
        _CircleButton(
          icon: AppAssets.iconFeedMore,
          width: 16,
          height: 4,
          square: true,
          onTap: onMore,
        ),
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.colour,
    required this.borderColour,
    this.busy = false,
    this.onTap,
  });

  final String label;
  final Color colour;
  final Color borderColour;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        height: 40.s,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.s),
          border: Border.all(color: borderColour, width: 1.5.s),
        ),
        child: Center(
          child: busy
              ? SizedBox(
                  width: 14.s,
                  height: 14.s,
                  child: const CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: AppColors.neutral300,
                  ),
                )
              : Text(label, style: AppStyles.button(13, color: colour)),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.width,
    required this.height,
    this.square = false,
    this.onTap,
  });

  final String icon;
  final double width;
  final double height;
  final bool square;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40.s,
        height: 40.s,
        decoration: BoxDecoration(
          color: AppColors.fieldBg.withValues(alpha: square ? 1 : 0.6),
          borderRadius: BorderRadius.circular(square ? 8.s : 999.s),
          border: Border.all(color: AppColors.neutral800, width: 1.5.s),
        ),
        child: Center(
          child: DesignIcon(
            icon,
            width: width.s,
            height: height.s,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Latest · Library · ●Live · Testimonies · About
class CreatorTabBar extends StatelessWidget {
  const CreatorTabBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final CreatorTab selected;
  final ValueChanged<CreatorTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.neutral800, width: 1.s),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.s),
        child: Row(
          children: [
            for (final tab in CreatorTab.values)
              _Tab(
                tab: tab,
                active: tab == selected,
                onTap: () => onChanged(tab),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.active, required this.onTap});

  final CreatorTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10.s),
            Row(
              children: [
                if (tab == CreatorTab.live) ...[
                  Container(
                    width: 6.s,
                    height: 6.s,
                    decoration: const BoxDecoration(
                      color: AppColors.red500,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 5.s),
                ],
                Text(
                  tab.label,
                  style: AppStyles.label(
                    14,
                    weight: active ? AppStyles.black : AppStyles.medium,
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.neutral400,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.s),
            Container(
              height: 2.s,
              width: 28.s,
              color: active ? AppColors.brandPrimary : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-tab empty state (Figma `11117-123440`).
class CreatorTabEmptyState extends StatelessWidget {
  const CreatorTabEmptyState({super.key, required this.tab, this.onAction});

  final CreatorTab tab;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(32.s, 40.s, 32.s, 40.s),
      child: Column(
        children: [
          Container(
            width: 56.s,
            height: 56.s,
            decoration: const BoxDecoration(
              color: Color(0x33FFA500),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: DesignIcon(
                tab.emptyIcon,
                width: 24.s,
                height: 24.s,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
          SizedBox(height: 16.s),
          Text(
            tab.emptyTitle,
            textAlign: TextAlign.center,
            style: AppStyles.heading(16, lineHeight: 22 / 16),
          ),
          SizedBox(height: 8.s),
          Text(
            tab.emptyBody,
            textAlign: TextAlign.center,
            style: AppStyles.body(
              12,
              color: AppColors.neutral400,
              lineHeight: 18 / 12,
            ),
          ),
          SizedBox(height: 20.s),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24.s, vertical: 11.s),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.s),
                border: Border.all(color: AppColors.neutral700, width: 1.5.s),
              ),
              child: Text(tab.emptyAction, style: AppStyles.button(13)),
            ),
          ),
        ],
      ),
    );
  }
}

/// About tab — only the parts the API can actually answer.
class CreatorAboutTab extends StatelessWidget {
  const CreatorAboutTab({super.key, required this.profile});

  final CreatorProfile profile;

  @override
  Widget build(BuildContext context) {
    final bio = profile.bio?.trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(16.s, 20.s, 16.s, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Panel(
            title: AppStrings.aboutLabel,
            child: Text(
              bio == null || bio.isEmpty ? AppStrings.notAvailable : bio,
              style: AppStyles.body(
                13,
                color: AppColors.neutral300,
                lineHeight: 18 / 13,
              ),
            ),
          ),
          SizedBox(height: 20.s),
          const DetailSectionHeading(AppStrings.detailsLabel),
          SizedBox(height: 10.s),
          _DetailRow(
            label: AppStrings.typeLabel,
            value: profile.isOrganization
                ? AppStrings.creatorTypeOrganisationValue
                : AppStrings.creatorTypeIndividualValue,
          ),
          if (profile.createdAt case final at?)
            _DetailRow(
              label: AppStrings.onGospelTube,
              value: '${AppStrings.sincePrefix}${relativeAge(at)}',
            ),
          SizedBox(height: 20.s),
          const DetailSectionHeading(AppStrings.reachLabel),
          SizedBox(height: 10.s),
          _StatTile(
            value: formatCount(profile.subscriberCount),
            label: AppStrings.subscribers,
          ),
          SizedBox(height: 8.s),
          _StatTile(
            value: formatCount(profile.totalViews),
            label: AppStrings.totalViewsLabel,
          ),
          SizedBox(height: 24.s),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(8.s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            style: AppStyles.overline(11, color: AppColors.neutral400),
          ),
          SizedBox(height: 6.s),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.s),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.neutral800, width: 1.s),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppStyles.body(13, color: AppColors.neutral400),
            ),
          ),
          Text(value, style: AppStyles.label(13, weight: AppStyles.bold)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(8.s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppStyles.heading(18)),
          SizedBox(height: 2.s),
          Text(label, style: AppStyles.body(12, color: AppColors.neutral400)),
        ],
      ),
    );
  }
}

class CreatorTestimonyCard extends StatelessWidget {
  const CreatorTestimonyCard({super.key, required this.item});

  final CreatorTestimony item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.s, 12.s, 16.s, 0),
      padding: EdgeInsets.all(14.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(8.s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.body,
            style: AppStyles.body(
              13,
              color: AppColors.neutral300,
              lineHeight: 18 / 13,
            ),
          ),
          SizedBox(height: 8.s),
          Text(
            item.anonymous
                ? AppStrings.anonymousTestimony
                : relativeAge(item.createdAt),
            style: AppStyles.label(11, color: AppColors.neutral500),
          ),
        ],
      ),
    );
  }
}
