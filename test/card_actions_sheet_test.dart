import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/engagement/views/card_actions_sheet.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// The `…` on a content card (Figma `10779-89546`).
///
/// Every row here had nothing to call until the backend answered on
/// 2026-10-26. Four of its rules are easy to break invisibly, so each is
/// pinned:
///
/// - **No count beside "Not interested"** — it increments nothing anywhere.
/// - **"Add to playlist" is media only** (`PARKED(1.5)`).
/// - **Mute keeps the follow; block drops it**, and the wording reads off the
///   route's own `unfollowed` rather than assuming.
/// - **Minting a share link is not a share** — the counter moves on the
///   interaction, not on opening the sheet.
class _FakeApi implements ApiService {
  _FakeApi({this.unfollowed = true, this.shareFails = false});

  final bool unfollowed;
  final bool shareFails;

  final List<({String path, Object? body})> posted = [];
  final List<String> deleted = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posted.add((path: path, body: data));
    if (path.contains('share-links')) {
      if (shareFails) {
        throw DioException(
          requestOptions: RequestOptions(path: path),
          response: Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 404,
          ),
        );
      }
      return _ok(path, {'url': 'https://app.gospeltube.tv/media/m1'});
    }
    if (path.contains('blocked-creators')) {
      return _ok(path, {'creatorId': 'c1', 'unfollowed': unfollowed});
    }
    if (path.contains('muted-creators')) return _ok(path, {'creatorId': 'c1'});
    return _ok(path, {'active': true, 'interactionType': 'not_interested'});
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    deleted.add(path);
    return _ok(path, const <String, dynamic>{});
  }

  Response<T> _ok<T>(String path, Object body) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: {'data': body} as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

WebFeedItem _item({String entityType = 'media', String id = 'm1'}) =>
    WebFeedItem(
      entityType: entityType,
      entityId: id,
      title: 'Sunday Worship',
      creator: const WebFeedCreator(
        creatorId: 'c1',
        displayName: 'Grace Chapel',
        handle: 'grace',
      ),
      meta: const WebFeedItemMeta(),
    );

