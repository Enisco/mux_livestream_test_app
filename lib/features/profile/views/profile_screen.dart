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
import 'package:test_app/features/discovery/views/widgets/detail_sections.dart';
import 'package:test_app/features/history/views/history_screen.dart';
import 'package:test_app/features/library/views/liked_saved_screens.dart';
import 'package:test_app/features/library/views/giving_screen.dart';
import 'package:test_app/features/library/views/my_events_screen.dart';
import 'package:test_app/features/library/views/playlists_screen.dart';
import 'package:test_app/features/library/views/records_screens.dart';
import 'package:test_app/features/profile/data/profile_dummy_data.dart';
import 'package:test_app/features/profile/views/widgets/profile_header_card.dart';
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
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  CreatorProfile? _channel;

  /// What the server says about whether this reader has a channel. Until it
  /// answers, the studio block shows nothing rather than guessing wrong in
  /// either direction.
  ChannelLookup? _lookup;

  @override
  void initState() {
    super.initState();
    _loadChannel();
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

  /// Nothing behind these yet. They are wired so the rows are not dead, and
  /// so the screen names exactly what is still missing.
  void _todo(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$what is not built yet', style: AppStyles.body(13)),
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
              hasNotifications: ProfileDummyData.hasUnreadNotifications,
              onTap: () => _todo(AppStrings.profileAccountInfo),
              onNotifications: () => _todo('Notifications'),
            ),
            SizedBox(height: 26.s),
            _continueWatching(),
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
    const progress = ProfileDummyData.lastWatched;
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
          onTap: () => _todo(progress.title),
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
          pill: ProfileDummyData.upcomingEventCount > 0
              ? '${ProfileDummyData.upcomingEventCount} '
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
