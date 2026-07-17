import 'package:go_router/go_router.dart';

import '../features/auth/views/sign_in_screen.dart';
import '../features/auth/views/sign_up_screen.dart';
import '../features/splash/splash_screen.dart';
import '../screens/main_shell.dart';
import '../services/api_service.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const home = '/home';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.signIn,
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: AppRoutes.signUp,
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const MainShell(),
    ),
  ],
);

void setupSessionExpiredCallback() {
  ApiService.onSessionExpired = () => appRouter.go(AppRoutes.signIn);
}
