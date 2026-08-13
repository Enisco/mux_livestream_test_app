import 'package:go_router/go_router.dart';

import 'package:test_app/core/routes/auth_routes.dart';
import 'package:test_app/core/routes/creator_routes.dart';
import 'package:test_app/core/routes/onboarding_routes.dart';
import 'package:test_app/core/routes/shell_routes.dart';
import 'package:test_app/shared/services/api_service.dart';

/// Route paths. Route definitions live in `core/routes/*_routes.dart`.
class AppRouter {
  AppRouter._();

  // Auth
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  static const String verifyEmail = '/verify-email';

  // Onboarding
  static const String welcomeNote = '/welcome-note';
  static const String roleSelection = '/role-selection';
  static const String interests = '/interests';
  static const String discoverySource = '/discovery-source';

  // Creator
  static const String creatorType = '/creator-type';
  static const String creatorSetup = '/creator-setup';
  static const String orgSetup = '/org-setup';
  static const String planSelection = '/plan-selection';

  // Shell
  static const String home = '/home';
}

final appRouter = GoRouter(
  initialLocation: AppRouter.splash,
  routes: [
    ...authRoutes,
    ...onboardingRoutes,
    ...creatorRoutes,
    ...shellRoutes,
  ],
);

void setupSessionExpiredCallback() {
  ApiService.onSessionExpired = () => appRouter.go(AppRouter.signIn);
}
