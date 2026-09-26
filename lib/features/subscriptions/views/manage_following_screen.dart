import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/subscriptions/repo/following_repo.dart';
import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/models/subscription_models/subscription_models.dart';
import 'package:test_app/shared/services/live_socket_service.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Everyone the reader follows, and what each is allowed to notify about.
///
/// This ran on a hardcoded list until the routes turned up. Two of those
/// invented ministries carried `isLive: true` permanently, which is why
/// ministries appeared to be broadcasting when they were not — the badge had
/// no source at all. It is real now:
///
///  * the list is `GET /v1/discovery/following-creators`,
///  * "Live now" comes from the feed's own `liveOnly: true` answer,
///  * unfollow is `DELETE /v1/creator/{id}/subscribe`,
///  * the notification level rewrites the four `notifyOn*` flags through the
///    upserting `POST`.
class ManageFollowingScreen extends StatefulWidget {
  const ManageFollowingScreen({super.key});

  @override
  State<ManageFollowingScreen> createState() => _ManageFollowingScreenState();
}

class _ManageFollowingScreenState extends State<ManageFollowingScreen> {
  final _controller = TextEditingController();
  final _repo = GetIt.instance<FollowingRepo>();

  List<FollowedMinistry> _ministries = const [];
  List<SuggestedMinistry> _suggestions = const [];
  String _query = '';
  bool _loading = true;
  bool _failed = false;
  StreamSubscription<LiveEvent>? _liveEvents;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_liveEvents?.cancel());
    if (GetIt.instance.isRegistered<LiveSocketService>()) {
      final socket = GetIt.instance<LiveSocketService>();
      for (final m in _ministries) {
        socket.unsubscribeCreator(m.id);
      }
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final following = await _repo.fetchFollowing();
      // Asked separately because the following payload carries no live flag.
      // A failure here costs the badges, not the list.
      var live = const <String>{};
      try {
        live = await _repo.fetchLiveCreatorIds();
      } catch (e) {
        logger.w('Live status unavailable for the following list', error: e);
      }
      if (!mounted) return;
      setState(() {
        _ministries = [
          for (final m in following)
            live.contains(m.id) ? m.copyWith(isLive: true) : m,
        ];
        _loading = false;
      });
      if (following.isEmpty) unawaited(_loadSuggestions());
      unawaited(_watchLive());
    } catch (e) {
      logger.w('Could not load the following list', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// Follows each ministry's public room so a badge appears when they go on
  /// air and — the half that was actually wrong — disappears when they stop.
  ///
  /// Without this the badges are only as fresh as the last time the screen
  /// was opened, which is how a ministry that ended an hour ago can still be
  /// shown as live.
  Future<void> _watchLive() async {
    // Live badges are a nicety; the list is the screen. A socket that cannot
    // be reached, or is not registered at all, must cost the badges and
    // nothing else.
    if (!GetIt.instance.isRegistered<LiveSocketService>()) return;
    final socket = GetIt.instance<LiveSocketService>();
    try {
      await socket.connect();
    } catch (e) {
      logger.w('Live socket unavailable', error: e);
      return;
    }
    for (final m in _ministries) {
      socket.subscribeCreator(m.id);
    }
    _liveEvents ??= socket.events.listen((event) {
      if (event.type != LiveEventType.statusChanged) return;
      if (!mounted || event.creatorId.isEmpty) return;
      final live = LiveRuntime.parse(event.status).isOnAir;
      setState(() {
        _ministries = [
          for (final m in _ministries)
            m.id == event.creatorId ? m.copyWith(isLive: live) : m,
        ];
      });
    });
  }

  Future<void> _loadSuggestions() async {
    try {
      final rows = await GetIt.instance<DiscoveryRepo>()
          .fetchRecommendedCreators(limit: 10);
      if (!mounted) return;
      setState(
        () =>
            _suggestions = rows.map(SuggestedMinistry.fromRecommended).toList(),
      );
    } catch (e) {
      logger.w('Could not load suggested ministries', error: e);
    }
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

  /// Removed straight away, and put back if the server refuses — the row
  /// disappearing and then returning is easier to understand than a row that
  /// sits there until a request finishes.
  Future<void> _unfollow(FollowedMinistry ministry) async {
    final before = _ministries;
    setState(() {
      _ministries = _ministries
          .where((m) => m.id != ministry.id)
          .toList(growable: false);
    });
    try {
      await _repo.unfollow(ministry.id);
      // Stop listening for a ministry that is no longer on the list.
      if (GetIt.instance.isRegistered<LiveSocketService>()) {
        GetIt.instance<LiveSocketService>().unsubscribeCreator(ministry.id);
      }
      if (mounted && _ministries.isEmpty) unawaited(_loadSuggestions());
    } catch (e) {
      logger.w('Could not unfollow ${ministry.id}', error: e);
      if (!mounted) return;
      setState(() => _ministries = before);
      _report(AppStrings.followingUnfollowFailed);
    }
  }

  Future<void> _setNotify(FollowedMinistry ministry, NotifyLevel level) async {
    final before = _ministries;
    setState(() {
      final i = _ministries.indexWhere((m) => m.id == ministry.id);
      if (i < 0) return;
      _ministries = [..._ministries]..[i] = ministry.withNotify(level);
    });
    try {
      await _repo.setNotifyLevel(ministry.id, level);
    } catch (e) {
      logger.w('Could not set notify level for ${ministry.id}', error: e);
      if (!mounted) return;
      setState(() => _ministries = before);
      _report(AppStrings.followingNotifyFailed);
    }
  }

  Future<void> _follow(SuggestedMinistry ministry) async {
    try {
      await _repo.follow(ministry.id);
      await _load();
    } catch (e) {
      logger.w('Could not follow ${ministry.id}', error: e);
      if (mounted) _report(AppStrings.followingNotifyFailed);
    }
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
          unawaited(_setNotify(ministry, level));
        },
        onUnfollow: () {
          Navigator.pop(sheetContext);
          unawaited(_unfollow(ministry));
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
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandPrimary,
                    ),
                  )
                : _failed
                ? ErrorStateView(
                    onRetry: _load,
                    title: AppStrings.followingLoadFailed,
                  )
                : matches.isEmpty
                ? SingleChildScrollView(
                    child: searching
                        ? const LibraryEmptyState(
                            icon: HugeIcons.strokeRoundedUserGroup,
                            title: AppStrings.followingNoMatchTitle,
                            body: AppStrings.followingNoMatchBody,
                          )
                        : FollowingStarterView(
                            suggestions: _suggestions,
                            onFollow: (m) => unawaited(_follow(m)),
                            onShowMore: () => unawaited(_loadSuggestions()),
                          ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 40.s),
                    itemCount: matches.length,
                    itemBuilder: (context, i) => _MinistryRow(
                      ministry: matches[i],
                      onUnfollow: () => unawaited(_unfollow(matches[i])),
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
