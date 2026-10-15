import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/discovery/views/content_detail_screen.dart';
import 'package:test_app/features/discovery/views/media_series_screen.dart';
import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/history/views/history_screen.dart';
import 'package:test_app/features/library/repo/playlist_repo.dart';
import 'package:test_app/features/library/repo/viewer_library_repo.dart';
import 'package:test_app/features/library/repo/viewer_records_repo.dart';
import 'package:test_app/features/library/views/liked_saved_screens.dart';
import 'package:test_app/features/library/views/my_events_screen.dart';
import 'package:test_app/features/library/views/playlist_detail_screen.dart';
import 'package:test_app/features/library/views/records_screens.dart';
import 'package:test_app/features/creator/views/widgets/creator_profile_parts.dart'
    show CreatorTab;
import 'package:test_app/shared/components/content_list_row.dart';
import 'package:test_app/shared/services/analytics_service.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// Tapping a library row must open the thing it is a picture of.
///
/// Every one of these screens used to answer a tap with a snackbar saying the
/// row's own title "is not built yet", because the row models kept only the
/// fields the design draws and threw away the entity type and id a detail
/// screen is opened by. The rows are enriched search hits, so the hit is now
/// carried whole — and these pin both halves: that the mappers keep it, and
/// that each screen's tap uses it.
///
/// The fixtures use `media_series` rows deliberately: the series screen is the
/// cheapest destination to let build, so a test can assert the push landed
/// rather than only that a snackbar was absent.

class _NoopAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Without a fake, the real one reaches for a platform channel these tests do
/// not have and throws, which silently aborts a destination screen's init.
class _SignedIn implements TokenStorageService {
  @override
  Future<bool> get hasSession async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeApi implements ApiService {
  _FakeApi({
    this.items = const [],
    this.events = const [],
    this.prayers = const [],
    this.testimonies = const [],
    this.playlistIds = const [],
  });

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> prayers;
  final List<Map<String, dynamic>> testimonies;
  final List<String> playlistIds;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path.contains('calendar/events/mine')) {
      return _ok(path, {'data': events});
    }
    if (path.contains('prayers/mine')) return _ok(path, {'items': prayers});
    if (path.contains('testimonies/mine')) {
      return _ok(path, {'items': testimonies});
    }
    if (path.contains('playlists/')) {
      return _ok(path, {
        'id': 'p1',
        'title': 'Sunday set',
        'orderedMediaIds': playlistIds,
        'itemCount': playlistIds.length,
        // Hydrated by the server since 2026-10-15 — the client no longer
        // runs a second search over the ids.
        'items': [
          for (final id in playlistIds)
            ...items.where((h) => h['entityId'] == id),
        ],
      });
    }
    // History, liked and saved all answer the same enriched-hit envelope.
    return _ok(path, {'items': items, 'total': items.length});
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    // The playlist's running order is hydrated through one search.
    if (path.contains('search')) return _ok(path, {'hits': items});
    return _ok(path, const <String, dynamic>{});
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async => _ok(path, const <String, dynamic>{});

