import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/profile/data/profile_dummy_data.dart';
import 'package:test_app/features/profile/views/widgets/profile_header_card.dart';
import 'package:test_app/features/profile/views/widgets/profile_menu.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'helpers/load_app_fonts.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.base1,
          body: Padding(padding: const EdgeInsets.all(15), child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The alert dot, told apart from the avatar by being the only small circle.
Iterable<Container> _dots(WidgetTester tester) =>
    tester.widgetList<Container>(find.byType(Container)).where((c) {
      final shape = (c.decoration as BoxDecoration?)?.shape;
      final width = c.constraints?.maxWidth ?? 0;
      return shape == BoxShape.circle && width > 0 && width <= 12;
    });

void main() {
  setUpAll(loadAppFonts);

  group('the profile card', () {
    testWidgets('names the reader and their handle', (tester) async {
      await _pump(
        tester,
        const ProfileHeaderCard(name: 'Ayomide John', handle: '@emekamusa'),
      );

      expect(find.text('Ayomide John'), findsOneWidget);
      expect(find.textContaining('@emekamusa · Account info'), findsOneWidget);
    });

    testWidgets('a reader with no handle still gets the way in', (
      tester,
    ) async {
      // The handle is derived from an email and can be missing; the link to
      // account settings must not disappear with it.
      await _pump(tester, const ProfileHeaderCard(name: 'Ayomide John'));

      expect(find.textContaining('Account info'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('the bell carries a dot only when there is something to see', (
      tester,
    ) async {
      await _pump(
        tester,
        const ProfileHeaderCard(name: 'A', hasNotifications: false),
      );
      expect(_dots(tester), isEmpty);

      await _pump(
        tester,
        const ProfileHeaderCard(name: 'A', hasNotifications: true),
      );
      expect(_dots(tester), hasLength(1));
    });

    testWidgets('the bell is tappable without opening the profile', (
      tester,
    ) async {
      var opened = 0;
      var bell = 0;
      await _pump(
        tester,
        ProfileHeaderCard(
          name: 'Ayomide John',
          hasNotifications: true,
          onTap: () => opened++,
          onNotifications: () => bell++,
        ),
      );

      await tester.tap(find.byType(HugeIcon));
      await tester.pump();

      expect(bell, 1);
      expect(opened, 0);
    });
  });

  group('continue watching', () {
    testWidgets('shows what is left of it', (tester) async {
      await _pump(
        tester,
        const ContinueWatchingCard(progress: ProfileDummyData.lastWatched),
      );

      expect(find.text('The Prodigal Returns'), findsOneWidget);
      expect(find.text('Grace Community'), findsOneWidget);
      expect(find.text('24m remaining'), findsOneWidget);
    });

    testWidgets('the bar reflects how far in the reader got', (tester) async {
      await _pump(
        tester,
        const ContinueWatchingCard(progress: ProfileDummyData.lastWatched),
      );

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(0.67, 0.001));
    });

    testWidgets('a fraction outside 0-1 cannot overrun the bar', (
      tester,
    ) async {
      await _pump(
        tester,
        const ContinueWatchingCard(
          progress: ProfileWatchProgress(
            mediaId: 'm',
            title: 'Overrun',
            creatorName: 'C',
            fraction: 1.8,
            remainingLabel: '0m',
          ),
        ),
      );

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, 1);
    });
  });

  group('a menu row', () {
    testWidgets('draws its label and reports taps', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        ProfileMenuItem(
          icon: HugeIcons.strokeRoundedClock01,
          label: 'History',
          onTap: () => taps++,
        ),
      );

      expect(find.text('History'), findsOneWidget);
      await tester.tap(find.text('History'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a note rides beside the label', (tester) async {
      await _pump(
        tester,
        const ProfileMenuItem(
          icon: HugeIcons.strokeRoundedVideo01,
          label: 'Become a creator',
          note: 'Start your channel',
        ),
      );

      expect(find.text('Become a creator'), findsOneWidget);
      expect(find.text('Start your channel'), findsOneWidget);
    });

    testWidgets('a count pill appears only when there is a count', (
      tester,
    ) async {
      await _pump(
        tester,
        const ProfileMenuItem(
          icon: HugeIcons.strokeRoundedCalendar03,
          label: 'My events',
        ),
      );
      expect(find.textContaining('Upcoming'), findsNothing);

      await _pump(
        tester,
        const ProfileMenuItem(
          icon: HugeIcons.strokeRoundedCalendar03,
          label: 'My events',
          pill: '2 Upcoming',
        ),
      );
      expect(find.text('2 Upcoming'), findsOneWidget);
    });

    testWidgets('an avatar can stand in for the glyph', (tester) async {
      // The studio row leads with the channel's own picture.
      await _pump(
        tester,
        const ProfileMenuItem(
          leading: ColoredBox(color: AppColors.brandPrimary),
          label: 'Celebration Centre International',
          tag: 'Streamer',
        ),
      );

      expect(find.text('Celebration Centre International'), findsOneWidget);
      expect(find.text('Streamer'), findsOneWidget);
    });
  });

  group('a menu section', () {
    testWidgets('captions its rows', (tester) async {
      await _pump(
        tester,
        const ProfileMenuSection(
          caption: 'ACCOUNT',
          children: [
            ProfileMenuItem(
              icon: HugeIcons.strokeRoundedSettings01,
              label: 'Settings',
            ),
            ProfileMenuItem(
              icon: HugeIcons.strokeRoundedLogout01,
              label: 'Sign out',
            ),
          ],
        ),
      );

      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('the rule under a section can be dropped', (tester) async {
      await _pump(
        tester,
        const ProfileMenuSection(
          caption: 'ACCOUNT',
          showDivider: false,
          children: [
            ProfileMenuItem(
              icon: HugeIcons.strokeRoundedSettings01,
              label: 'Settings',
            ),
          ],
        ),
      );

      final box = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('ACCOUNT'),
              matching: find.byType(Container),
            )
            .last,
      );
      expect((box.decoration as BoxDecoration?)?.border, isNull);
    });
  });
}
