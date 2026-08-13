import 'package:go_router/go_router.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/core/transitions.dart';
import 'package:test_app/features/auth/views/forgot_password_screen.dart';
import 'package:test_app/features/auth/views/sign_in_screen.dart';
import 'package:test_app/features/auth/views/sign_up_screen.dart';
import 'package:test_app/features/auth/views/verify_email_screen.dart';
import 'package:test_app/features/auth/views/welcome_screen.dart';
import 'package:test_app/features/splash/views/splash_screen.dart';

final List<RouteBase> authRoutes = [
  GoRoute(
    path: AppRouter.splash,
    pageBuilder: (context, state) =>
        fadeTransition(state, const SplashScreen()),
  ),
  GoRoute(
    path: AppRouter.welcome,
    pageBuilder: (context, state) =>
        fadeTransition(state, const WelcomeScreen()),
  ),
  GoRoute(
    path: AppRouter.signIn,
    pageBuilder: (context, state) =>
        slideTransition(state, const SignInScreen()),
  ),
  GoRoute(
    path: AppRouter.signUp,
    pageBuilder: (context, state) =>
        slideTransition(state, const SignUpScreen()),
  ),
  GoRoute(
    path: AppRouter.forgotPassword,
    pageBuilder: (context, state) =>
        slideTransition(state, const ForgotPasswordScreen()),
  ),
  GoRoute(
    path: AppRouter.verifyEmail,
    pageBuilder: (context, state) {
      final params = state.uri.queryParameters;
      return slideTransition(
        state,
        VerifyEmailScreen(
          email: params['email'] ?? '',
          challengeId: params['challengeId'] ?? '',
        ),
      );
    },
  ),
];