  Response<T> _ok<T>(String path, Object body) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: {'data': body} as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// One enriched search hit, as history, liked, saved and a playlist all send.
Map<String, dynamic> _hit({
  String id = 'm1',
  String title = 'Romans, chapter',
  String entityType = 'media_series',
  String? mediaType = 'video',
  int? progressPercent,
}) => {
  'entityType': entityType,
  'entityId': id,
  'title': title,
  'historyTargetType': 'media',
  'engagementTargetType': 'media',
  'viewedAt': DateTime.now().toUtc().toIso8601String(),
  'interactionAt': DateTime.now().toUtc().toIso8601String(),
  'completed': false,
  // A search hit keys its creator `id`, not `creatorId` — verified against
  // staging. Carrying both here hid the fact that nothing read `id`.
  'creator': {'id': 'c1', 'displayName': 'Grace Community', 'handle': 'grace'},
  'facets': {'mediaType': mediaType, 'analyticsViews': 12},
  'meta': {'durationSeconds': 600.0, 'progressPercent': progressPercent},
};

Map<String, dynamic> _eventRow() => {
  'event': {
    'id': 'e1',
    'title': 'Night of worship',
    'calendarStartAt': DateTime.now()
        .add(const Duration(days: 3))
        .toIso8601String(),
    'location': {'label': 'Main hall'},
    'creator': {'id': 'c1', 'displayName': 'Grace Community'},
  },
  'rsvp': {'status': 'attending'},
};

Map<String, dynamic> _prayerRow({Map<String, dynamic>? contentRef}) => {
  'id': 'pr1',
  'creatorId': 'c1',
  'body': 'Please pray for my mother.',
  'status': 'open',
  'createdAt': DateTime.now().toUtc().toIso8601String(),
  'contentRef': contentRef,
  'creator': {'id': 'c1', 'displayName': 'Grace Community'},
};

Map<String, dynamic> _testimonyRow({String status = 'approved'}) => {
  'id': 't1',
  'creatorId': 'c1',
  'body': 'God healed my mother.',
  'status': status,
  'impactTags': const ['healing'],
  'createdAt': DateTime.now().toUtc().toIso8601String(),
  'creator': {'id': 'c1', 'displayName': 'Grace Community'},
};

Future<void> _pump(
  WidgetTester tester,
  _FakeApi api,
  Widget child, {
  Size size = const Size(390, 1400),
}) async {
  GetIt.instance
    ..allowReassignment = true
    ..registerSingleton<ApiService>(api)
    ..registerSingleton<DiscoveryRepo>(DiscoveryRepo())
    ..registerSingleton<EngagementRepo>(EngagementRepo())
    ..registerSingleton<EngagementStore>(EngagementStore())
    ..registerSingleton<TokenStorageService>(_SignedIn())
    ..registerSingleton<AnalyticsService>(_NoopAnalytics());
  addTearDown(GetIt.instance.reset);

  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (_) => MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('the mappers keep what a tap needs', () {
    test('a history row carries the hit it came from', () {
      final entry = ViewerLibraryRepo.debugMap([_hit()]).single;
      expect(entry.source, isNotNull);
      // The entity type is the whole point: it is what decides which detail
      // screen opens, and it is not derivable from the fields on the row.
      expect(entry.source!.entityType, 'media_series');
      expect(entry.source!.entityId, 'm1');
    });

    test('a playlist item carries it too', () async {
      final api = _FakeApi(items: [_hit()], playlistIds: const ['m1']);
      final playlist = await PlaylistRepo(api: api).fetch('p1');
      expect(playlist.items.single.source?.entityId, 'm1');
      // A search hit keys its creator `id`, not `creatorId`; reading only
      // the latter left the click beacon with no creator attributed.
      expect(playlist.items.single.source?.creator?.creatorId, 'c1');
    });

    test('an event carries its identity and its type', () async {
      final api = _FakeApi(events: [_eventRow()]);
      final event = (await ViewerRecordsRepo(api: api).fetchMyEvents()).single;
      expect(event.source?.entityType, 'event');
      expect(event.source?.entityId, 'e1');
    });

    test('a prayer carries what it was asked about', () async {
      final api = _FakeApi(
        prayers: [
          _prayerRow(
            contentRef: const {
              'targetType': 'media_series',
              'targetId': 'm1',
              'title': 'Romans, chapter',
              'mediaType': 'video',
            },
          ),
        ],
      );
      final prayer = (await ViewerRecordsRepo(
        api: api,
      ).fetchMyPrayers()).single;
      expect(prayer.aboutItem?.entityId, 'm1');
      expect(prayer.aboutItem?.entityType, 'media_series');
    });

    test('one asked of the ministry itself has nothing to open', () async {
      final api = _FakeApi(prayers: [_prayerRow()]);
      final prayer = (await ViewerRecordsRepo(
        api: api,
      ).fetchMyPrayers()).single;
      expect(prayer.aboutItem, isNull);
    });

    test('nor does one whose content has since gone', () async {
      // A ref with no title is how the server says the content was deleted or
      // made private. Opening it would 404.
      final api = _FakeApi(
        prayers: [
          _prayerRow(
            contentRef: const {'targetType': 'media', 'targetId': 'm1'},
          ),
        ],
      );
      final prayer = (await ViewerRecordsRepo(
        api: api,
      ).fetchMyPrayers()).single;
      expect(prayer.aboutGone, isTrue);
      expect(prayer.aboutItem, isNull);
    });

    test('a testimony carries whose wall it is on', () async {
      final api = _FakeApi(testimonies: [_testimonyRow()]);
      final row = (await ViewerRecordsRepo(
        api: api,
      ).fetchMyTestimonies()).single;
      expect(row.creatorId, 'c1');
    });
  });

  group('tapping a row opens it', () {
    testWidgets('in History', (tester) async {
      final api = _FakeApi(items: [_hit()]);
      await _pump(
        tester,
        api,
        HistoryScreen(repo: ViewerLibraryRepo(api: api)),
      );

      await tester.tap(find.byType(ContentListRow).first);
      await tester.pumpAndSettle();

      expect(find.byType(MediaSeriesScreen), findsOneWidget);
      expect(find.textContaining('is not built yet'), findsNothing);
    });

    testWidgets('on the History resume rail', (tester) async {
      final api = _FakeApi(items: [_hit(progressPercent: 40)]);
      await _pump(
        tester,
        api,
        HistoryScreen(repo: ViewerLibraryRepo(api: api)),
      );

      // The rail card, not the row below it.
      await tester.tap(find.text('Romans, chapter').first);
      await tester.pumpAndSettle();

      expect(find.byType(MediaSeriesScreen), findsOneWidget);
    });

    testWidgets('in Liked', (tester) async {
      final api = _FakeApi(items: [_hit()]);
      await _pump(tester, api, LikedScreen(repo: ViewerLibraryRepo(api: api)));

      await tester.tap(find.byType(ContentListRow).first);
      await tester.pumpAndSettle();

      expect(find.byType(MediaSeriesScreen), findsOneWidget);
    });

    testWidgets('in Saved', (tester) async {
      final api = _FakeApi(items: [_hit()]);
      await _pump(tester, api, SavedScreen(repo: ViewerLibraryRepo(api: api)));

      await tester.tap(find.byType(ContentListRow).first);
      await tester.pumpAndSettle();

      expect(find.byType(MediaSeriesScreen), findsOneWidget);
    });

    testWidgets('in a playlist', (tester) async {
      final api = _FakeApi(items: [_hit()], playlistIds: const ['m1']);
      await _pump(
        tester,
        api,
        PlaylistDetailScreen(
          playlist: await PlaylistRepo(api: api).fetch('p1'),
          repo: PlaylistRepo(api: api),
        ),
      );

      await tester.tap(find.byType(ContentListRow).first);
      await tester.pumpAndSettle();

      expect(find.byType(MediaSeriesScreen), findsOneWidget);
    });

    testWidgets('and in My events', (tester) async {
      final api = _FakeApi(events: [_eventRow()]);
      await _pump(
        tester,
        api,
        MyEventsScreen(repo: ViewerRecordsRepo(api: api)),
      );

      await tester.tap(find.text('Night of worship'));
      await tester.pumpAndSettle();

      expect(find.textContaining('is not built yet'), findsNothing);
      // An event opens the shared non-media detail screen, not the media
      // aggregate, which 404s on one.
      final detail = tester.widget<ContentDetailScreen>(
        find.byType(ContentDetailScreen),
      );
      expect(detail.kind, ContentDetailKind.event);
      expect(detail.item.entityId, 'e1');
    });
  });

  group('a row with nothing behind it says so', () {
    testWidgets('rather than answering a tap with silence', (tester) async {
      // No `entityId` is how a degraded hit arrives. The row stays, because it
      // is a true record of what was watched, but there is nothing to open.
      final api = _FakeApi(
        items: [
          {
            'entityType': 'media',
            'title': 'Romans, chapter',
            'historyTargetType': 'media',
            'viewedAt': DateTime.now().toUtc().toIso8601String(),
            'facets': const <String, dynamic>{},
            'meta': const <String, dynamic>{},
          },
        ],
      );
      await _pump(
        tester,
        api,
        HistoryScreen(repo: ViewerLibraryRepo(api: api)),
      );

      await tester.tap(find.byType(ContentListRow).first);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.libraryRowGone), findsOneWidget);
    });
  });

  group('the prayer and testimony menus', () {
    testWidgets('Go to content opens what the request was about', (
      tester,
    ) async {
      final api = _FakeApi(
        prayers: [
          _prayerRow(
            contentRef: const {
              'targetType': 'media_series',
              'targetId': 'm1',
              'title': 'Romans, chapter',
              'mediaType': 'video',
            },
          ),
        ],
      );
      await _pump(
        tester,
        api,
        PrayerRequestsScreen(repo: ViewerRecordsRepo(api: api)),
      );

      await tester.tap(find.byKey(const ValueKey('more-pr1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.prayerActionGoToContent));
      await tester.pumpAndSettle();

      expect(find.byType(MediaSeriesScreen), findsOneWidget);
      expect(find.textContaining('is not built yet'), findsNothing);
    });

    testWidgets('View on wall opens the ministry on its testimonies', (
      tester,
    ) async {
      final api = _FakeApi(testimonies: [_testimonyRow()]);
      GetIt.instance
        ..allowReassignment = true
        ..registerSingleton<ApiService>(api)
        ..registerSingleton<DiscoveryRepo>(DiscoveryRepo())
        ..registerSingleton<AnalyticsService>(_NoopAnalytics());
      // `EngagementStore`'s default constructor resolves repos eagerly.
      addTearDown(GetIt.instance.reset);

      tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      // Only where the push landed matters, so the destination is a stub.
      String? landed;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                TestimoniesScreen(repo: ViewerRecordsRepo(api: api)),
          ),
          GoRoute(
            path: AppRouter.creatorProfile,
            builder: (_, state) {
              landed = state.uri.toString();
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          respectSystemFontScale: false,
          builder: (_) => MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('more-t1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.testimonyActionView));
      await tester.pumpAndSettle();

      expect(landed, contains('id=c1'));
      expect(landed, contains('tab=testimonies'));
    });
  });

  group('the tab a link asks for', () {
    test('survives the URL', () {
      expect(
        AppRouter.creatorProfileById('c1', tab: CreatorTab.testimonies.name),
        '/creator?id=c1&tab=testimonies',
      );
    });

    test('is absent when none was asked for', () {
      expect(AppRouter.creatorProfileById('c1'), '/creator?id=c1');
    });

    test('and a name that is not a tab is ignored rather than thrown', () {
      // It arrives from a URL, which anything can write.
      expect(CreatorTab.byName('testimonies'), CreatorTab.testimonies);
      expect(CreatorTab.byName('nonsense'), isNull);
      expect(CreatorTab.byName(null), isNull);
    });
  });
}
