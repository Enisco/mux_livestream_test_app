import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/discovery/data/search_query.dart';
import 'package:test_app/features/discovery/views/widgets/search_result_rows.dart';
import 'package:test_app/features/discovery/views/widgets/search_type_tabs.dart';
import 'package:test_app/features/explore/data/explore_dummy_data.dart';
import 'package:test_app/features/explore/views/widgets/explore_cards.dart';
import 'package:test_app/features/explore/views/widgets/explore_category_chips.dart';
import 'package:test_app/features/explore/views/widgets/explore_creator_card.dart';
import 'package:test_app/features/explore/views/widgets/explore_event_row.dart';
import 'package:test_app/features/explore/views/widgets/explore_hero.dart';
import 'package:test_app/features/explore/views/widgets/explore_rail.dart';
import 'package:test_app/features/history/views/widgets/history_parts.dart';
import 'package:test_app/features/profile/data/profile_dummy_data.dart';
import 'package:test_app/features/profile/views/widgets/profile_header_card.dart';
import 'package:test_app/features/profile/views/widgets/profile_menu.dart';
import 'package:test_app/features/settings/views/widgets/settings_row.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/shared/components/content_list_row.dart';
import 'package:test_app/models/explore_models/explore_models.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'helpers/load_app_fonts.dart';

/// Nothing on these screens controls its own content. A title can be a
/// paragraph, a creator can have no name at all, and the phone can be a 320pt
/// iPhone SE. Each case here pumps a real widget and fails on any exception
/// Flutter raises — an overflow included.

/// Long enough to burst any row that is not told to ellipsize.
const _long =
    'The Power of Persistent Prayer in the Life of the Believer and the '
    'Church Universal Throughout Every Generation';

const _longName =
    'Celebration Centre International Ministries Worldwide Incorporated';

/// The narrowest phone the app is likely to meet.
const _small = Size(320, 568);
const _normal = Size(390, 844);

ExploreCreatorRef _creator({String name = _longName, bool org = true}) =>
    ExploreCreatorRef(
      id: 'c',
      name: name,
      handle: 'averyveryverylonghandlethatkeepsgoing',
      verified: true,
      subscribers: 128900,
      isOrganisation: org,
    );

ExploreCard _card({String title = _long, bool sponsored = false}) =>
    ExploreCard(
      id: 'x',
      title: title,
      creator: _creator(),
      badge: '1h 32:15',
      sponsored: sponsored,
      progress: 0.5,
    );

WebFeedItem _row({
  String entityType = 'media',
  String title = _long,
  String creator = _longName,
  String? location,
  String? startsAt,
}) => WebFeedItem.fromJson({
  'entityType': entityType,
  'entityId': 'x',
  'title': title,
  'creator': {
    'creatorId': 'c',
    'displayName': creator,
    'handle': 'averyveryverylonghandle',
    'isVerified': true,
  },
  'facets': {'analyticsViews': 12345678},
  'meta': {
    'handle': 'averyveryverylonghandle',
    'isVerified': true,
    'publishedAt': '2020-01-01T00:00:00.000Z',
    'locationLabel': ?location,
  },
  'calendarStartAt': ?startsAt,
});

