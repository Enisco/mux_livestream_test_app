import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// Nobody gets stuck on a failure.
///
/// Reported from the app: opening a ministry's page whose data would not load
/// showed the error state *instead of the whole screen*, back arrow included.
/// Retry does not help when the content is simply gone, so the only way out
/// was to force-quit. The same shape existed on content detail.
///
/// The way out is decided here rather than screen by screen, so a screen
/// added later cannot reintroduce the trap by forgetting to pass anything.
Future<void> _pump(
  WidgetTester tester, {
  required bool pushed,
  bool? showBack,
  VoidCallback? onBack,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final view = ErrorStateView(
    onRetry: () {},
    showBack: showBack,
    onBack: onBack,
  );

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (context) => MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: pushed
                ? Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(body: view),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  )
                : view,
          ),
        ),
      ),
    ),
  );
  if (pushed) {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
  await tester.pumpAndSettle();
}

final _back = find.byKey(const ValueKey('error-go-back'));

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a pushed screen that fails offers a way back', (tester) async {
    await _pump(tester, pushed: true);
    expect(_back, findsOneWidget);
    expect(find.text(AppStrings.goBack), findsOneWidget);
  });

  testWidgets('and taking it actually leaves', (tester) async {
    await _pump(tester, pushed: true);
    await tester.tap(_back);
    await tester.pumpAndSettle();
    // Back on the page that opened it.
    expect(find.text('open'), findsOneWidget);
    expect(_back, findsNothing);
  });

  testWidgets('a tab body offers no back, because there is nowhere to go', (
    tester,
  ) async {
    // The home feed lives inside the shell; its nav bar is the way out.
    await _pump(tester, pushed: false);
    expect(_back, findsNothing);
  });

  testWidgets('retry is still the first thing offered', (tester) async {
    await _pump(tester, pushed: true);
    expect(find.text(AppStrings.feedRetry), findsOneWidget);
  });

  testWidgets('a screen can insist on a way out even where it cannot pop', (
    tester,
  ) async {
    var left = false;
    await _pump(
      tester,
      pushed: false,
      showBack: true,
      onBack: () => left = true,
    );
    expect(_back, findsOneWidget);
    await tester.tap(_back);
    await tester.pumpAndSettle();
    expect(left, isTrue);
  });

  testWidgets('and one can suppress it deliberately', (tester) async {
    await _pump(tester, pushed: true, showBack: false);
    expect(_back, findsNothing);
  });

  testWidgets('the whole state fits a small phone without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await _pump(tester, pushed: true);
    expect(tester.takeException(), isNull);
  });
}
