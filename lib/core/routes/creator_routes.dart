import 'package:go_router/go_router.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/core/transitions.dart';
import 'package:test_app/features/creator/views/creator_live_screen.dart';
import 'package:test_app/features/creator/views/creator_polish_screens.dart';
import 'package:test_app/features/creator/views/creator_profile_setup_screen.dart';
import 'package:test_app/features/creator/views/checkout_status_screen.dart';
import 'package:test_app/features/creator/views/creator_profile_screen.dart';
import 'package:test_app/features/creator/views/creator_type_screen.dart';
import 'package:test_app/features/creator/views/studio_shell.dart';
import 'package:test_app/features/creator/views/organization_profile_setup_screen.dart';
import 'package:test_app/features/creator/views/plan_selection_screen.dart';

final List<RouteBase> creatorRoutes = [
  GoRoute(
    path: AppRouter.creatorType,
    pageBuilder: (context, state) =>
        slideTransition(state, const CreatorTypeScreen()),
  ),
  GoRoute(
    path: AppRouter.creatorSetup,
    pageBuilder: (context, state) =>
        slideTransition(state, const CreatorProfileSetupScreen()),
  ),
  GoRoute(
    path: AppRouter.orgSetup,
    pageBuilder: (context, state) =>
        slideTransition(state, const OrganizationProfileSetupScreen()),
  ),
  GoRoute(
    path: AppRouter.planSelection,
    pageBuilder: (context, state) =>
        slideTransition(state, const PlanSelectionScreen()),
  ),
  GoRoute(
    path: AppRouter.creatorProfile,
    pageBuilder: (context, state) => slideTransition(
      state,
      CreatorProfileScreen(
        creatorId: state.uri.queryParameters['id'],
        handle: state.uri.queryParameters['handle'],
      ),
    ),
  ),
  GoRoute(
    path: AppRouter.creatorLive,
    pageBuilder: (context, state) =>
        slideTransition(state, const CreatorLiveScreen()),
  ),
  GoRoute(
    path: AppRouter.creatorPhoto,
    pageBuilder: (context, state) =>
        slideTransition(state, const CreatorPhotoScreen()),
  ),
  GoRoute(
    path: AppRouter.creatorBanner,
    pageBuilder: (context, state) =>
        slideTransition(state, const CreatorBannerScreen()),
  ),
  GoRoute(
    path: AppRouter.creatorBio,
    pageBuilder: (context, state) =>
        slideTransition(state, const CreatorBioScreen()),
  ),
  GoRoute(
    path: AppRouter.creatorLinks,
    pageBuilder: (context, state) =>
        slideTransition(state, const CreatorLinksScreen()),
  ),
  GoRoute(
    path: AppRouter.studio,
    pageBuilder: (context, state) =>
        slideTransition(state, const StudioShell()),
  ),
  GoRoute(
    path: AppRouter.checkoutStatus,
    pageBuilder: (context, state) => slideTransition(
      state,
      CheckoutStatusScreen(sessionId: state.extra as String?),
    ),
  ),
];
