import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/shared/services/api_service.dart';

import 'package:test_app/features/creator/views/studio_content_detail_screen.dart';
import 'package:test_app/models/creator_models/studio_content_models.dart';
import 'package:test_app/features/engagement/data/share_link_action.dart';
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
  String status = 'published',
  int views = 1204,
  int? duration = 2538,
}) => StudioContentItem.fromMedia({
  'id': 'm1',
  'type': type,
  'title': 'The Prodigal Returns',
  'status': status,
  'visibility': 'public',
  'durationSeconds': duration,
  'analyticsViews': views,
  'engagementLikeCount': 36,
  'engagementCommentCount': 86000,
  'categorySlugs': ['bible-study'],
  'publishedAt': '2026-06-06T00:00:00.000Z',
});

const _shareUrl = 'https://gospeltube.tv/w/abc?analyticsSource=share_link';

/// What the share mint put on the clipboard.
String? _copied;

/// What the Share button handed to the device's sheet.
String? _shared;

class _FakeShareApi implements ApiService {
  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data:
        {
              'data': {'url': _shareUrl},
            }
            as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a video names itself, its figures and its own editor', (
    tester,
  ) async {
    await _pump(tester, _media());

    expect(find.text(AppStrings.contentKindVideo), findsOneWidget);
    expect(find.text('The Prodigal Returns'), findsOneWidget);
    expect(find.textContaining('Published Jun 6'), findsOneWidget);
    expect(find.text(AppStrings.studioViews), findsOneWidget);
    expect(find.text('1.2K'), findsOneWidget);
    expect(find.text('42:18'), findsOneWidget);
    // `PATCH /v1/media/{id}` exists, so this is no longer a trip to a
    // desktop — the row offers Edit and says what the phone covers.
    expect(find.byKey(const ValueKey('detail-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-manage-web')), findsNothing);
    expect(find.text(AppStrings.contentMediaEditNote), findsOneWidget);
  });

  testWidgets('an archived video is not offered to anyone', (tester) async {
    await _pump(tester, _media(status: 'archived'));

    expect(find.byKey(const ValueKey('detail-edit')), findsNothing);
    expect(find.byKey(const ValueKey('detail-manage-web')), findsOneWidget);
    expect(find.text(AppStrings.editMediaNotEditable), findsOneWidget);
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
    expect(find.byKey(const ValueKey('detail-edit')), findsNothing);
    expect(find.text(AppStrings.contentManageOnWeb), findsOneWidget);
    expect(find.text(AppStrings.contentMediaEditWeb), findsOneWidget);
  });

  testWidgets('a slug is shown as words, not as a slug', (tester) async {
    await _pump(tester, _media());
    expect(find.textContaining('Bible study'), findsOneWidget);
  });

  testWidgets('audio counts plays and is edited here too', (tester) async {
    await _pump(tester, _media(type: 'music'));

    expect(find.text(AppStrings.contentKindAudio), findsOneWidget);
    expect(find.text(AppStrings.contentPlaysLabel), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-edit')), findsOneWidget);
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

  group('sharing a row of your own', () {
    setUp(() {
      _copied = null;
      _shared = null;
      // No platform channel in a test, so the sheet is stood in for.
      shareSheetForTesting = (url, subject, from) async {
        _shared = url;
        return ShareResultStatus.success;
      };
      addTearDown(() => shareSheetForTesting = null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              _copied = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      GetIt.instance.registerSingleton<EngagementRepo>(
        EngagementRepo(api: _FakeShareApi()),
      );
      addTearDown(GetIt.instance.reset);
    });

    testWidgets('a published row mints a real link', (tester) async {
      await _pump(tester, _media());

      await tester.tap(find.byKey(const ValueKey('detail-copy-link')));
      await tester.pumpAndSettle();

      // The handler used to report "no shareable link" for everything, and
      // wrote an empty string over whatever the creator had copied.
      expect(_copied, _shareUrl);
      expect(find.text(_shareUrl), findsOneWidget);
    });

    testWidgets('and the big Share button opens the device sheet', (
      tester,
    ) async {
      await _pump(tester, _media());

      await tester.tap(find.text(AppStrings.contentShare));
      await tester.pumpAndSettle();

      // Both buttons used to copy, so the one marked Share did not share.
      // Copy link still copies; Share hands the link to the OS.
      expect(_shared, _shareUrl);
      expect(_copied, isNull);
    });

    testWidgets('a draft says to publish it first, and copies nothing', (
      tester,
    ) async {
      await _pump(tester, _media(status: 'draft'));

      await tester.tap(find.byKey(const ValueKey('detail-copy-link')));
      await tester.pumpAndSettle();

      // There is a share route; what a draft lacks is a public page for it
      // to point at. Minting one would hand over a dead URL.
      expect(find.text(AppStrings.contentNotPublicYet), findsOneWidget);
      expect(_copied, isNull);
      expect(_shared, isNull);
    });
  });

  testWidgets('nothing overflows on a narrow phone', (tester) async {
    await _pump(tester, _media(), size: const Size(320, 1200));
    expect(tester.takeException(), isNull);
  });
}
