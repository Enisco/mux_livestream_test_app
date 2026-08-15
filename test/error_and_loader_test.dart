import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/home/views/widgets/home_loader.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'helpers/load_app_fonts.dart';

const _devices = {'iPhone 15': Size(393, 852), 'small Android': Size(360, 640)};

Future<void> _pump(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = Size(size.width * 3, size.height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('error state', () {
    _devices.forEach((name, size) {
      testWidgets('lays out cleanly — $name', (tester) async {
        await _pump(tester, size, ErrorStateView(onRetry: () {}));
        expect(tester.takeException(), isNull);
        expect(find.text('Try again'), findsOneWidget);
      });
    });

    testWidgets('says what went wrong, not "failed to load video"', (
      tester,
    ) async {
      await _pump(tester, const Size(393, 852), ErrorStateView(onRetry: () {}));
      expect(find.text("That didn't load"), findsOneWidget);
      expect(find.text('Failed to load video'), findsNothing);
    });

    testWidgets('retry fires', (tester) async {
      var tapped = 0;
      await _pump(
        tester,
        const Size(393, 852),
        ErrorStateView(onRetry: () => tapped++),
      );
      await tester.tap(find.text('Try again'));
      expect(tapped, 1);
    });

    testWidgets('a screen can override the copy', (tester) async {
      await _pump(
        tester,
        const Size(393, 852),
        ErrorStateView(
          onRetry: () {},
          title: 'No comments loaded',
          body: 'We could not reach the thread.',
          retryLabel: 'Reload',
        ),
      );
      expect(find.text('No comments loaded'), findsOneWidget);
      expect(find.text('Reload'), findsOneWidget);
    });
  });

  group('loader', () {
    testWidgets('animates rather than sitting still', (tester) async {
      await _pump(tester, const Size(393, 852), const HomeLoader());
      // A running animation leaves the tester with pending frames.
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('disposes its controllers', (tester) async {
      await _pump(tester, const Size(393, 852), const HomeLoader());
      await tester.pump(const Duration(milliseconds: 200));
      await _pump(tester, const Size(393, 852), const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });
}
