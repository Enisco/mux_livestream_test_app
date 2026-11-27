import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/discovery/views/widgets/detail_sections.dart';
import 'package:test_app/features/discovery/views/widgets/portrait_watch_view.dart';
import 'package:test_app/features/discovery/views/widgets/watch_rail.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  /// The toggle was drawn whatever the text was, so a one-line
  /// description offered to "Show more" and then showed the same line.
  group('the description panel', () {
    testWidgets('offers no Show more for something already fully shown', (
      tester,
    ) async {
      await _pump(
        tester,
        const DetailDescriptionCard(body: 'Patience is a Virtue'),
      );
      expect(find.text('Patience is a Virtue'), findsOneWidget);
      expect(find.text(AppStrings.showMore), findsNothing);
    });

    testWidgets('and offers it for something with more behind the fold', (
      tester,
    ) async {
      await _pump(
        tester,
        DetailDescriptionCard(body: List.filled(120, 'word').join(' ')),
      );
      expect(find.text(AppStrings.showMore), findsOneWidget);
    });

    testWidgets('and says Show less once it is open', (tester) async {
      await _pump(
        tester,
        DetailDescriptionCard(body: List.filled(120, 'word').join(' ')),
      );

      await tester.tap(find.text(AppStrings.showMore));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.showLess), findsOneWidget);
    });

    testWidgets('and an empty description offers nothing at all', (
      tester,
    ) async {
      await _pump(tester, const DetailDescriptionCard(body: ''));
      expect(find.text(AppStrings.showMore), findsNothing);
      expect(find.text(AppStrings.showLess), findsNothing);
    });
  });

  group('the watch rail', () {
    testWidgets('saves with the same glyph the feed cards use', (tester) async {
      // It was an `archive` box here and a bookmark on the card, so the
      // one control looked like two different actions.
      await _pump(
        tester,
        const WatchRailAction(asset: AppAssets.iconFeedBookmark, label: '1'),
      );

      final icons = tester
          .widgetList<DesignIcon>(find.byType(DesignIcon))
          .toList();
      expect(icons, isNotEmpty);
      expect(icons.every((i) => i.asset == AppAssets.iconFeedBookmark), isTrue);
    });
  });

  group('a sheet over the video', () {
    test('stops well short of swallowing it', () {
      // 0.92 left a sliver nobody could make anything of.
      expect(PortraitWatchView.sheetMax, lessThanOrEqualTo(0.7));
      expect(PortraitWatchView.sheetMax, greaterThanOrEqualTo(0.6));
    });

    test('and does not draw on the same black as the page behind it', () {
      expect(AppColors.sheetSurface, isNot(AppColors.base1));
    });
  });
}
