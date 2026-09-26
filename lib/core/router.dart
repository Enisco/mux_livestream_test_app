import 'package:go_router/go_router.dart';

import 'package:test_app/core/routes/auth_routes.dart';
import 'package:test_app/core/routes/creator_routes.dart';
import 'package:test_app/core/routes/onboarding_routes.dart';
import 'package:test_app/core/routes/shell_routes.dart';
import 'package:test_app/shared/services/api_service.dart';

class AppRouter {
  AppRouter._();

  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';

  /// Finishing a reset. `?token=` is filled in by the emailed link; without
  /// one the screen asks the reader to paste the code.
  static const String resetPassword = '/reset-password';

  static String resetPasswordWithToken(String token) =>
      '$resetPassword?token=${Uri.encodeQueryComponent(token)}';
  static const String verifyEmail = '/verify-email';

  static const String welcomeNote = '/welcome-note';
  static const String roleSelection = '/role-selection';
  static const String interests = '/interests';
  static const String discoverySource = '/discovery-source';

  static const String creatorType = '/creator-type';
  static const String creatorSetup = '/creator-setup';
  static const String orgSetup = '/org-setup';
  static const String planSelection = '/plan-selection';
  static const String checkoutStatus = '/checkout-status';

  /// Everything after the plan is settled: the channel is live, then four
  /// optional steps that make it look like a channel.
  static const String creatorLive = '/creator-live';
  static const String creatorPhoto = '/creator-photo';
  static const String creatorBanner = '/creator-banner';
  static const String creatorBio = '/creator-bio';
  static const String creatorLinks = '/creator-links';

  /// The creator studio: dashboard, content, impact and giving.
  static const String studio = '/studio';
  static const String creatorProfile = '/creator';

  /// Profile by id — the form every in-app creator affordance uses.
  static String creatorProfileById(String id) => '/creator?id=$id';

  static String creatorProfileByHandle(String handle) =>
      '/creator?handle=${handle.replaceFirst('@', '')}';

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