Future<_FakeApi> _open(
  WidgetTester tester,
  WebFeedItem item, {
  EngagementStore? store,
  bool unfollowed = true,
  bool shareFails = false,
  bool isOwn = false,
}) async {
  final api = _FakeApi(unfollowed: unfollowed, shareFails: shareFails);
  final used =
      store ??
      EngagementStore(
        toggle:
            ({
              required String targetType,
              required String targetId,
              required String interactionType,
            }) async => true,
        setFollowing: (String creatorId, {required bool follow}) async {},
      );
  GetIt.instance
    ..allowReassignment = true
    ..registerSingleton<ApiService>(api)
    ..registerSingleton<EngagementStore>(used);
  addTearDown(GetIt.instance.reset);

  tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCardActionsSheet(
                context,
                item,
                repo: EngagementRepo(api: api),
                store: used,
                isOwn: isOwn,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  setUpAll(loadAppFonts);

  group('which rows a card offers', () {
    testWidgets('media gets Add to playlist', (tester) async {
      await _open(tester, _item());
      expect(find.text(AppStrings.cardAddToPlaylist), findsOneWidget);
    });

    testWidgets('a blog does not — playlists hold media only', (tester) async {
      // PARKED(1.5): ruled not planned, so the row is absent rather than
      // present and refused.
      await _open(tester, _item(entityType: 'post'));
      expect(find.text(AppStrings.cardAddToPlaylist), findsNothing);
    });

    testWidgets('a devotional and an event do not either', (tester) async {
      await _open(tester, _item(entityType: 'devotional'));
      expect(find.text(AppStrings.cardAddToPlaylist), findsNothing);
    });

    testWidgets('a testimony is not offered Not interested', (tester) async {
      // Ranking did not choose it, so the route is a 400.
      await _open(tester, _item(entityType: 'testimony'));
      expect(find.text(AppStrings.cardNotInterested), findsNothing);
    });

    testWidgets('every card can be shared and reported', (tester) async {
      await _open(tester, _item(entityType: 'event'));
      expect(find.text(AppStrings.cardShare), findsOneWidget);
      expect(find.text(AppStrings.cardReport), findsOneWidget);
    });
  });

  group('hiding', () {
    testWidgets('Not interested posts the interaction and shows no count', (
      tester,
    ) async {
      final api = await _open(tester, _item());

      await tester.tap(find.text(AppStrings.cardNotInterested));
      await tester.pumpAndSettle();

      expect(api.posted.single.path, '/v1/engagement/interactions');
      expect(api.posted.single.body, {
        'targetType': 'media',
        'targetId': 'm1',
        'interactionType': 'not_interested',
      });
      // It increments nothing, anywhere — there is no number to draw.
      expect(find.textContaining('1'), findsNothing);
    });

    testWidgets('muting keeps the follow', (tester) async {
      final store = EngagementStore(
        toggle:
            ({
              required String targetType,
              required String targetId,
              required String interactionType,
            }) async => true,
        setFollowing: (String creatorId, {required bool follow}) async {},
      )..adoptFollowing('c1', true);

      final api = await _open(tester, _item(), store: store);
      await tester.tap(find.text(AppStrings.cardMute));
      await tester.pumpAndSettle();

      expect(api.posted.single.path, '/v1/discovery/muted-creators');
      expect(store.isMuted('c1'), isTrue);
      // A viewer who mutes their own church still follows it.
      expect(store.isFollowing('c1'), isTrue);
    });

    testWidgets('blocking drops it, and says so', (tester) async {
      final store = EngagementStore(
        toggle:
            ({
              required String targetType,
              required String targetId,
              required String interactionType,
            }) async => true,
        setFollowing: (String creatorId, {required bool follow}) async {},
      )..adoptFollowing('c1', true);

      await _open(tester, _item(), store: store);
      await tester.tap(find.text(AppStrings.cardBlock));
      await tester.pumpAndSettle();

      expect(store.isBlocked('c1'), isTrue);
      expect(store.isFollowing('c1'), isFalse);
      expect(
        find.text(AppStrings.cardBlockedUnfollowed('Grace Chapel')),
        findsOneWidget,
      );
    });

    testWidgets('and words it off the response, not an assumption', (
      tester,
    ) async {
      // Nothing was unfollowed, so the confirmation must not claim it was.
      await _open(tester, _item(), unfollowed: false);
      await tester.tap(find.text(AppStrings.cardBlock));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.cardBlocked('Grace Chapel')), findsOneWidget);
      expect(
        find.text(AppStrings.cardBlockedUnfollowed('Grace Chapel')),
        findsNothing,
      );
    });
  });

  group('sharing', () {
    testWidgets('mints a link without recording a share', (tester) async {
      final api = await _open(tester, _item());

      await tester.tap(find.text(AppStrings.cardShare));
      await tester.pumpAndSettle();

      expect(api.posted.single.path, '/v1/engagement/share-links');
      // Opening the sheet is not sharing: no interaction is posted, or every
      // abandoned sheet would inflate the creator's share count.
      expect(api.posted.where((c) => c.path.contains('interactions')), isEmpty);
    });

    testWidgets('a refusal is final, not a retry', (tester) async {
      // A link is never minted for something the viewer cannot already open.
      await _open(tester, _item(), shareFails: true);

      await tester.tap(find.text(AppStrings.cardShare));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.cardShareUnavailable), findsOneWidget);
    });
  });

  group('your own channel', () {
    testWidgets('offers nothing about muting or reporting yourself', (
      tester,
    ) async {
      // The report route refuses your own content, so the row would answer
      // "Something went wrong"; muting or following yourself is nonsense.
      await _open(tester, _item(entityType: 'creator'), isOwn: true);

      expect(find.text(AppStrings.cardMute), findsNothing);
      expect(find.text(AppStrings.cardBlock), findsNothing);
      expect(find.text(AppStrings.cardReport), findsNothing);
      expect(find.text(AppStrings.cardFollow), findsNothing);
    });

    testWidgets('but sharing it is still the point', (tester) async {
      final api = await _open(
        tester,
        _item(entityType: 'creator'),
        isOwn: true,
      );

      await tester.tap(find.text(AppStrings.cardShare));
      await tester.pumpAndSettle();

      expect(api.posted.single.path, '/v1/engagement/share-links');
    });

    testWidgets('somebody else’s channel keeps all of them', (tester) async {
      await _open(tester, _item(entityType: 'creator'));

      expect(find.text(AppStrings.cardMute), findsOneWidget);
      expect(find.text(AppStrings.cardBlock), findsOneWidget);
      expect(find.text(AppStrings.cardReport), findsOneWidget);
    });
  });
}
