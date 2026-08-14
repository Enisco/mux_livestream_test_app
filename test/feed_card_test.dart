import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'helpers/load_app_fonts.dart';

/// Rules taken from the Card comp variants in Figma — see docs/CLAUDE.md.
FeedCardData _data(FeedCardKind kind) => FeedCardData(
  id: '1',
  kind: kind,
  creatorName: 'Petra CC',
  handle: '@petraccinternational',
  age: '4h',
  title: 'Sunday Service: Walking by Faith',
  body: 'Prayer points for this week are up.',
  verified: true,
  likes: 12900,
  saves: 200,
  comments: 35,
  views: '12.9K',
  viewCount: 12900,
);

Future<void> _pump(WidgetTester tester, FeedCardKind kind) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: FeedCard(data: _data(kind))),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('views label', () {
    testWidgets('live counts watchers', (tester) async {
      await _pump(tester, FeedCardKind.live);
      expect(find.text('12.9K Watching'), findsOneWidget);
    });

    testWidgets('blog counts opens', (tester) async {
      await _pump(tester, FeedCardKind.blog);
      expect(find.text('12.9K Opens'), findsOneWidget);
    });

    testWidgets('video counts views', (tester) async {
      await _pump(tester, FeedCardKind.video);
      expect(find.text('12.9K Views'), findsOneWidget);
    });
  });

  group('post card', () {
    testWidgets('has no comment action', (tester) async {
      await _pump(tester, FeedCardKind.post);
      expect(find.text('35'), findsNothing);
    });

    testWidgets('other kinds keep it', (tester) async {
      await _pump(tester, FeedCardKind.video);
      expect(find.text('35'), findsOneWidget);
    });
  });

  group('live card', () {
    testWidgets('shows the LIVE badge', (tester) async {
      await _pump(tester, FeedCardKind.live);
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('other kinds do not', (tester) async {
      await _pump(tester, FeedCardKind.video);
      expect(find.text('LIVE'), findsNothing);
    });
  });
}
