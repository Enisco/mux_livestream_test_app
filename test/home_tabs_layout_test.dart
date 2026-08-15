import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/home/views/widgets/empty_tab_views.dart';
import 'package:test_app/features/home/views/widgets/home_loader.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'helpers/load_app_fonts.dart';

const _devices = {
  'iPhone 15': Size(393, 852),
  'small Android': Size(360, 640),
  'Pixel tall': Size(411, 914),
};

final _creators = [
  const RecommendedCreator(
    creatorId: 'c1',
    displayName: 'Pastor Luke Cage',
    handle: 'lukecage',
    isVerified: true,
  ),
  const RecommendedCreator(
    creatorId: 'c2',
    displayName: 'CCI International Ministries Worldwide',
    handle: 'cciinternationalministries',
    isVerified: true,
  ),
  const RecommendedCreator(
    creatorId: 'c3',
    displayName: 'Grace',
    handle: 'grace',
  ),
];

final _events = [
  WebFeedItem.fromJson(const {
    'entityType': 'event',
    'entityId': 'e1',
    'title': 'Youth Conference',
    'calendarStartAt': '2026-06-12T09:00:00.000Z',
    'creator': {'displayName': 'CCI International', 'isVerified': true},
    'meta': {'locationLabel': 'River Worship'},
  }),
  WebFeedItem.fromJson(const {
    'entityType': 'event',
    'entityId': 'e2',
    'title':
        'An Unusually Long Conference Title That Should Wrap Onto Two Lines',
    'calendarStartAt': '2026-08-23T14:00:00.000Z',
    'creator': {'displayName': 'Art Fusion'},
    'meta': {'locationLabel': 'A Very Long Downtown Gallery Venue Name'},
  }),
  // No schedule and no venue — the row must still lay out.
  WebFeedItem.fromJson(const {
    'entityType': 'event',
    'entityId': 'e3',
    'title': 'To be announced',
    'creator': {'displayName': 'Global Tech Meet'},
    'meta': {},
  }),
];

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

  _devices.forEach((name, size) {
    testWidgets('following empty lays out cleanly — $name', (tester) async {
      await _pump(
        tester,
        size,
        FollowingEmptyView(
          suggestions: _creators,
          pending: const {'c2'},
          onFollow: (_) {},
          onOpenCreator: (_) {},
          onEditTopics: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text("You're not following anyone yet"), findsOneWidget);
      expect(find.text('Ministries to follow'), findsOneWidget);
      expect(find.text('Edit your topics'), findsOneWidget);
    });

    testWidgets('live empty lays out cleanly — $name', (tester) async {
      await _pump(
        tester,
        size,
        LiveEmptyView(events: _events, onOpenEvent: (_) {}, onMore: (_) {}),
      );
      expect(tester.takeException(), isNull);
      expect(find.text("No one's live right now"), findsOneWidget);
      expect(find.text('Upcoming events'), findsOneWidget);
    });
  });

  testWidgets('following empty survives having no suggestions', (tester) async {
    await _pump(
      tester,
      const Size(393, 852),
      FollowingEmptyView(
        suggestions: const [],
        pending: const {},
        onFollow: (_) {},
        onOpenCreator: (_) {},
        onEditTopics: () {},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Ministries to follow'), findsNothing);
  });

  testWidgets('live empty survives having no events', (tester) async {
    await _pump(
      tester,
      const Size(393, 852),
      LiveEmptyView(events: const [], onOpenEvent: (_) {}),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Upcoming events'), findsNothing);
  });

  testWidgets('a pending follow shows a spinner, not a label', (tester) async {
    await _pump(
      tester,
      const Size(393, 852),
      FollowingEmptyView(
        suggestions: _creators,
        pending: const {'c2'},
        onFollow: (_) {},
        onOpenCreator: (_) {},
        onEditTopics: () {},
      ),
    );
    // Three rows, one of them busy.
    expect(find.text('Follow'), findsNWidgets(2));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('the branded loader renders', (tester) async {
    await _pump(tester, const Size(393, 852), const HomeLoader());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  _creatorTapTests();
}

void _creatorTapTests() {
  group('creator affordances are wired', () {
    testWidgets('a suggestion row opens the creator', (tester) async {
      String? opened;
      await _pump(
        tester,
        const Size(393, 852),
        FollowingEmptyView(
          suggestions: _creators,
          pending: const {},
          onFollow: (_) {},
          onOpenCreator: (c) => opened = c.creatorId,
          onEditTopics: () {},
        ),
      );
      await tester.tap(find.text('Pastor Luke Cage'));
      expect(opened, 'c1');
    });

    testWidgets('following a row does not open the creator', (tester) async {
      String? opened;
      String? followed;
      await _pump(
        tester,
        const Size(393, 852),
        FollowingEmptyView(
          suggestions: _creators,
          pending: const {},
          onFollow: (c) => followed = c.creatorId,
          onOpenCreator: (c) => opened = c.creatorId,
          onEditTopics: () {},
        ),
      );
      await tester.tap(find.text('Follow').first);
      expect(followed, 'c1');
      expect(opened, isNull);
    });

    testWidgets('an event row opens its creator', (tester) async {
      String? opened;
      await _pump(
        tester,
        const Size(393, 852),
        LiveEmptyView(
          events: _events,
          onOpenEvent: (_) {},
          onOpenCreator: (e) => opened = e.entityId,
        ),
      );
      await tester.tap(find.text('CCI International'));
      expect(opened, 'e1');
    });
  });
}
