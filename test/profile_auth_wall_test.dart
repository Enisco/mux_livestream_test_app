import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/landing/views/widgets/profile_auth_wall.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_theme.dart';
import 'helpers/load_app_fonts.dart';

/// The You tab a reader sees before they have signed in.
///
/// It was the last piece of the old design left in a screen the app actually
/// renders: legacy palette, raw `TextStyle`s and unscaled padding inside the
/// new shell. These hold it to the new design system and to the two ways out
/// it has to offer, and they sweep the sizes where a pitch like this breaks.
Future<GoRouter> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = Size(size.width * 3, size.height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ProfileAuthWall()),
      GoRoute(path: AppRouter.signIn, builder: (_, _) => const Text('SIGN IN')),
      GoRoute(
        path: AppRouter.welcome,
        builder: (_, _) => const Text('WELCOME'),
      ),
    ],
  );
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (context) =>
          MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Every colour the wall paints, so a legacy token cannot creep back in.
Set<Color> _colours(WidgetTester tester) => {
  for (final t in tester.widgetList<Text>(find.byType(Text))) ?t.style?.color,
  for (final i in tester.widgetList<Icon>(find.byType(Icon))) ?i.color,
};

void main() {
  setUpAll(loadAppFonts);

  testWidgets('it pitches an account and offers both ways in', (tester) async {
    await _pump(tester, const Size(390, 844));

    expect(find.text(AppStrings.authWallTitle), findsOneWidget);
    expect(find.text(AppStrings.authWallSubtitle), findsOneWidget);
    for (final feature in [
      AppStrings.authWallFollow,
      AppStrings.authWallSave,
      AppStrings.authWallRecommend,
      AppStrings.authWallGoLive,
    ]) {
      expect(find.text(feature), findsOneWidget);
    }
    expect(find.text(AppStrings.signIn), findsOneWidget);
    expect(find.text(AppStrings.createAccount), findsOneWidget);
  });

  testWidgets('signing in goes to sign-in', (tester) async {
    await _pump(tester, const Size(390, 844));
    await tester.tap(find.text(AppStrings.signIn));
    await tester.pumpAndSettle();
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets('creating an account goes to the welcome walk', (tester) async {
    await _pump(tester, const Size(390, 844));
    await tester.tap(find.text(AppStrings.createAccount));
    await tester.pumpAndSettle();
    expect(find.text('WELCOME'), findsOneWidget);
  });

  testWidgets('it is written in the new palette, not the legacy one', (
    tester,
  ) async {
    await _pump(tester, const Size(390, 844));

    final retired = <Color>{
      AppColors.primary,
      AppColors.surface,
      AppColors.surfaceVariant,
      AppColors.background,
      AppColors.textSecondary,
      AppColors.textTertiary,
    };
    expect(_colours(tester).intersection(retired), isEmpty);
    // And the accent it does use is the new brand orange.
    expect(_colours(tester), contains(AppColors.brandPrimary));
  });

  testWidgets('every string comes from AppStrings', (tester) async {
    await _pump(tester, const Size(390, 844));
    // Nothing hardcoded: the wall used to carry its own copy inline.
    expect(find.text('Watch. Follow. Create.'), findsOneWidget);
    expect(find.text('GTube'), findsNothing);
  });

  group('it lays out without overflowing', () {
    for (final size in const [
      Size(320, 568), // the smallest phone still supported
      Size(360, 640),
      Size(390, 844),
      Size(430, 932),
      Size(360, 480), // a short window, where the pitch has to scroll
    ]) {
      testWidgets('at ${size.width.toInt()}×${size.height.toInt()}', (
        tester,
      ) async {
        await _pump(tester, size);
        expect(tester.takeException(), isNull);
        // Still reachable by scrolling, however short the window.
        await tester.scrollUntilVisible(
          find.text(AppStrings.createAccount),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(AppStrings.createAccount), findsOneWidget);
      });
    }
  });
}
