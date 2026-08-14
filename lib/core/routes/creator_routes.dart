import 'package:go_router/go_router.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/core/transitions.dart';
import 'package:test_app/features/creator/views/creator_profile_setup_screen.dart';
import 'package:test_app/features/creator/views/checkout_status_screen.dart';
import 'package:test_app/features/creator/views/creator_type_screen.dart';
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
    path: AppRouter.checkoutStatus,
    pageBuilder: (context, state) => slideTransition(
      state,
      CheckoutStatusScreen(sessionId: state.extra as String?),
    ),
  ),
];
