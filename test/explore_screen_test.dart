import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/explore/data/explore_categories.dart';
import 'package:test_app/features/explore/repo/explore_repo.dart';
import 'package:test_app/features/explore/views/explore_screen.dart';
import 'package:test_app/features/explore/views/widgets/card_bits.dart';
import 'package:test_app/features/explore/views/widgets/explore_category_chips.dart';
import 'package:test_app/features/explore/views/widgets/explore_cards.dart';
import 'package:test_app/features/explore/views/widgets/explore_creator_card.dart';
import 'package:test_app/features/explore/views/widgets/explore_event_row.dart';
import 'package:test_app/features/explore/views/widgets/explore_hero.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount;
import 'package:test_app/models/explore_models/explore_models.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

const _creator = ExploreCreatorRef(
  id: 'c1',
  name: 'Grace Community',
  handle: 'grace',
  verified: true,
  subscribers: 12900,
);

const _card = ExploreCard(
  id: 'x1',
  title: 'The Power of Persistent Prayer',
  creator: _creator,
  badge: '32:15',
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.base1,
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// A hero panel's worth of content, built here rather than shipped in the
/// app: these tests are about the panel's layout, not about any real row.
ExploreHero _sampleHero() => const ExploreHero(
  id: 'm1',
  title: 'The Weight of Worship',
  description: 'A night of praise from the Lagos auditorium.',
  creator: ExploreCreatorRef(
    id: 'c1',
    name: 'Grace Chapel',
    handle: 'gracechapel',
    isOrganisation: true,
  ),
);

void main() {
  setUpAll(loadAppFonts);
  _screenTests();

  group('a card names what it is showing', () {
    testWidgets('the title and the creator both appear', (tester) async {
      await _pump(tester, const ExploreLiveCard(card: _card));

      expect(find.text('The Power of Persistent Prayer'), findsOneWidget);
      expect(find.text('Grace Community'), findsOneWidget);
    });

    testWidgets('a live card flags itself as live', (tester) async {
      await _pump(tester, const ExploreLiveCard(card: _card));
      expect(find.byType(ExploreLiveFlag), findsOneWidget);
    });

    testWidgets('a poster card shows its length badge', (tester) async {
      await _pump(
        tester,
        const ExplorePosterCard(
          card: ExploreCard(
            id: 'd1',
            title: 'Embracing Change',
            creator: _creator,
            badge: '40 days',
          ),
          kindIcon: 'assets/icons/cat_bible.svg',
        ),
      );
      expect(find.text('40 days'), findsOneWidget);
    });

    testWidgets('a trending card carries its position', (tester) async {
      await _pump(tester, const ExploreTrendingCard(card: _card, rank: 3));
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('the sponsored marker', () {
    testWidgets('is absent on an ordinary row', (tester) async {
      await _pump(tester, const ExploreTrendingCard(card: _card, rank: 1));
      expect(find.byType(ExploreSponsoredTag), findsNothing);
    });

    testWidgets('appears once a row is promoted', (tester) async {
      await _pump(
        tester,
        const ExploreTrendingCard(
          card: ExploreCard(
            id: 'x2',
            title: 'Promoted',
            creator: _creator,
            sponsored: true,
          ),
          rank: 1,
        ),
      );
      expect(find.byType(ExploreSponsoredTag), findsOneWidget);
      expect(find.text('Sponsored'), findsOneWidget);
    });
  });

  group('continue watching', () {
    testWidgets('draws the creator without an avatar', (tester) async {
      // The design gives this rail the name alone so the poster keeps the eye.
      await _pump(
        tester,
        const ExploreContinueCard(
          card: ExploreCard(
            id: 'cw',
            title: 'Half finished',
            creator: _creator,
            progress: 0.5,
          ),
        ),
      );

      final line = tester.widget<ExploreCreatorLine>(
        find.byType(ExploreCreatorLine),
      );
      expect(line.showAvatar, isFalse);
    });

    testWidgets('a progress bar is drawn for a part-watched row', (
      tester,
    ) async {
      await _pump(
        tester,
        const ExploreContinueCard(
          card: ExploreCard(
            id: 'cw',
            title: 'Half finished',
            creator: _creator,
            progress: 0.5,
          ),
        ),
      );

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, 0.5);
    });

    testWidgets('a row with no progress reads as unstarted', (tester) async {
      await _pump(
        tester,
        const ExploreContinueCard(
          card: ExploreCard(id: 'cw', title: 'Fresh', creator: _creator),
        ),
      );

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, 0);
    });
  });

  group('a ministry card', () {
    testWidgets('shows a tick once the viewer follows, not a bare plus', (
      tester,
    ) async {
      // Without this the badge is an action with no feedback: you tap it and
      // nothing says whether it took.
      await _pump(
        tester,
        const ExploreCreatorCard(creator: _creator, isFollowing: true),
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('and a plus while they do not', (tester) async {
      await _pump(tester, const ExploreCreatorCard(creator: _creator));
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('shows the handle and a rounded subscriber count', (
      tester,
    ) async {
      await _pump(tester, const ExploreCreatorCard(creator: _creator));

      expect(find.text('@grace'), findsOneWidget);
      expect(find.text('12.9K Subscribers'), findsOneWidget);
    });

    testWidgets('the follow badge is tappable on its own', (tester) async {
      // Tapping it must not also open the profile behind it.
      var follows = 0;
      var opens = 0;
      await _pump(
        tester,
        ExploreCreatorCard(
          creator: _creator,
          onTap: () => opens++,
          onFollow: () => follows++,
        ),
      );

      await tester.tap(
        find
            .ancestor(
              of: find.byWidgetPredicate(
                (w) =>
                    w is DesignIcon && w.asset == AppAssets.iconFeedPlusCircle,
              ),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      await tester.pump();

      expect(follows, 1);
      expect(opens, 0);
    });

    test('subscriber counts round the way the design writes them', () {
      // Shared with the feed cards, so a count reads the same everywhere.
      expect(formatCount(999), '999');
      expect(formatCount(12900), '12.9K');
      expect(formatCount(48200), '48.2K');
      expect(formatCount(7000), '7K');
      expect(formatCount(1500000), '1.5M');
    });
  });

  group('an event row', () {
    testWidgets('prints the date, venue and time', (tester) async {
      await _pump(
        tester,
        const ExploreEventRow(
          event: ExploreEvent(
            id: 'e1',
            title: 'Youth Conference',
            day: '12',
            month: 'JUN',
            venue: 'River Worship',
            time: '9:00am',
            creator: _creator,
          ),
        ),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.text('JUN'), findsOneWidget);
      expect(find.text('Youth Conference'), findsOneWidget);
      expect(find.text('River Worship'), findsOneWidget);
      expect(find.text('9:00am'), findsOneWidget);
    });
  });

  group('browse chips', () {
    testWidgets('every category is offered', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 390,
          child: ExploreCategoryChips(categories: ExploreCategories.all),
        ),
      );

      expect(find.text('Browse'), findsOneWidget);
      for (final c in ExploreCategories.all) {
        expect(find.text(c.label), findsOneWidget, reason: c.slug);
      }
    });

    testWidgets('tapping one reports which', (tester) async {
      ExploreCategory? picked;
      await _pump(
        tester,
        SizedBox(
          width: 390,
          child: ExploreCategoryChips(
            categories: ExploreCategories.all,
            onSelected: (c) => picked = c,
          ),
        ),
      );

      await tester.tap(find.text('Worship'));
      await tester.pump();

      expect(picked?.slug, 'worship');
    });

    test('no two categories share a slug', () {
      final slugs = ExploreCategories.all.map((c) => c.slug).toSet();
      expect(slugs.length, ExploreCategories.all.length);
    });
  });

  group('the hero', () {
    testWidgets('offers both of the design\'s actions', (tester) async {
      var watched = 0;
      var saved = 0;
      await _pump(
        tester,
        SizedBox(
          width: 390,
          child: ExploreHeroPanel(
            hero: _sampleHero(),
            topInset: 54,
            onWatch: () => watched++,
            onAddToPlaylist: () => saved++,
          ),
        ),
      );

      expect(find.text('The Weight of Worship'), findsOneWidget);

      await tester.tap(find.text('Watch'));
      await tester.tap(find.text('Add to playlist'));
      await tester.pump();

      expect(watched, 1);
      expect(saved, 1);
    });

    testWidgets('leaves room for the status bar above the artwork', (
      tester,
    ) async {
      // The panel runs under the notch, so its height has to grow by the inset
      // or the creator line rides up into the clock.
      await _pump(
        tester,
        SizedBox(
          width: 390,
          child: ExploreHeroPanel(hero: _sampleHero(), topInset: 54),
        ),
      );

      final box = tester.getSize(find.byType(ExploreHeroPanel));
      expect(box.height, greaterThan(ExploreHeroPanel.height));
    });
  });
}

ExploreCard _railCard(String id, String title) =>
    ExploreCard(id: id, title: title, creator: _creator);

/// An Explore page with exactly the rails a test wants, and no network.
class _StubRepo implements ExploreRepo {
  _StubRepo(this.page);

  final ExplorePage page;
  int loads = 0;

  @override
  Future<ExplorePage> load() async {
    loads++;
    return page;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _pumpScreen(WidgetTester tester, ExplorePage page) async {
  tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(home: ExploreScreen(repo: _StubRepo(page))),
    ),
  );
  await tester.pumpAndSettle();
}

void _screenTests() {
  group('the page', () {
    testWidgets('draws only the rails that have something in them', (
      tester,
    ) async {
      // A browse that comes back empty means "not right now". A heading over
      // no cards reads as a claim that the whole category is empty.
      await _pumpScreen(
        tester,
        ExplorePage(
          trending: [_railCard('m1', 'Most watched')],
          articles: [_railCard('p1', 'An article')],
        ),
      );

      expect(find.text(AppStrings.exploreTrendingToday), findsOneWidget);
      expect(find.text(AppStrings.exploreArticles), findsOneWidget);
      expect(find.text(AppStrings.exploreLive), findsNothing);
      expect(find.text(AppStrings.exploreContinueWatching), findsNothing);
      expect(find.text(AppStrings.exploreUpcomingEvent), findsNothing);
    });

    testWidgets('with nothing at all, says so rather than drawing a shell', (
      tester,
    ) async {
      await _pumpScreen(tester, const ExplorePage());
      expect(find.text(AppStrings.feedRetry), findsOneWidget);
    });

    testWidgets('a rail with nowhere to go shows no See all', (tester) async {
      // Trending is an ordering, not a kind — no type tab means it, so the
      // chevron would be an affordance that leads nowhere.
      await _pumpScreen(
        tester,
        ExplorePage(
          trending: [_railCard('m1', 'Top')],
          articles: [_railCard('p1', 'An article')],
        ),
      );
      final chevrons = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == AppIcons.chevronRight,
      );
      // Articles has one; Trending does not.
      expect(chevrons, findsOneWidget);
    });

    testWidgets('the banner is the top trending item', (tester) async {
      await _pumpScreen(
        tester,
        ExplorePage(
          hero: const ExploreHero(
            id: 'm1',
            title: 'Most watched',
            description: '',
            creator: _creator,
          ),
          trending: [_railCard('m1', 'Most watched')],
        ),
      );
      expect(find.text('Most watched'), findsWidgets);
      expect(find.text(AppStrings.exploreWatch), findsOneWidget);
    });

    testWidgets('the browse chips carry the real platform slugs', (
      tester,
    ) async {
      // An earlier version offered `preaching`, `fellowship`, `missions` and
      // `discipleship`, none of which the platform has — a filter on one
      // would have matched nothing.
      await _pumpScreen(
        tester,
        ExplorePage(trending: [_railCard('m1', 'Top')]),
      );
      const real = {
        'worship',
        'sermons',
        'bible-study',
        'prayer',
        'gospel-music',
        'live-services',
        'testimonies',
        'youth',
        'family',
        'devotionals',
      };
      expect(ExploreCategories.all.map((c) => c.slug).toSet(), real);
    });
  });
}
