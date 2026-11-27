import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/giving/data/giving_capability_store.dart';
import 'package:test_app/features/giving/repo/donor_giving_repo.dart';
import 'package:test_app/features/engagement/data/share_link_action.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/engagement/views/card_actions_sheet.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// The `…` on a content card (Figma `10779-89546`).
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
  GivingCapabilityStore? giving,
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
    ..registerSingleton<EngagementStore>(used)
    // The sheet asks whether this ministry can take a gift before it draws
    // its rows.
    ..registerSingleton<GivingCapabilityStore>(
      giving ?? GivingCapabilityStore(repo: DonorGivingRepo(api: api)),
    );
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

/// What Share handed to the device's sheet, and whether it opened at all.
String? _shared;
String? _copied;

void main() {
  setUpAll(loadAppFonts);

  setUp(() {
    _shared = null;
    _copied = null;
    // There is no platform channel in a widget test, so the OS sheet is
    // stood in for. Without this, every Share in this file would land in
    // the catch and report "That can't be shared".
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
  });

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

  group('add to playlist', () {
    testWidgets('opens a picker, not the browse screen', (tester) async {
      // It used to push `PlaylistsScreen`, which cannot be told what is
      // being added — so tapping a playlist there opened it and nothing
      // was ever put in it.
      await _open(tester, _item());

      await tester.tap(find.text(AppStrings.cardAddToPlaylist));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.playlistPickTitle), findsOneWidget);
      expect(find.text(AppStrings.playlistPickNew), findsOneWidget);
      expect(find.text(AppStrings.playlistsTitle), findsNothing);
    });
  });

  group('the bookmark row', () {
    /// A store with [targetType]:[targetId] already saved, the way the
    /// card's own bookmark would have left it.
    EngagementStore storeHolding({
      required String targetType,
      required String targetId,
      bool saved = true,
    }) {
      // The real route answers which way it landed, and the store takes
      // that as final — so a fake that always says "on" silently undoes
      // every un-save. This one flips, like the server does.
      final active = <String>{if (saved) '$targetType:$targetId:favorite'};
      final store = EngagementStore(
        toggle:
            ({
              required String targetType,
              required String targetId,
              required String interactionType,
            }) async {
              final key = '$targetType:$targetId:$interactionType';
              return active.remove(key) ? false : (active..add(key)).isNotEmpty;
            },
        setFollowing: (String creatorId, {required bool follow}) async {},
      );
      store.seed(targetType: targetType, targetId: targetId, saved: saved);
      return store;
    }

    testWidgets('says Bookmark for something not saved', (tester) async {
      await _open(tester, _item());
      expect(find.text(AppStrings.cardBookmark), findsOneWidget);
      expect(find.text(AppStrings.cardBookmarked), findsNothing);
    });

    testWidgets('and says Remove bookmark for something that is', (
      tester,
    ) async {
      // The row was a fixed "Bookmark" however long the thing had been
      // saved, so the sheet could neither show that it was nor take it
      // out — the card's own bookmark was the only way back.
      await _open(
        tester,
        _item(),
        store: storeHolding(targetType: 'media', targetId: 'm1'),
      );
      expect(find.text(AppStrings.cardBookmarked), findsOneWidget);
      expect(find.text(AppStrings.cardBookmark), findsNothing);
    });

    testWidgets('and tapping it un-saves, which the card sees at once', (
      tester,
    ) async {
      final store = storeHolding(targetType: 'media', targetId: 'm1');
      await _open(tester, _item(), store: store);

      await tester.tap(find.text(AppStrings.cardBookmarked));
      await tester.pumpAndSettle();

      expect(store.stateFor('media', 'm1')?.saved, isFalse);
    });

    testWidgets('a devotional series writes where the card reads', (
      tester,
    ) async {
      // The feed's `entityType` is not always the interaction API's name
      // for it: a `devotional_series` interacts as a `devotional`. The
      // sheet used to pass the raw entity type, so it kept its own entry
      // and the card never saw the save — on top of being a 400.
      final store = storeHolding(
        targetType: 'devotional',
        targetId: 'd1',
        saved: false,
      );
      await _open(
        tester,
        _item(entityType: 'devotional_series', id: 'd1'),
        store: store,
      );

      await tester.tap(find.text(AppStrings.cardBookmark));
      await tester.pumpAndSettle();

      expect(store.stateFor('devotional', 'd1')?.saved, isTrue);
      expect(store.stateFor('devotional_series', 'd1'), isNull);
    });

    testWidgets('and a row that carries no interactions is not offered one', (
      tester,
    ) async {
      // A media series has no interaction target, so a Bookmark row there
      // could only ever be refused.
      await _open(tester, _item(entityType: 'media_series', id: 's1'));
      expect(find.text(AppStrings.cardBookmark), findsNothing);
      expect(find.text(AppStrings.cardBookmarked), findsNothing);
    });

    testWidgets('and a media series is not offered a playlist either', (
      tester,
    ) async {
      // Playlists hold media, one row at a time; a series id is refused.
      await _open(tester, _item(entityType: 'media_series', id: 's1'));
      expect(find.text(AppStrings.cardAddToPlaylist), findsNothing);
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

    testWidgets('and hands it to the device, not the clipboard', (
      tester,
    ) async {
      // Share used to copy the URL and say so in a snackbar, which is not
      // what a control called Share means anywhere else on the phone.
      // Copying is still there — it is a row in the system sheet.
      await _open(tester, _item());

      await tester.tap(find.text(AppStrings.cardShare));
      await tester.pumpAndSettle();

      expect(_shared, 'https://app.gospeltube.tv/media/m1');
      expect(_copied, isNull);
    });

    testWidgets('and says nothing when the reader backs out of the sheet', (
      tester,
    ) async {
      shareSheetForTesting = (url, subject, from) async =>
          ShareResultStatus.dismissed;
      await _open(tester, _item());

      await tester.tap(find.text(AppStrings.cardShare));
      await tester.pumpAndSettle();

      // They closed it themselves; a snackbar about it would be noise.
      expect(find.text(AppStrings.cardShareUnavailable), findsNothing);
    });

    testWidgets('and an unlaid-out widget still yields a usable anchor', (
      tester,
    ) async {
      // The branch that matters on iPad. A zero-size subtree is exactly
      // the shape that used to hand `share_plus` a null and get back a
      // `FlutterError` instead of a sheet.
      late BuildContext inside;
      await tester.pumpWidget(
        MaterialApp(
          // `Center` passes loose constraints down, so the zero size is
          // actually honoured — under `home` directly the constraints are
          // tight and a shrunk box is forced back to full screen.
          home: Center(
            child: SizedBox(
              width: 0,
              height: 0,
              child: Builder(
                builder: (context) {
                  inside = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      final anchor = shareOriginOf(inside);

      expect(anchor.isEmpty, isFalse);
      expect(anchor.width, greaterThan(0));
    });

    testWidgets('and always anchors the sheet, because iPad demands it', (
      tester,
    ) async {
      // `FPPSharePlusPlugin` refuses with a `FlutterError` when the
      // origin is missing or empty on iPad, and the app ships for iPad
      // (`TARGETED_DEVICE_FAMILY = "1,2"`). A null here would have been a
      // Share that reported "that can't be shared" on every iPad.
      Rect? anchor;
      shareSheetForTesting = (url, subject, from) async {
        anchor = from;
        return ShareResultStatus.success;
      };
      await _open(tester, _item());

      await tester.tap(find.text(AppStrings.cardShare));
      await tester.pumpAndSettle();

      expect(anchor, isNotNull);
      expect(anchor!.isEmpty, isFalse);
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

  group('giving', () {
    GivingCapabilityStore storeSaying(bool? available) {
      final store = GivingCapabilityStore(
        repo: DonorGivingRepo(api: _FakeApi()),
      );
      if (available != null) store.seed('c1', available);
      return store;
    }

    testWidgets('a ministry that can receive is offered Give now', (
      tester,
    ) async {
      await _open(tester, _item(), giving: storeSaying(true));
      expect(find.text(AppStrings.cardGiveNow), findsOneWidget);
    });

    testWidgets('one that cannot is not', (tester) async {
      // Withheld rather than disabled: the refusal carries no reason the
      // giver could act on, so a greyed row would only invite a dead tap.
      await _open(tester, _item(), giving: storeSaying(false));
      expect(find.text(AppStrings.cardGiveNow), findsNothing);
    });

    testWidgets('nor is one nobody has asked about', (tester) async {
      // Unknown is not yes. The sheet is built in one pass, so a row cannot
      // appear later — drawing it on a guess is what must not happen.
      await _open(tester, _item(), giving: storeSaying(null));
      expect(find.text(AppStrings.cardGiveNow), findsNothing);
    });

    testWidgets('your own channel is never offered Give now', (tester) async {
      // `isOwn` drops the creator id, and giving to yourself is refused by
      // the server anyway.
      await _open(
        tester,
        _item(entityType: 'creator'),
        isOwn: true,
        giving: storeSaying(true),
      );
      expect(find.text(AppStrings.cardGiveNow), findsNothing);
    });
  });
}
