import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Shared head of both empty tabs: a tinted disc, a headline and a line of
/// explanation, then a hairline before the list below.
class EmptyTabHeader extends StatelessWidget {
  const EmptyTabHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(32.s, 28.s, 32.s, 24.s),
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
              child: DesignIcon(icon, width: 26.s, height: 26.s),
            ),
          ),
          SizedBox(height: 16.s),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppStyles.heading(18, lineHeight: 24 / 18),
          ),
          SizedBox(height: 8.s),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppStyles.body(
              13,
              color: AppColors.neutral400,
              lineHeight: 20 / 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.s, 20.s, 16.s, 12.s),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label, style: AppStyles.heading(14, letterSpacing: -0.3)),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
    height: 1.5.s,
    color: AppColors.neutral400.withValues(alpha: 0.3),
  );
}

/// Following tab with nothing followed yet (Figma `10824-100773`).
class FollowingEmptyView extends StatelessWidget {
  const FollowingEmptyView({
    super.key,
    required this.suggestions,
    required this.pending,
    required this.onFollow,
    required this.onEditTopics,
  });

  final List<RecommendedCreator> suggestions;

  /// Creator ids with a follow request in flight.
  final Set<String> pending;
  final ValueChanged<RecommendedCreator> onFollow;
  final VoidCallback onEditTopics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        bottom: 92.s + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        EmptyTabHeader(
          icon: AppAssets.iconEmptyFollow,
          title: AppStrings.followingEmptyTitle,
          body: AppStrings.followingEmptyBody,
        ),
        const _Divider(),
        if (suggestions.isNotEmpty) ...[
          _SectionLabel(AppStrings.ministriesToFollow),
          for (final creator in suggestions)
            // TODO(profile): make the row open the creator profile once that
            // screen exists; for now only the Follow button acts.
            _SuggestionRow(
              creator: creator,
              busy: pending.contains(creator.creatorId),
              onFollow: () => onFollow(creator),
            ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(16.s, 24.s, 16.s, 8.s),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                AppStrings.alreadyKnowWhatYouLike,
                style: AppStyles.body(13, color: AppColors.neutral300),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEditTopics,
                child: Text(
                  AppStrings.editYourTopics,
                  style: AppStyles.body(13, color: AppColors.brandPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.creator,
    required this.busy,
    required this.onFollow,
  });

  final RecommendedCreator creator;
  final bool busy;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.neutral400.withValues(alpha: 0.3),
            width: 1.5.s,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 12.s),
      child: Row(
        children: [
          _Avatar(name: creator.displayName),
          SizedBox(width: 12.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        creator.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.heading(14, letterSpacing: -0.3),
                      ),
                    ),
                    if (creator.isVerified) ...[
                      SizedBox(width: 4.s),
                      DesignIcon(
                        AppAssets.iconFeedVerified,
                        width: 13.s,
                        height: 13.s,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2.s),
                Text(
                  '@${creator.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.body(12, color: AppColors.neutral400),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.s),
          _FollowButton(
            following: creator.isFollowing,
            busy: busy,
            onTap: onFollow,
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.following,
    required this.busy,
    required this.onTap,
  });

  final bool following;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        constraints: BoxConstraints(minWidth: 78.s),
        padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 9.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.s),
          border: Border.all(color: AppColors.neutral400, width: 1.s),
          color: following
              ? AppColors.neutral400.withValues(alpha: 0.15)
              : null,
        ),
        child: Center(
          child: busy
              ? SizedBox(
                  width: 13.s,
                  height: 13.s,
                  child: const CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: AppColors.neutral300,
                  ),
                )
              : Text(
                  following ? AppStrings.following : AppStrings.follow,
                  style: AppStyles.label(13, weight: AppStyles.bold),
                ),
        ),
      ),
    );
  }
}

/// Live tab with nobody broadcasting (Figma `10824-100999`).
class LiveEmptyView extends StatelessWidget {
  const LiveEmptyView({
    super.key,
    required this.events,
    required this.onOpenEvent,
    this.onMore,
  });

  final List<WebFeedItem> events;
  final ValueChanged<WebFeedItem> onOpenEvent;
  final ValueChanged<WebFeedItem>? onMore;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        bottom: 92.s + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        EmptyTabHeader(
          icon: AppAssets.iconEmptyLiveOff,
          title: AppStrings.liveEmptyTitle,
          body: AppStrings.liveEmptyBody,
        ),
        const _Divider(),
        if (events.isNotEmpty) ...[
          _SectionLabel(AppStrings.upcomingEvents),
          for (final event in events)
            _EventRow(
              event: event,
              onTap: () => onOpenEvent(event),
              onMore: onMore == null ? null : () => onMore!(event),
            ),
        ],
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onTap, this.onMore});

  final WebFeedItem event;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  String get _time {
    final at = event.startsAt?.toLocal();
    if (at == null) return '';
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    return '$hour:$minute${at.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    final at = event.startsAt?.toLocal();
    final venue = event.meta.locationLabel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.s, 6.s, 16.s, 14.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.isPromoted) ...[
              Row(
                children: [
                  DesignIcon(
                    AppAssets.iconFeedLoudspeaker,
                    width: 11.s,
                    height: 11.s,
                  ),
                  SizedBox(width: 5.s),
                  Text(
                    AppStrings.sponsored,
                    style: AppStyles.overline(
                      10,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.s),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateBlock(
                  day: at == null ? '--' : at.day.toString(),
                  month: at == null ? '' : _months[at.month - 1],
                ),
                SizedBox(width: 12.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              event.creatorDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppStyles.body(
                                12,
                                color: AppColors.neutral300,
                              ),
                            ),
                          ),
                          if (event.creatorVerified) ...[
                            SizedBox(width: 4.s),
                            DesignIcon(
                              AppAssets.iconFeedVerified,
                              width: 12.s,
                              height: 12.s,
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 3.s),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.heading(15, letterSpacing: -0.4),
                      ),
                      SizedBox(height: 6.s),
                      Row(
                        children: [
                          DesignIcon(
                            AppAssets.iconPin,
                            width: 11.s,
                            height: 11.s,
                          ),
                          SizedBox(width: 4.s),
                          Flexible(
                            child: Text(
                              [
                                if (venue != null && venue.isNotEmpty) venue,
                                if (_time.isNotEmpty) _time,
                              ].join('  •  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppStyles.body(
                                12,
                                color: AppColors.neutral400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onMore != null) ...[
                  SizedBox(width: 8.s),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onMore,
                    child: Container(
                      width: 34.s,
                      height: 30.s,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.s),
                        border: Border.all(
                          color: AppColors.neutral400.withValues(alpha: 0.6),
                          width: 1.s,
                        ),
                      ),
                      child: Center(
                        child: DesignIcon(
                          AppAssets.iconFeedMore,
                          width: 13.s,
                          height: 3.s,
                        ),
                      ),
                    ),
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

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.day, required this.month});

  final String day;
  final String month;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52.s,
      padding: EdgeInsets.symmetric(vertical: 10.s),
      decoration: BoxDecoration(
        color: AppColors.base2,
        borderRadius: BorderRadius.circular(8.s),
        border: Border.all(
          color: AppColors.neutral400.withValues(alpha: 0.3),
          width: 1.s,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(day, style: AppStyles.heading(18, letterSpacing: -0.6)),
          SizedBox(height: 2.s),
          Text(
            month,
            style: AppStyles.overline(10, color: AppColors.neutral400),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 42.s,
      height: 42.s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.brandPrimary, AppColors.brandPrimaryDeep],
        ),
      ),
      child: Center(child: Text(initial, style: AppStyles.heading(16))),
    );
  }
}
