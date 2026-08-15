import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  group('back button', () {
    testWidgets('draws a HugeIcon, not an SVG', (tester) async {
      await _pump(tester, const GTubeBackButton());
      expect(find.byType(HugeIcon), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is smaller than the glyph it replaced', (tester) async {
      await _pump(tester, const GTubeBackButton());
      final icon = tester.widget<HugeIcon>(find.byType(HugeIcon));
      // The exported SVG drew a 20pt-wide arrow; the design reads better
      // with something that does not compete with the title beside it.
      expect(icon.size, lessThan(20));
    });

    testWidgets('keeps a 24pt tap target', (tester) async {
      await _pump(tester, const GTubeBackButton());
      final box = tester.getSize(find.byType(GTubeBackButton));
      expect(box.width, 24);
      expect(box.height, 24);
    });

    testWidgets('fires its own handler', (tester) async {
      var taps = 0;
      await _pump(tester, GTubeBackButton(onTap: () => taps++));
      await tester.tap(find.byType(GTubeBackButton));
      expect(taps, 1);
    });

    testWidgets('falls back to popping the route', (tester) async {
      await _pump(tester, const GTubeBackButton());
      await tester.tap(find.byType(GTubeBackButton));
      expect(tester.takeException(), isNull);
    });

    testWidgets('takes a colour', (tester) async {
      await _pump(tester, const GTubeBackButton(color: AppColors.brandPrimary));
      final icon = tester.widget<HugeIcon>(find.byType(HugeIcon));
      expect(icon.color, AppColors.brandPrimary);
    });
  });

  group('icon set', () {
    test('disclosure chevrons are real chevrons, not tailed arrows', () {
      expect(AppIcons.chevronDown, CupertinoIcons.chevron_down);
      expect(AppIcons.chevronRight, CupertinoIcons.chevron_forward);
    });

    testWidgets('a chevron renders as an Icon', (tester) async {
      await _pump(
        tester,
        const Icon(AppIcons.chevronDown, size: 12, color: AppColors.neutral400),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, CupertinoIcons.chevron_down);
      expect(icon.color, AppColors.neutral400);
    });

    testWidgets('ticks render and take their colour', (tester) async {
      await _pump(
        tester,
        const HugeIcon(
          icon: AppIcons.tick,
          color: AppColors.green500,
          size: 18,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<HugeIcon>(find.byType(HugeIcon)).color,
        AppColors.green500,
      );
    });
  });
}
