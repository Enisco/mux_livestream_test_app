import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/locator.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_app/features/creator/views/creator_profile_screen.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/discovery/views/content_detail_screen.dart';
import 'package:test_app/features/notifications/data/notification_store.dart';
import 'package:test_app/features/notifications/views/notifications_screen.dart';
import 'package:test_app/features/discovery/views/widgets/detail_sections.dart';
import 'package:test_app/features/history/views/history_screen.dart';
import 'package:test_app/features/library/views/liked_saved_screens.dart';
import 'package:test_app/features/library/views/giving_screen.dart';
import 'package:test_app/features/library/views/my_events_screen.dart';
import 'package:test_app/features/library/views/playlists_screen.dart';
import 'package:test_app/features/library/views/records_screens.dart';
import 'dart:async';

import 'package:test_app/features/library/repo/viewer_library_repo.dart';
import 'package:test_app/features/library/repo/viewer_records_repo.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/models/history_models/profile_watch_progress.dart';
import 'package:test_app/features/profile/views/widgets/profile_header_card.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';
import 'package:test_app/features/profile/views/widgets/profile_menu.dart';
import 'package:test_app/features/settings/views/settings_screen.dart';
import 'package:test_app/models/creator_models/creator_profile.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The You tab: who the reader is, what they were watching, and everything
/// filed under their account.
///
/// Most of it is real — the name and handle come from the cached account, the
/// studio row from the reader's own creator profile if they have one. What is
/// still invented is listed in [ProfileDummyData]; the destinations that do not
/// exist yet are marked below.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.library, this.records});

  /// Default to the real things; a test supplies its own.
  final ViewerLibraryRepo? library;
  final ViewerRecordsRepo? records;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _library = widget.library ?? ViewerLibraryRepo();
  late final _records = widget.records ?? ViewerRecordsRepo();

  CreatorProfile? _channel;

  /// The card under CONTINUE WATCHING, and the pill on "My events".
  ///
  /// Both are read from lists the reader's own library already loads — the
  /// first part-watched row of their history, and their own RSVPs — rather
  /// than from anything this screen owns. Null and zero both mean "do not
  /// draw it", which is what a reader with no history should see.
  HistoryEntry? _lastWatched;
  int _upcomingEvents = 0;

  /// What the server says about whether this reader has a channel. Until it
  /// answers, the studio block shows nothing rather than guessing wrong in
  /// either direction.
  ChannelLookup? _lookup;

  @override
  void initState() {
    super.initState();
    _loadChannel();
    unawaited(_loadLibrary());
    unawaited(_notifications.refresh());
    // The dot is drawn from the store, which the notifications screen also
    // writes — reading it once would leave a stale dot behind that screen.
    _notifications.addListener(_onNotifications);
  }

  final _notifications = getIt<NotificationStore>();

  void _onNotifications() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notifications.removeListener(_onNotifications);
    super.dispose();
  }

  /// Neither of these is worth an error state: a missing resume card or a
  /// missing count leaves the row as it would be for someone with nothing
  /// there, which is the honest reading.
  Future<void> _loadLibrary() async {
    try {
      final page = await _library.fetchHistory(limit: 20);
      final resume = [
        for (final day in page.days)
          for (final e in day.entries)
            if (e.progress != null && !e.isEvent) e,
      ];
      if (mounted) setState(() => _lastWatched = resume.firstOrNull);
    } catch (e) {
      logger.w('Profile history unavailable', error: e);
    }
    try {
      final events = await _records.fetchMyEvents(limit: 50);
      if (!mounted) return;
      setState(() {
        _upcomingEvents = events.where((e) => !e.past).length;
      });
    } catch (e) {
      logger.w('Profile events unavailable', error: e);
    }
  }

  /// A reader who has a channel gets the way into their studio; a reader who
  /// has none gets the invitation to start one. Which of those it is comes
  /// from the server, not from whatever happens to be cached.
  Future<void> _loadChannel({bool force = false}) async {
    final lookup = await getIt<CreatorRepo>().resolveChannel(force: force);
    if (!mounted) return;
    setState(() => _lookup = lookup);

    final id = lookup.id;
    if (id == null) return;
    try {
      final profile = await getIt<DiscoveryRepo>().fetchCreatorById(id);
      if (mounted) setState(() => _channel = profile);
    } catch (e) {
      // The studio row still works without the channel's picture and name.
      logger.w('Own channel unavailable', error: e);
    }
  }

  /// Starts the channel a reader does not have yet, and comes back to see
  /// whether they finished — so the block turns into their studio without
  /// them having to leave the tab and return.
  Future<void> _becomeCreator() async {
    await context.push(AppRouter.creatorType);
    if (!mounted) return;
    await _loadChannel(force: true);
  }

  void _openStudio() => context.go(AppRouter.studio);

  void _signOut() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.fieldBg,
        title: Text(
          AppStrings.profileSignOutTitle,
          style: AppStyles.heading(16),
        ),
        content: Text(
          AppStrings.profileSignOutBody,
          style: AppStyles.body(13, color: AppColors.neutral400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              AppStrings.notNow,
              style: AppStyles.button(13, color: AppColors.neutral400),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            child: Text(
              AppStrings.profileSignOut,
              style: AppStyles.button(13, color: AppColors.brandPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        LocalStorage.cachedFullName ??
        LocalStorage.cachedFirstName ??
        AppStrings.accountFallbackName;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(15.s, 10.s, 15.s, 130.s),
          children: [
            ProfileHeaderCard(
              name: name,
              handle: LocalStorage.cachedHandle,
              avatarUrl: AssetUrlResolver.resolve(LocalStorage.cachedAvatarKey),
              hasNotifications: _notifications.hasUnread,
              // The card names the account, so it opens the account — the
              // same screen the Account row at the bottom leads to.
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
                if (mounted) setState(() {});
              },
              onNotifications: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
            SizedBox(height: 26.s),
            // Nothing part-watched means no section at all, which is what a
            // reader with no history should see.
            if (_lastWatched != null) _continueWatching(),
            _studio(),
            SizedBox(height: 20.s),
            _you(),
            SizedBox(height: 20.s),
            _account(),
          ],
        ),
      ),
    );
  }

  Widget _continueWatching() {
    final row = _lastWatched!;
    final progress = ProfileWatchProgress(
      mediaId: row.id,
      title: row.title,
      creatorName: row.creatorName,
      creatorVerified: row.creatorVerified,
      thumbnailUrl: row.thumbnailUrl,
      fraction: row.progress ?? 0,
      remainingLabel: remainingOf(row),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.profileContinueWatching,
          style: AppStyles.label(
            10,
            weight: AppStyles.bold,
            color: AppColors.neutral400,
            lineHeight: 16 / 10,
          ),
        ),
        SizedBox(height: 10.s),
        ContinueWatchingCard(
          progress: progress,
          onTap: () {
            if (!openFeedItem(
              context,
              row.source,
              source: AnalyticsSource.library,
            )) {
              _say(AppStrings.libraryRowGone);
            }
          },
        ),
        SizedBox(height: 24.s),
      ],
    );
  }

  Widget _studio() {
    final channel = _channel;
    final lookup = _lookup;

    // Nothing is offered until the server has answered: inviting a reader
    // who already has a channel walks them into a 409, and hiding the
    // studio from one who does is just as wrong. A lookup that failed says
    // neither, so the whole block stands down rather than leaving its
    // heading over an empty space.
    if (lookup == null || (!lookup.canStartOne && !lookup.hasChannel)) {
      return const SizedBox.shrink();
    }

    return ProfileMenuSection(
      caption: AppStrings.profileStudio,
      children: [
        if (lookup.canStartOne)
          ProfileMenuItem(
            key: const ValueKey('profile-become-creator'),
            icon: HugeIcons.strokeRoundedVideo01,
            label: AppStrings.profileBecomeCreator,
            note: AppStrings.profileStartChannel,
            onTap: _becomeCreator,
          ),
        // The channel's own studio, which is where a creator actually works.
        if (lookup.hasChannel)
          ProfileMenuItem(
            key: const ValueKey('profile-open-studio'),
            icon: HugeIcons.strokeRoundedGridView,
            label: AppStrings.profileOpenStudio,
            note: AppStrings.profileOpenStudioNote,
            onTap: _openStudio,
          ),
        if (channel != null)
          ProfileMenuItem(
            leading: DetailAvatar(
              name: channel.displayName,
              isOrganization: channel.isOrganization,
              size: 20,
            ),
            label: channel.displayName,
            tag: AppStrings.profileStreamerTag,
            onTap: () => openCreatorProfile(context, creatorId: channel.id),
          ),
      ],
    );
  }

  Widget _you() {
    return ProfileMenuSection(
      caption: AppStrings.profileYou,
      children: [
        ProfileMenuItem(
          icon: HugeIcons.strokeRoundedClock01,
          label: AppStrings.profileHistory,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          ),
        ),
        ProfileMenuItem(
          icon: HugeIcons.strokeRoundedFolderHeart,
          label: AppStrings.profilePlaylist,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlaylistsScreen()),
          ),
        ),
        ProfileMenuItem(
          icon: HugeIcons.strokeRoundedThumbsUp,
          label: AppStrings.profileLiked,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LikedScreen()),
          ),
        ),
        ProfileMenuItem(
          icon: HugeIcons.strokeRoundedBookmarkAdd01,
          label: AppStrings.profileSaved,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SavedScreen()),
          ),
        ),
        ProfileMenuItem(
          icon: HugeIcons.strokeRoundedCalendar03,
          label: AppStrings.profileMyEvents,
          pill: _upcomingEvents > 0
              ? '$_upcomingEvents '
                    '${AppStrings.profileUpcomingSuffix}'
              : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyEventsScreen()),
          ),
        ),
        ProfileMenuItem(
          icon: HugeIcons.strokeRoundedCharity,
          label: AppStrings.profilePrayerRequests,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrayerRequestsScreen()),
          ),
        ),
        ProfileMenuItem(
          icon: HugeIcons.strokeRoundedFile01,
          label: AppStrings.profileTestimonies,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TestimoniesScreen()),
          ),
        ),
        ProfileMenuItem(
          icon: HugeIcons.strokeRoundedGift,
          label: AppStrings.profileGiving,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GivingScreen()),
          ),
        ),
      ],
    );
  }

  Widget _account() {
    return ProfileMenuSection(
      caption: AppStrings.profileAccount,
      children: [
        ProfileMenuItem(
          icon: HugeIcons.strokeRoundedSettings01,
          label: AppStrings.profileSettings,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        ProfileMenuItem(
          icon: HugeIcons.strokeRoundedLogout01,
          label: AppStrings.profileSignOut,
          onTap: _signOut,
        ),
      ],
    );
  }
}
