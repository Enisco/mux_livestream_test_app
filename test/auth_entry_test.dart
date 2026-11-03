import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_app/features/auth/views/sign_in_screen.dart';
import 'package:test_app/features/auth/views/sign_up_screen.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_theme.dart';
import 'helpers/load_app_fonts.dart';

/// Getting between the three auth screens.
///
/// Reported from the app: sign-in had no way to create an account beyond a
/// 16pt link tucked under the title, and the sign-up screen's back button
/// did nothing — `context.pop()` against a screen that was navigated to
/// rather than pushed is a no-op, the same fault the creator polish chain
/// had.
///
/// Nothing here calls the gateway; the fake exists only because `AuthRepo`
/// resolves its dependencies in its field initialisers.
class _FakeApi implements ApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<GoRouter> _pump(
  WidgetTester tester,
  String at, {
  Size size = const Size(390, 1400),
}) async {
  await GetIt.instance.reset();
  GetIt.instance
    ..registerSingleton<ApiService>(_FakeApi())
    ..registerSingleton<TokenStorageService>(TokenStorageService());
  addTearDown(GetIt.instance.reset);

  tester.view.physicalSize = Size(size.width * 3, size.height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: at,
    routes: [
      GoRoute(
        path: AppRouter.welcome,
        builder: (_, _) => const Text('AUTH LANDING'),
      ),
      GoRoute(path: AppRouter.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: AppRouter.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: AppRouter.forgotPassword,
        builder: (_, _) => const Text('FORGOT'),
      ),
    ],
  );
  await tester.pumpWidget(
    BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(),
      child: SizingBuilder(
        baseSize: const Size(390, 844),
        respectSystemFontScale: false,
        builder: (context) =>
            MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _where(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  setUpAll(loadAppFonts);

  group('from sign-in, when the reader has no account', () {
    testWidgets('a control of its own says so, not just a link', (
      tester,
    ) async {
      await _pump(tester, AppRouter.signIn);

      expect(find.text(AppStrings.newHereSignUp), findsOneWidget);
    });

    testWidgets('it opens the sign-up form', (tester) async {
      final router = await _pump(tester, AppRouter.signIn);

      await tester.tap(find.byKey(const ValueKey('sign-in-sign-up')));
      await tester.pumpAndSettle();

      expect(_where(router), AppRouter.signUp);
      expect(find.byKey(const ValueKey('sign-up-back')), findsOneWidget);
    });

    testWidgets('and so does the link under the title', (tester) async {
      // It used to answer with the auth landing, which is not what a
      // control labelled "Sign up" promises.
      final router = await _pump(tester, AppRouter.signIn);

      await tester.tap(find.byKey(const ValueKey('sign-in-sign-up-link')));
      await tester.pumpAndSettle();

      expect(_where(router), AppRouter.signUp);
    });

    testWidgets('and the short phones still fit it on', (tester) async {
      // Sign-in is centred and scrollable, but a control added below the
      // fold is the usual way that stops being true.
      await _pump(tester, AppRouter.signIn, size: const Size(320, 568));

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.newHereSignUp), findsOneWidget);
    });
  });

  group('backing out of sign-up', () {
    testWidgets('reaches the auth landing when there is nothing to pop', (
      tester,
    ) async {
      final router = await _pump(tester, AppRouter.signUp);

      await tester.tap(find.byKey(const ValueKey('sign-up-back')));
      await tester.pumpAndSettle();

      expect(_where(router), AppRouter.welcome);
      expect(find.text('AUTH LANDING'), findsOneWidget);
    });

    testWidgets('and still returns where it was pushed from', (tester) async {
      // The landing pushes it, and that reader should go back to the
      // carousel they came from rather than have it rebuilt under them.
      final router = await _pump(tester, AppRouter.welcome);
      router.push(AppRouter.signUp);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('sign-up-back')));
      await tester.pumpAndSettle();

      expect(_where(router), AppRouter.welcome);
      expect(find.text('AUTH LANDING'), findsOneWidget);
    });
  });
}
