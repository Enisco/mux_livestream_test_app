import 'package:go_router/go_router.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/core/transitions.dart';
import 'package:test_app/features/onboarding/views/discovery_source_screen.dart';
import 'package:test_app/features/onboarding/views/interests_screen.dart';
import 'package:test_app/features/onboarding/views/role_selection_screen.dart';
import 'package:test_app/features/onboarding/views/welcome_note_screen.dart';

final List<RouteBase> onboardingRoutes = [
  GoRoute(
    path: AppRouter.welcomeNote,
    pageBuilder: (context, state) => fadeTransition(
      state,
      WelcomeNoteScreen(
        name: state.uri.queryParameters['name'],
        nextRoute: state.uri.queryParameters['next'],
      ),
    ),
  ),
  GoRoute(
    path: AppRouter.roleSelection,
    pageBuilder: (context, state) => slideTransition(
      state,
      RoleSelectionScreen(name: state.uri.queryParameters['name']),
    ),
  ),
  GoRoute(
    path: AppRouter.interests,
    pageBuilder: (context, state) =>
        slideTransition(state, const InterestsScreen()),
  ),
  GoRoute(
    path: AppRouter.discoverySource,
    pageBuilder: (context, state) =>
        slideTransition(state, const DiscoverySourceScreen()),
  ),
];
