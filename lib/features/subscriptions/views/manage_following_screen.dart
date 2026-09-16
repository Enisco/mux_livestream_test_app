import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/subscriptions/data/subscriptions_dummy_data.dart';
import 'package:test_app/models/subscription_models/subscription_models.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Everyone the reader follows, and what each is allowed to notify about.
///
/// Unfollowing and the notification levels are held in memory only — see
/// [SubscriptionsDummyData] for which routes are missing.
class ManageFollowingScreen extends StatefulWidget {
  const ManageFollowingScreen({super.key});

  @override
  State<ManageFollowingScreen> createState() => _ManageFollowingScreenState();
}

class _ManageFollowingScreenState extends State<ManageFollowingScreen> {
  final _controller = TextEditingController();
  late List<FollowedMinistry> _ministries = [
    ...SubscriptionsDummyData.following,
  ];
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<FollowedMinistry> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _ministries;
    return _ministries
        .where(
          (m) =>
              m.name.toLowerCase().contains(q) ||
              m.handle.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  void _report(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _unfollow(FollowedMinistry ministry) {
    setState(() {
      _ministries = _ministries
          .where((m) => m.id != ministry.id)
          .toList(growable: false);
    });
  }

  void _openNotifications(FollowedMinistry ministry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => NotifyLevelSheet(
        ministry: ministry,
        onPicked: (level) {
          Navigator.pop(sheetContext);
          setState(() {
            final i = _ministries.indexWhere((m) => m.id == ministry.id);
            if (i < 0) return;
            _ministries = [..._ministries]..[i] = ministry.withNotify(level);
          });
        },
        onUnfollow: () {
          Navigator.pop(sheetContext);
          _unfollow(ministry);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final searching = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LibraryHeader(
            title: AppStrings.followingTitle,
            actionLabel: AppStrings.followingSeeLatest,
            actionIcon: HugeIcons.strokeRoundedAddCircle,
            actionTint: AppColors.brandPrimary,
            onAction: () => Navigator.pop(context),
            controller: _ministries.isEmpty ? null : _controller,
            onQueryChanged: _ministries.isEmpty
                ? null
                : (v) => setState(() => _query = v),
            searchHint: AppStrings.followingSearchHint,
          ),
          Expanded(
            child: matches.isEmpty
                ? SingleChildScrollView(
                    child: searching
                        ? const LibraryEmptyState(
                            icon: HugeIcons.strokeRoundedUserGroup,
                            title: AppStrings.followingNoMatchTitle,
                            body: AppStrings.followingNoMatchBody,
                          )
                        : FollowingStarterView(
                            suggestions: SubscriptionsDummyData.suggested,
                            onFollow: (m) =>
                                _report('Following ${m.name} is not built yet'),
                            onShowMore: () =>
                                _report('More ministries are not built yet'),
                          ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 40.s),
                    itemCount: matches.length,
                    itemBuilder: (context, i) => _MinistryRow(
                      ministry: matches[i],
                      onUnfollow: () => _unfollow(matches[i]),
                      onNotifications: () => _openNotifications(matches[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MinistryRow extends StatelessWidget {
  const _MinistryRow({
    required this.ministry,
    required this.onUnfollow,
    required this.onNotifications,
  });

  final FollowedMinistry ministry;
  final VoidCallback onUnfollow;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.s),
      child: Row(
        children: [
          MinistryAvatar(size: 36.s),
          SizedBox(width: 10.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ministry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.label(13, weight: AppStyles.bold),
                      ),
                    ),
                    if (ministry.verified) ...[
                      SizedBox(width: 4.s),
                      DesignIcon(
                        AppAssets.iconFeedVerified,
                        width: 13.s,
                        height: 13.s,
                      ),
                    ],
                    if (ministry.isLive) ...[
                      SizedBox(width: 6.s),
                      const _LiveBadge(),
                    ],
                  ],
                ),
                SizedBox(height: 3.s),
                Text(
                  '${ministry.handle} · ${ministry.lastActivity}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.label(
                    12,
                    color: AppColors.neutral500,
                    lineHeight: 16 / 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.s),
          _SquareButton(
            key: ValueKey('unfollow-${ministry.id}'),
            icon: HugeIcons.strokeRoundedUserRemove01,
            tint: AppColors.destructive,
            onTap: onUnfollow,
          ),
          SizedBox(width: 8.s),
          _SquareButton(
            key: ValueKey('notify-${ministry.id}'),
            // A silenced ministry shows the struck-through bell, so the row
            // says what it will do without opening the sheet.
            icon: ministry.notify == NotifyLevel.none
                ? HugeIcons.strokeRoundedNotificationOff01
                : HugeIcons.strokeRoundedNotification01,
            onTap: onNotifications,
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.s, vertical: 1.s),
      decoration: BoxDecoration(
        color: AppColors.destructive,
        borderRadius: BorderRadius.circular(4.s),
      ),
      child: Text(
        AppStrings.followingLive,
        style: AppStyles.label(
          9,
          weight: AppStyles.bold,
          lineHeight: 12 / 9,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tint,
  });

  final List<List<dynamic>> icon;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 34.s,
        height: 30.s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6.s),
          border: Border.all(color: AppColors.neutral800),
        ),
        child: HugeIcon(
          icon: icon,
          color: tint ?? AppColors.textPrimary,
          size: 16.s,
        ),
      ),
    );
  }
}

/// How much one ministry may notify about, plus the way out of following it.
class NotifyLevelSheet extends StatelessWidget {
  const NotifyLevelSheet({
    super.key,
    required this.ministry,
    required this.onPicked,
    required this.onUnfollow,
  });

  final FollowedMinistry ministry;
  final ValueChanged<NotifyLevel> onPicked;
  final VoidCallback onUnfollow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(12.s),
      decoration: BoxDecoration(
        color: AppColors.base2,
        borderRadius: BorderRadius.circular(16.s),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final level in NotifyLevel.values)
              _LevelRow(
                level: level,
                selected: ministry.notify == level,
                onTap: () => onPicked(level),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.s, 14.s, 16.s, 16.s),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onUnfollow,
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedUserRemove01,
                      color: AppColors.destructive,
                      size: 16.s,
                    ),
                    SizedBox(width: 8.s),
                    Flexible(
                      child: Text(
                        '${AppStrings.followingUnfollowPrefix} '
                        '${ministry.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.label(
                          13,
                          weight: AppStyles.bold,
                          color: AppColors.destructive,
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
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final NotifyLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('level-${level.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 12.s),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.neutral900)),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: level == NotifyLevel.none
                  ? HugeIcons.strokeRoundedNotificationOff01
                  : HugeIcons.strokeRoundedNotification01,
              color: AppColors.textPrimary,
              size: 17.s,
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    level.label,
                    style: AppStyles.label(13, weight: AppStyles.bold),
                  ),
                  SizedBox(height: 2.s),
                  Text(
                    level.body,
                    style: AppStyles.label(
                      11,
                      color: AppColors.neutral500,
                      lineHeight: 15 / 11,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.s),
            _Switch(on: selected),
          ],
        ),
      ),
    );
  }
}

/// The sheet's rows are one choice, not four independent ones, so only the
/// level in force reads as on.
class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.s,
      height: 22.s,
      padding: EdgeInsets.all(2.s),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? AppColors.brandPrimary : AppColors.neutral800,
        borderRadius: BorderRadius.circular(999.s),
      ),
      child: Container(
        width: 18.s,
        height: 18.s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? AppColors.base1 : AppColors.neutral500,
        ),
        child: on
            ? null
            : HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                color: AppColors.neutral300,
                size: 10.s,
              ),
      ),
    );
  }
}

