import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/views/studio_content_detail_screen.dart';
import 'package:test_app/models/creator_models/studio_content_models.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

Future<void> _pump(
  WidgetTester tester,
  StudioContentItem item, {
  Size size = const Size(390, 900),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) =>
          MaterialApp(home: StudioContentDetailScreen(item: item)),
    ),
  );
  await tester.pump();
}

StudioContentItem _media({
  String type = 'video',
  int views = 1204,
  int? duration = 2538,
}) => StudioContentItem.fromMedia({
  'id': 'm1',
  'type': type,
  'title': 'The Prodigal Returns',
  'status': 'published',
  'visibility': 'public',
  'durationSeconds': duration,
  'analyticsViews': views,
  'engagementLikeCount': 36,
  'engagementCommentCount': 86000,
  'categorySlugs': ['bible-study'],
  'publishedAt': '2026-06-06T00:00:00.000Z',
});

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a video names itself, its figures and its web-only edit', (
    tester,
  ) async {
    await _pump(tester, _media());

    expect(find.text(AppStrings.contentKindVideo), findsOneWidget);
    expect(find.text('The Prodigal Returns'), findsOneWidget);
    expect(find.textContaining('Published Jun 6'), findsOneWidget);
    expect(find.text(AppStrings.studioViews), findsOneWidget);
    expect(find.text('1.2K'), findsOneWidget);
    expect(find.text('42:18'), findsOneWidget);
    expect(find.text(AppStrings.contentEditOnWeb), findsOneWidget);
  });

  testWidgets('a livestream is titled and counted as a broadcast', (
    tester,
  ) async {
    await _pump(tester, _media(type: 'livestream'));

    expect(find.text(AppStrings.contentKindLivestream), findsOneWidget);
    // A broadcast is never presented as an upload.
    expect(find.text(AppStrings.contentKindVideo), findsNothing);
    expect(find.text(AppStrings.contentWatchedLiveLabel), findsOneWidget);
    expect(find.text(AppStrings.studioViews), findsNothing);
    expect(find.text(AppStrings.contentEditOnWeb), findsNothing);
    expect(find.text(AppStrings.contentManageOnWeb), findsOneWidget);
  });

  testWidgets('a slug is shown as words, not as a slug', (tester) async {
    await _pump(tester, _media());
    expect(find.textContaining('Bible study'), findsOneWidget);
  });

  testWidgets('audio counts plays and manages on the web', (tester) async {
    await _pump(tester, _media(type: 'music'));

    expect(find.text(AppStrings.contentKindAudio), findsOneWidget);
    expect(find.text(AppStrings.contentPlaysLabel), findsOneWidget);
    expect(find.text(AppStrings.contentManageOnWeb), findsOneWidget);
    expect(find.text(AppStrings.studioViews), findsNothing);
  });

  testWidgets('a post counts reads', (tester) async {
    await _pump(
      tester,
      StudioContentItem.fromPost({
        'id': 'p1',
        'title': 'Why We Fast Before Easter',
        'status': 'published',
        'visibility': 'public',
        'analyticsViews': 1204,
        'publishedAt': '2026-06-03T00:00:00.000Z',
      }),
    );

    expect(find.text(AppStrings.contentKindPost), findsOneWidget);
    expect(find.text(AppStrings.contentReadsLabel), findsOneWidget);
  });

  testWidgets('an event leads with when and where, and counts those going', (
    tester,
  ) async {
    await _pump(
      tester,
      StudioContentItem.fromEvent({
        'id': 'e1',
        'title': 'Midweek Prayer Vigil',
        'status': 'published',
        'visibility': 'public',
        'attendingCount': 3240,
        'engagementLikeCount': 36,
        'engagementCommentCount': 86000,
        'startAt': '2026-06-10T18:30:00.000Z',
        'location': {'label': 'Grace Chapel, Ikeja'},
      }),
    );

    expect(find.text(AppStrings.contentKindEvent), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('JUN'), findsOneWidget);
    expect(find.textContaining('Grace Chapel, Ikeja'), findsOneWidget);
    expect(find.text(AppStrings.contentGoingLabel), findsOneWidget);
    expect(find.text('3.2K'), findsOneWidget);
    // An event has no view count of its own, so that card is not drawn.
    expect(find.text(AppStrings.studioViews), findsNothing);
  });

  testWidgets('no figure claims a change it cannot prove', (tester) async {
    // The deltas in the design come from a Pro-only analytics route.
    await _pump(tester, _media());
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('sharing says plainly that there is no link yet', (tester) async {
    await _pump(tester, _media());

    await tester.tap(find.byKey(const ValueKey('detail-copy-link')));
    await tester.pump();
    expect(find.text(AppStrings.contentNoPublicLink), findsOneWidget);
  });

  testWidgets('nothing overflows on a narrow phone', (tester) async {
    await _pump(tester, _media(), size: const Size(320, 1200));
    expect(tester.takeException(), isNull);
  });
}
