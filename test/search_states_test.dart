import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/discovery/data/recent_searches.dart';
import 'package:test_app/features/discovery/data/search_grouping.dart';
import 'package:test_app/features/discovery/data/search_query.dart';
import 'package:test_app/features/discovery/data/search_suggestions_dummy.dart';
import 'package:test_app/features/discovery/views/widgets/search_result_rows.dart';
import 'package:test_app/features/discovery/views/widgets/search_type_tabs.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

WebFeedItem _row({
  String entityType = 'media',
  String id = 'm-1',
  String title = 'Worship him',
  String? mediaType = 'video',
  int views = 12000,
  String creator = 'Grace Community',
  String? location,
  String? startsAt,
}) => WebFeedItem.fromJson({
  'entityType': entityType,
  'entityId': id,
  'title': title,
  'mediaType': mediaType,
  'creator': {
    'creatorId': 'c-1',
    'displayName': creator,
    'handle': 'grace',
    'isVerified': true,
  },
  'facets': {'analyticsViews': views, 'mediaType': mediaType},
  'meta': {
    'mediaType': mediaType,
    'publishedAt': '2020-01-01T00:00:00.000Z',
    // A creator row is the creator, so its handle and tick sit on meta rather
    // than on a nested creator object.
    'handle': 'grace',
    'isVerified': true,
    'locationLabel': ?location,
  },
  'calendarStartAt': ?startsAt,
});

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: Scaffold(backgroundColor: AppColors.base1, body: child),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('results are filed by kind', () {
    test('a creator row lands under ministries', () {
      expect(
        SearchGrouping.kindOf(_row(entityType: 'creator')),
        SearchGroupKind.ministries,
      );
    });

    test('a music row is audio, not video', () {
      // Both arrive as entityType "media"; only mediaType separates them.
      expect(
        SearchGrouping.kindOf(_row(mediaType: 'music')),
        SearchGroupKind.audio,
      );
      expect(
        SearchGrouping.kindOf(_row(mediaType: 'video')),
        SearchGroupKind.videos,
      );
    });

    test('devotional series and entries share one group', () {
      expect(
        SearchGrouping.kindOf(_row(entityType: 'devotional_series')),
        SearchGroupKind.devotionals,
      );
      expect(
        SearchGrouping.kindOf(_row(entityType: 'devotional_entry')),
        SearchGroupKind.devotionals,
      );
    });

    test('posts are blogs and events are events', () {
      expect(
        SearchGrouping.kindOf(_row(entityType: 'post')),
        SearchGroupKind.blogs,
      );
      expect(
        SearchGrouping.kindOf(_row(entityType: 'event')),
        SearchGroupKind.events,
      );
    });

    test('groups come back in a fixed order, ministries first', () {
      final groups = SearchGrouping.apply([
        _row(entityType: 'event', id: 'e'),
        _row(id: 'v'),
        _row(entityType: 'creator', id: 'c'),
      ]);

      expect(groups.map((g) => g.kind), [
        SearchGroupKind.ministries,
        SearchGroupKind.videos,
        SearchGroupKind.events,
      ]);
    });

    test('a kind with nothing in it is left out entirely', () {
      // Otherwise the screen draws a heading over empty space.
      final groups = SearchGrouping.apply([_row()]);
      expect(groups.length, 1);
      expect(groups.single.kind, SearchGroupKind.videos);
    });

    test('nothing in, nothing out', () {
      expect(SearchGrouping.apply(const []), isEmpty);
    });
  });

  group('recent searches', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
    });

    test('start empty', () {
      expect(RecentSearches.load(), isEmpty);
    });

    test('a term is remembered, newest first', () async {
      await RecentSearches.add('worship');
      await RecentSearches.add('prayer');
      expect(RecentSearches.load(), ['prayer', 'worship']);
    });

    test(
      'searching the same thing again moves it up, not duplicates it',
      () async {
        await RecentSearches.add('worship');
        await RecentSearches.add('prayer');
        await RecentSearches.add('WORSHIP');

        expect(RecentSearches.load(), ['WORSHIP', 'prayer']);
      },
    );

    test('blank input is not remembered', () async {
      await RecentSearches.add('   ');
      expect(RecentSearches.load(), isEmpty);
    });

    test('the list stops growing at the cap', () async {
      for (var i = 0; i < RecentSearches.max + 4; i++) {
        await RecentSearches.add('term $i');
      }
      expect(RecentSearches.load().length, RecentSearches.max);
      expect(RecentSearches.load().first, 'term 11');
    });

    test('one can be forgotten without losing the rest', () async {
      await RecentSearches.add('worship');
      await RecentSearches.add('prayer');

      await RecentSearches.remove('worship');

      expect(RecentSearches.load(), ['prayer']);
    });

    test('clearing empties it', () async {
      await RecentSearches.add('worship');
      await RecentSearches.clear();
      expect(RecentSearches.load(), isEmpty);
    });

    test('a corrupt entry reads as empty rather than throwing', () async {
      await LocalStorage.setString('gtube_recent_searches', 'not json');
      expect(RecentSearches.load(), isEmpty);
    });
  });

  group('autocomplete', () {
    test('offers nothing for an empty query', () {
      expect(SearchSuggestions.forQuery('  '), isEmpty);
    });

    test('a prefix match is ranked above a mere contains', () {
      // Someone typing "wor" means "worship" far more often than the phrase
      // that merely contains "wor" in "word".
      final hits = SearchSuggestions.forQuery('wor');
      expect(hits.first, startsWith('wor'));
      expect(hits, contains('worship songs'));
    });

    test('matching is case-insensitive', () {
      expect(SearchSuggestions.forQuery('WORSHIP'), isNotEmpty);
    });

    test('a query nothing matches offers nothing', () {
      expect(SearchSuggestions.forQuery('zzzzz'), isEmpty);
    });

    test('the list is capped', () {
      expect(SearchSuggestions.forQuery('a', limit: 2).length, lessThan(3));
    });
  });

  group('the type tabs', () {
    testWidgets('offer the seven kinds the design draws', (tester) async {
      // Wide enough that the horizontal list builds every tab; on a phone the
      // row scrolls and the last ones are off-screen by design.
      await _pump(
        tester,
        SearchTypeTabs(selected: SearchFilter.all, onSelected: (_) {}),
        width: 900,
      );

      for (final label in [
        'All',
        'Creators',
        'Audio',
        'Videos',
        'Devotionals',
        'Blogs',
        'Events',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('live and series are not among them', (tester) async {
      // They are reachable from Home; crowding them in here would push the
      // useful ones off the row.
      await _pump(
        tester,
        SearchTypeTabs(selected: SearchFilter.all, onSelected: (_) {}),
      );
      expect(find.text('Live'), findsNothing);
      expect(find.text('Series'), findsNothing);
    });

    testWidgets('tapping one reports it', (tester) async {
      SearchFilter? picked;
      await _pump(
        tester,
        SearchTypeTabs(
          selected: SearchFilter.all,
          onSelected: (f) => picked = f,
        ),
        width: 900,
      );

      await tester.tap(find.text('Events'));
      await tester.pump();

      expect(picked, SearchFilter.events);
    });
  });

  group('result rows', () {
    testWidgets('a ministry row shows the handle and a follow action', (
      tester,
    ) async {
      var follows = 0;
      await _pump(
        tester,
        SearchMinistryRow(
          item: _row(entityType: 'creator', title: 'River Worship'),
          following: false,
          onFollow: () => follows++,
        ),
      );

      expect(find.text('River Worship'), findsOneWidget);
      expect(find.text('@grace'), findsOneWidget);

      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(follows, 1);
    });

    testWidgets('an already-followed ministry says so', (tester) async {
      await _pump(
        tester,
        SearchMinistryRow(item: _row(entityType: 'creator'), following: true),
      );
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
    });

    testWidgets('a content row reads kind, views and age', (tester) async {
      await _pump(tester, SearchContentRow(item: _row(), kindLabel: 'Video'));

      expect(find.text('Worship him'), findsOneWidget);
      expect(find.textContaining('Video'), findsOneWidget);
      expect(find.textContaining('12K views'), findsOneWidget);
    });

    testWidgets('a row with no views does not print a bare zero', (
      tester,
    ) async {
      await _pump(
        tester,
        SearchContentRow(item: _row(views: 0), kindLabel: 'Video'),
      );
      expect(find.textContaining('0 views'), findsNothing);
    });

    testWidgets('an event row prints its date tile and venue', (tester) async {
      await _pump(
        tester,
        SearchEventRow(
          item: _row(
            entityType: 'event',
            title: 'Night of Worship',
            location: 'River Worship',
            startsAt: '2026-06-12T09:00:00.000Z',
          ),
        ),
      );

      expect(find.text('Night of Worship'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('JUN'), findsOneWidget);
      expect(find.text('River Worship'), findsOneWidget);
      expect(find.text('RSVP'), findsOneWidget);
    });

    testWidgets('a recent row can be run or forgotten independently', (
      tester,
    ) async {
      var ran = 0;
      var forgot = 0;
      await _pump(
        tester,
        RecentSearchRow(
          term: 'night of worship',
          onTap: () => ran++,
          onRemove: () => forgot++,
        ),
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(forgot, 1);
      expect(ran, 0, reason: 'removing must not also run the search');

      await tester.tap(find.text('night of worship'));
      await tester.pump();
      expect(ran, 1);
    });

    testWidgets('a suggestion can be run or lifted into the field', (
      tester,
    ) async {
      var ran = 0;
      var filled = 0;
      await _pump(
        tester,
        SearchSuggestionRow(
          phrase: 'worship songs',
          onTap: () => ran++,
          onFill: () => filled++,
        ),
      );

      await tester.tap(find.text('worship songs'));
      await tester.pump();
      expect(ran, 1);
      expect(filled, 0);
    });
  });
}
