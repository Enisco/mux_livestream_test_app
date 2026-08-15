import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/landing/views/widgets/gtube_nav_bar.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'helpers/load_app_fonts.dart';

Future<void> _pump(WidgetTester tester, int index) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: GTubeNavBar(index: index, onChanged: (_) {}),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Set<String> _assets(WidgetTester tester) => tester
    .widgetList<DesignIcon>(find.byType(DesignIcon))
    .map((e) => e.asset)
    .toSet();

void main() {
  setUpAll(loadAppFonts);

  group('selected tab', () {
    testWidgets('explore swaps to the filled glyph', (tester) async {
      await _pump(tester, 1);
      expect(_assets(tester), contains(AppAssets.iconNavExploreBold));
      expect(_assets(tester), isNot(contains(AppAssets.iconNavExplore)));
    });

    testWidgets('explore uses the outline glyph when idle', (tester) async {
      await _pump(tester, 0);
      expect(_assets(tester), contains(AppAssets.iconNavExplore));
      expect(_assets(tester), isNot(contains(AppAssets.iconNavExploreBold)));
    });

    testWidgets('following swaps to the filled glyph', (tester) async {
      await _pump(tester, 2);
      expect(_assets(tester), contains(AppAssets.iconNavFollowingBold));
      expect(_assets(tester), isNot(contains(AppAssets.iconNavFollowing)));
    });

    testWidgets('home keeps one drawing in both states', (tester) async {
      await _pump(tester, 0);
      expect(_assets(tester), contains(AppAssets.iconNavHome));
      await _pump(tester, 3);
      expect(_assets(tester), contains(AppAssets.iconNavHome));
    });
  });

  group('pill', () {
    /// The design centres the pill on the icon, not on the icon+label block.
    testWidgets('sits over the icon, not the label', (tester) async {
      await _pump(tester, 0);
      final pill = tester.getRect(find.byType(AnimatedPositioned).first);
      final icon = tester.getRect(find.byType(DesignIcon).first);
      final label = tester.getRect(find.text('Home'));
      expect(
        (pill.center.dy - icon.center.dy).abs(),
        lessThan(2),
        reason: 'pill should be centred on the icon',
      );
      expect(
        pill.bottom,
        lessThan(label.center.dy),
        reason: 'pill should not sit behind the label',
      );
    });

    testWidgets('is wider for Following, as designed', (tester) async {
      await _pump(tester, 1);
      final explore = tester.getRect(find.byType(AnimatedPositioned).first);
      await _pump(tester, 2);
      final following = tester.getRect(find.byType(AnimatedPositioned).first);
      expect(following.width, greaterThan(explore.width));
    });

    testWidgets('is centred on the selected item', (tester) async {
      for (final index in [0, 1, 2, 3]) {
        await _pump(tester, index);
        final pill = tester.getRect(find.byType(AnimatedPositioned).first);
        final item = tester.getRect(find.byType(GestureDetector).at(index));
        expect(
          (pill.center.dx - item.center.dx).abs(),
          lessThan(2),
          reason: 'pill should centre on item $index',
        );
      }
    });
  });
}