/// The feed with nothing in it: why it is empty, and a way to fix that.
class FollowingStarterView extends StatelessWidget {
  const FollowingStarterView({
    super.key,
    required this.suggestions,
    required this.onFollow,
    required this.onShowMore,
  });

  final List<SuggestedMinistry> suggestions;
  final ValueChanged<SuggestedMinistry> onFollow;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LibraryEmptyState(
          icon: HugeIcons.strokeRoundedUserSearch01,
          title: AppStrings.followingFillTitle,
          body: AppStrings.followingFillBody,
        ),
        Container(
          margin: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 24.s),
          padding: EdgeInsets.all(14.s),
          decoration: BoxDecoration(
            color: AppColors.fieldBg,
            borderRadius: BorderRadius.circular(12.s),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.followingStarterTitle,
                style: AppStyles.label(
                  14,
                  weight: AppStyles.bold,
                  lineHeight: 20 / 14,
                ),
              ),
              SizedBox(height: 10.s),
              for (final ministry in suggestions)
                _SuggestionRow(
                  ministry: ministry,
                  onFollow: () => onFollow(ministry),
                ),
              SizedBox(height: 6.s),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onShowMore,
                child: Text(
                  AppStrings.followingShowMore,
                  style: AppStyles.label(
                    13,
                    weight: AppStyles.bold,
                    color: AppColors.brandPrimary,
                  ),
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
  const _SuggestionRow({required this.ministry, required this.onFollow});

  final SuggestedMinistry ministry;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.s),
      child: Row(
        children: [
          MinistryAvatar(size: 34.s),
          SizedBox(width: 10.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ministry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.label(13, weight: AppStyles.bold),
                      ),
                    ),
                    if (ministry.verified) ...[
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
                  ministry.handle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.label(
                    11,
                    color: AppColors.neutral500,
                    lineHeight: 15 / 11,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.s),
          GestureDetector(
            key: ValueKey('follow-${ministry.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: onFollow,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 7.s),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6.s),
                border: Border.all(color: AppColors.neutral700),
              ),
              child: Text(AppStrings.follow, style: AppStyles.button(12)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A placeholder ring; ministry avatars are not resolved anywhere yet.
class MinistryAvatar extends StatelessWidget {
  const MinistryAvatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.buttonSecondaryActive,
        border: Border.all(color: AppColors.purple400, width: size / 20),
      ),
      child: Icon(Icons.person, size: size * 0.6, color: AppColors.neutral400),
    );
  }
}