/// Pumps [child] at [size] and fails if anything was thrown while laying out.
Future<void> _stress(
  WidgetTester tester,
  Widget child, {
  Size size = _normal,
  bool scroll = false,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.base1,
          body: scroll ? SingleChildScrollView(child: child) : child,
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(loadAppFonts);

  group('explore cards survive their content', () {
    testWidgets('a live card with a paragraph for a title', (tester) async {
      await _stress(tester, ExploreLiveCard(card: _card()));
    });

    testWidgets('a continue card with a paragraph for a title', (tester) async {
      await _stress(tester, ExploreContinueCard(card: _card()));
    });

    testWidgets('a trending card, sponsored, at rank 100', (tester) async {
      await _stress(
        tester,
        ExploreTrendingCard(card: _card(sponsored: true), rank: 100),
      );
    });

    testWidgets('a poster card, sponsored', (tester) async {
      await _stress(
        tester,
        ExplorePosterCard(
          card: _card(sponsored: true),
          kindIcon: AppAssets.iconCatBible,
        ),
      );
    });

    testWidgets('a creator card with a very long name and handle', (
      tester,
    ) async {
      // This one sets no width of its own, so it is the card most exposed to
      // the rail's unbounded horizontal constraints.
      await _stress(tester, ExploreCreatorCard(creator: _creator()));
    });

    testWidgets('a creator card inside an unbounded row', (tester) async {
      await _stress(
        tester,
        SizedBox(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [ExploreCreatorCard(creator: _creator())],
          ),
        ),
      );
    });

    testWidgets('an event row with a long venue and host', (tester) async {
      await _stress(
        tester,
        ExploreEventRow(
          event: ExploreEvent(
            id: 'e',
            title: _long,
            day: '12',
            month: 'JUN',
            venue: 'The Very Long Named Worship Centre And Conference Hall',
            time: '9:00am',
            creator: _creator(),
            sponsored: true,
          ),
        ),
      );
    });

    testWidgets('a card with no artwork at all', (tester) async {
      await _stress(
        tester,
        ExploreLiveCard(
          card: ExploreCard(id: 'x', title: 'No art', creator: _creator()),
        ),
      );
    });

    testWidgets('a creator with an empty name does not crash the avatar', (
      tester,
    ) async {
      await _stress(
        tester,
        ExploreCreatorCard(creator: _creator(name: '')),
      );
    });
  });

  group('explore rails hold their cards', () {
    for (final (label, rail) in <(String, Widget)>[
      (
        'live',
        ExploreRail(
          title: 'Live',
          itemCount: 3,
          itemBuilder: (_, _) => ExploreLiveCard(card: _card()),
        ),
      ),
      (
        'continue watching',
        ExploreRail(
          title: 'Continue watching',
          itemCount: 3,
          itemBuilder: (_, _) => ExploreContinueCard(card: _card()),
        ),
      ),
      (
        'trending',
        ExploreRail(
          title: 'Trending today',
          itemCount: 3,
          itemBuilder: (_, i) =>
              ExploreTrendingCard(card: _card(sponsored: true), rank: i + 1),
        ),
      ),
      (
        'posters',
        ExploreRail(
          title: 'Devotionals',
          itemCount: 3,
          itemBuilder: (_, _) => ExplorePosterCard(
            card: _card(sponsored: true),
            kindIcon: AppAssets.iconCatBible,
          ),
        ),
      ),
      (
        'ministries',
        ExploreRail(
          title: 'Ministries to follow',
          itemCount: 3,
          itemBuilder: (_, _) => ExploreCreatorCard(creator: _creator()),
        ),
      ),
    ]) {
      testWidgets('the $label rail does not overflow its height', (
        tester,
      ) async {
        await _stress(tester, rail);
      });

      testWidgets('the $label rail survives a 320pt phone', (tester) async {
        await _stress(tester, rail, size: _small);
      });
    }
  });

  group('the hero and chips', () {
    testWidgets('the hero holds a long ministry name and blurb', (
      tester,
    ) async {
      await _stress(
        tester,
        ExploreHeroPanel(
          hero: ExploreHero(
            id: 'h',
            title: _long,
            description: '$_long $_long',
            creator: _creator(),
          ),
          topInset: 54,
        ),
      );
    });

    testWidgets('the hero survives a 320pt phone', (tester) async {
      await _stress(
        tester,
        ExploreHeroPanel(hero: ExploreDummyData.hero, topInset: 54),
        size: _small,
      );
    });

    testWidgets('the chips wrap on a 320pt phone', (tester) async {
      await _stress(
        tester,
        ExploreCategoryChips(categories: ExploreDummyData.categories),
        size: _small,
        scroll: true,
      );
    });
  });

  group('search rows survive their content', () {
    testWidgets('a ministry row with a long name and handle', (tester) async {
      await _stress(
        tester,
        SearchMinistryRow(item: _row(entityType: 'creator'), following: false),
      );
    });

    testWidgets('a ministry row on a 320pt phone', (tester) async {
      // Name, handle, Follow and the overflow button all compete for one row.
      await _stress(
        tester,
        SearchMinistryRow(item: _row(entityType: 'creator'), following: true),
        size: _small,
      );
    });

    testWidgets('a content row with a paragraph title', (tester) async {
      await _stress(
        tester,
        SearchContentRow(item: _row(), kindLabel: 'Devotional'),
      );
    });

    testWidgets('a content row on a 320pt phone', (tester) async {
      // The still is a fixed 146 wide, which is a lot of a 320pt screen.
      await _stress(
        tester,
        SearchContentRow(item: _row(), kindLabel: 'Devotional'),
        size: _small,
      );
    });

    testWidgets('an event row with a long venue', (tester) async {
      await _stress(
        tester,
        SearchEventRow(
          item: _row(
            entityType: 'event',
            location: 'The Very Long Named Worship Centre And Conference Hall',
            startsAt: '2026-06-12T09:00:00.000Z',
          ),
        ),
      );
    });

    testWidgets('an event row on a 320pt phone', (tester) async {
      await _stress(
        tester,
        SearchEventRow(
          item: _row(
            entityType: 'event',
            location: 'River Worship',
            startsAt: '2026-06-12T09:00:00.000Z',
          ),
        ),
        size: _small,
      );
    });

    testWidgets('an event with no date at all', (tester) async {
      // calendarStartAt is nullable; the tile must simply not be drawn.
      await _stress(tester, SearchEventRow(item: _row(entityType: 'event')));
    });

    testWidgets('a recent row with a very long term', (tester) async {
      await _stress(tester, RecentSearchRow(term: _long), size: _small);
    });

    testWidgets('a suggestion row with a very long phrase', (tester) async {
      await _stress(tester, SearchSuggestionRow(phrase: _long), size: _small);
    });

    testWidgets('the tab row scrolls rather than overflowing', (tester) async {
      await _stress(
        tester,
        SearchTypeTabs(selected: SearchFilter.all, onSelected: (_) {}),
        size: _small,
      );
    });
  });

  group('history and settings survive their content', () {
    testWidgets('a history row with a paragraph title', (tester) async {
      await _stress(
        tester,
        const ContentListRow(
          title: _long,
          creatorName: _longName,
          creatorVerified: true,
          meta: 'Devotional · 12K views · 6d',
          badge: '1:02:25',
          progress: 0.5,
        ),
        size: _small,
      );
    });

    testWidgets('a history event row with a long venue', (tester) async {
      await _stress(
        tester,
        const ContentListRow(
          title: _long,
          creatorName: _longName,
          eventDate: '12 June 2026',
          eventVenue: 'The Very Long Named Worship Centre And Conference Hall',
          eventTime: '9am',
        ),
        size: _small,
      );
    });

    testWidgets('a resume card with a long title', (tester) async {
      await _stress(
        tester,
        const HistoryResumeCard(
          item: HistoryResumeItem(
            id: 'r',
            title: _long,
            creatorName: _longName,
            creatorVerified: true,
            progress: 0.5,
            isAudio: true,
          ),
        ),
        size: _small,
      );
    });

    testWidgets('a settings row with a long value and an action', (
      tester,
    ) async {
      await _stress(
        tester,
        const SettingsRow(
          icon: HugeIcons.strokeRoundedMail01,
          title: 'Two-factor authentication and recovery',
          subtitle: 'averyveryverylongemailaddress@someverylongdomain.com',
          subtitleVerified: true,
          action: 'Change',
        ),
        size: _small,
      );
    });

    testWidgets('a settings row on a 320pt phone with a chevron', (
      tester,
    ) async {
      await _stress(
        tester,
        const SettingsRow(
          icon: HugeIcons.strokeRoundedShieldUser,
          title: 'Two-factor authentication',
          subtitle: 'Off · uses an authenticator app',
          showChevron: true,
        ),
        size: _small,
      );
    });

    testWidgets('the initials disc handles a name with no spaces', (
      tester,
    ) async {
      await _stress(tester, const SettingsAvatar(name: _longName));
    });
  });

  group('the profile screen survives its content', () {
    testWidgets('a header with a long name and handle', (tester) async {
      await _stress(
        tester,
        const ProfileHeaderCard(
          name: _longName,
          handle: '@averyveryverylonghandlethatkeepsgoingandgoing',
          hasNotifications: true,
        ),
      );
    });

    testWidgets('a header on a 320pt phone', (tester) async {
      await _stress(
        tester,
        const ProfileHeaderCard(name: _longName, handle: '@long'),
        size: _small,
      );
    });

    testWidgets('continue watching with a long title', (tester) async {
      await _stress(
        tester,
        const ContinueWatchingCard(
          progress: ProfileWatchProgress(
            mediaId: 'm',
            title: _long,
            creatorName: _longName,
            creatorVerified: true,
            fraction: 0.5,
            remainingLabel: '1h 24m',
          ),
        ),
        size: _small,
      );
    });

    testWidgets('a menu row with a long label, note and pill', (tester) async {
      // The worst case the design allows: everything on one row at once.
      await _stress(
        tester,
        const ProfileMenuItem(
          icon: HugeIcons.strokeRoundedCalendar03,
          label: 'My prayer requests and testimonies',
          note: 'Start your channel today',
          pill: '128 Upcoming',
        ),
        size: _small,
      );
    });

    testWidgets('a menu row with a long label and a tag', (tester) async {
      await _stress(
        tester,
        const ProfileMenuItem(
          leading: ColoredBox(color: AppColors.brandPrimary),
          label: _longName,
          tag: 'Streamer',
        ),
        size: _small,
      );
    });

    testWidgets('the whole menu on a 320pt phone', (tester) async {
      await _stress(
        tester,
        const ProfileMenuSection(
          caption: 'YOU',
          children: [
            ProfileMenuItem(
              icon: HugeIcons.strokeRoundedClock01,
              label: 'History',
            ),
            ProfileMenuItem(
              icon: HugeIcons.strokeRoundedCalendar03,
              label: 'My events',
              pill: '2 Upcoming',
            ),
          ],
        ),
        size: _small,
        scroll: true,
      );
    });
  });
}
