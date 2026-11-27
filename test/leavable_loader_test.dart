import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/leavable_loader.dart';
import 'helpers/load_app_fonts.dart';

Future<void> _pump(WidgetTester tester, {required bool pushed}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        home: pushed
            ? Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LeavableLoader(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              )
            : const LeavableLoader(),
      ),
    ),
  );
  if (pushed) {
    await tester.tap(find.text('open'));
    // Not `pumpAndSettle`: the loader spins and breathes forever, so
    // there is no settled state to wait for.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  setUpAll(loadAppFonts);

  /// A slow fetch used to be a dead screen: the logo, the spinner, and
  /// nothing to press.
  group('waiting for a page to load', () {
    testWidgets('offers a way back out of it', (tester) async {
      await _pump(tester, pushed: true);
      expect(find.byType(GTubeBackButton), findsOneWidget);
    });

    testWidgets('and the arrow actually leaves', (tester) async {
      await _pump(tester, pushed: true);

      await tester.tap(find.byType(GTubeBackButton));
      await tester.pump();
      // Long enough for the route's exit transition to finish; the
      // loader is still on screen part-way through it.
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LeavableLoader), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('but draws no arrow where there is nowhere to go', (
      tester,
    ) async {
      // A root tab is not something you back out of, and an arrow that
      // does nothing is worse than none.
      await _pump(tester, pushed: false);
      expect(find.byType(GTubeBackButton), findsNothing);
    });
  });

  /// Both of these screens had already learned this for their *failed*
  /// state and still shipped the same trap one state earlier, where the
  /// reader is far more likely to be sitting.
  group('the screens a content card opens', () {
    test('leave while they are still loading, not only once they fail', () {
      const screens = <String, (String, String)>{
        'lib/features/creator/views/creator_profile_screen.dart': (
          'a ministry page',
          'LeavableLoader',
        ),
        'lib/features/discovery/views/content_detail_screen.dart': (
          'a blog, devotional or event page',
          '_TopBar',
        ),
      };
      for (final entry in screens.entries) {
        final source = File(entry.key).readAsStringSync();
        final loading = source.indexOf('if (_loading) {');
        final branch = loading == -1
            // A one-line `if (_loading) return ...;`.
            ? source.substring(
                source.indexOf('if (_loading) return'),
                source.indexOf(';', source.indexOf('if (_loading) return')),
              )
            : source.substring(loading, loading + 400);
        expect(
          branch,
          contains(entry.value.$2),
          reason:
              '${entry.value.$1} strands the reader on a spinner with no '
              'way back while the fetch runs',
        );
      }
    });
  });
}
