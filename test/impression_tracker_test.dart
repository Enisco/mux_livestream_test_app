import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:test_app/features/analytics/views/widgets/promoted_impression_tracker.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/shared/services/analytics_service.dart';

/// Counts beacons without touching the network.
class SpyAnalytics implements AnalyticsService {
  final List<String> impressions = [];
  final List<String> paid = [];

  @override
  void trackImpression({
    required String mediaId,
    required String creatorId,
    String? contentType,
    String? mediaType,
    String source = AnalyticsSource.unknown,
  }) => impressions.add(mediaId);

  @override
  void trackPromotedQualifiedImpression({
    required String mediaId,
    required String creatorId,
    String? mediaType,
    required String source,
    required PromotionAttribution promotion,
    required int visibleDurationMs,
  }) => paid.add(mediaId);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _dwell = Duration(milliseconds: 20);

/// Puts [child] on screen, or [offset] pixels below it when pushed away.
///
/// Deliberately not inside a scroll view: `VisibilityDetector` does not report
/// through one under `flutter_test`, which would make these tests measure the
/// harness rather than the widget.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool offscreen = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Offstage(offstage: offscreen, child: child),
      ),
    ),
  );
  await tester.pump();
}

PromotedImpressionTracker _tracker({
  String mediaId = 'm1',
  PromotionAttribution? promotion,
}) => PromotedImpressionTracker(
  promotion: promotion,
  mediaId: mediaId,
  creatorId: 'c1',
  source: AnalyticsSource.homeFeed,
  dwell: _dwell,
  child: const SizedBox(height: 200, width: 200),
);

void main() {
  late SpyAnalytics spy;

  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  setUp(() {
    spy = SpyAnalytics();
    GetIt.instance.registerSingleton<AnalyticsService>(spy);
  });

  tearDown(GetIt.instance.reset);

  group('feed impressions', () {
    testWidgets('a card that dwells on screen is reported once', (
      tester,
    ) async {
      await _pump(tester, _tracker());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // ignore: avoid_print
      print(
        'DEBUG hits=${spy.impressions} registered=${GetIt.instance.isRegistered<AnalyticsService>()}',
      );
      expect(spy.impressions, ['m1']);

      // Staying on screen must not report it again.
      await tester.pump(const Duration(milliseconds: 200));
      expect(spy.impressions, ['m1']);
    });

    testWidgets('an organic card sends no paid impression', (tester) async {
      await _pump(tester, _tracker());
      await tester.pump(const Duration(milliseconds: 50));

      // Billing organic content would be fabricating a delivery.
      expect(spy.paid, isEmpty);
      expect(spy.impressions, ['m1']);
    });

    testWidgets('a promoted card sends both, organic first', (tester) async {
      await _pump(
        tester,
        _tracker(
          promotion: const PromotionAttribution(
            campaignId: 'camp1',
            placement: PromotionPlacement.catalogue,
            deliveryId: 'del1',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(spy.impressions, ['m1']);
      expect(spy.paid, ['m1']);
    });

    testWidgets('a card that is never painted is never reported', (
      tester,
    ) async {
      await _pump(tester, _tracker(), offscreen: true);
      await tester.pump(const Duration(milliseconds: 200));

      expect(spy.impressions, isEmpty);
    });

    testWidgets('leaving before the dwell reports nothing', (tester) async {
      await _pump(tester, _tracker());
      // Gone again before the dwell elapses.
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump(const Duration(milliseconds: 200));

      expect(spy.impressions, isEmpty);
    });

    testWidgets('a recycled row reports its new target too', (tester) async {
      await _pump(tester, _tracker());
      await tester.pump(const Duration(milliseconds: 50));
      expect(spy.impressions, ['m1']);

      // The list reused this element for a different row.
      await _pump(tester, _tracker(mediaId: 'm2'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(spy.impressions, ['m1', 'm2']);
    });

    testWidgets('disabled means nothing is watched at all', (tester) async {
      await _pump(
        tester,
        PromotedImpressionTracker(
          promotion: null,
          mediaId: 'm1',
          creatorId: 'c1',
          source: AnalyticsSource.homeFeed,
          dwell: _dwell,
          enabled: false,
          child: const SizedBox(height: 200, width: 200),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(spy.impressions, isEmpty);
      expect(find.byType(VisibilityDetector), findsNothing);
    });
  });
}
