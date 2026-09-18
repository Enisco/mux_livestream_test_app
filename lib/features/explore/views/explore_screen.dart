import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/discovery/views/search_screen.dart';
import 'package:test_app/features/explore/data/explore_dummy_data.dart';
import 'package:test_app/features/explore/views/widgets/explore_category_chips.dart';
import 'package:test_app/features/explore/views/widgets/explore_cards.dart';
import 'package:test_app/features/explore/views/widgets/explore_creator_card.dart';
import 'package:test_app/features/explore/views/widgets/explore_event_row.dart';
import 'package:test_app/features/explore/views/widgets/explore_hero.dart';
import 'package:test_app/features/explore/views/widgets/explore_rail.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Explore: the catalogue as rails — what is live now, what the reader left
/// unfinished, and what is worth starting.
///
/// The rows are placeholders. None of these rails has an endpoint yet, so
/// every one reads [ExploreDummyData]; the widgets already take the models the
/// real responses will parse into, so wiring them up is a swap at this level
/// and nowhere else. See that file for how to retire it.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The hero runs under the status bar, so its clock and icons need to be
    // light whatever the platform would otherwise pick.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.base1,
        body: Stack(
          children: [
            const _Content(),
            _FloatingSearch(onTap: () => openSearch(context)),
          ],
        ),
      ),
    );
  }

  static void openSearch(BuildContext context, {String? query}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: query)),
    );
  }
}

/// The search field, pinned over the hero rather than scrolling with it — it
/// is the one control that must stay reachable the whole way down.
class _FloatingSearch extends StatelessWidget {
  const _FloatingSearch({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10.s,
      left: kExploreGutter.s,
      right: kExploreGutter.s,
      child: ExploreSearchBar(onTap: onTap),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content();

  /// The rails run on placeholder rows, so a tap has nothing real to open.
  /// Saying so beats a button that looks live and does nothing.
  void _todo(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$what is not built yet', style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    const gap = kExploreSectionGap;

    return ListView(
      padding: EdgeInsets.only(
        // Clear of the floating nav bar at the bottom of the shell.
        bottom: MediaQuery.paddingOf(context).bottom + 110.s,
      ),
      children: [
        ExploreHeroPanel(
          hero: ExploreDummyData.hero,
          topInset: topInset,
          onWatch: () => _todo(context, AppStrings.exploreWatch),
          onAddToPlaylist: () =>
              _todo(context, AppStrings.exploreAddToPlaylist),
        ),
        SizedBox(height: 16.s),

        ExploreRail(
          title: AppStrings.exploreLive,
          onSeeAll: () => _todo(context, AppStrings.exploreLive),
          itemCount: ExploreDummyData.live.length,
          itemBuilder: (_, i) => ExploreLiveCard(
            card: ExploreDummyData.live[i],
            onTap: () => _todo(context, ExploreDummyData.live[i].title),
          ),
        ),
        SizedBox(height: gap.s),

        ExploreRail(
          title: AppStrings.exploreContinueWatching,
          onSeeAll: () => _todo(context, AppStrings.exploreContinueWatching),
          itemCount: ExploreDummyData.continueWatching.length,
          itemBuilder: (_, i) => ExploreContinueCard(
            card: ExploreDummyData.continueWatching[i],
            onTap: () =>
                _todo(context, ExploreDummyData.continueWatching[i].title),
          ),
        ),
        SizedBox(height: gap.s),

        ExploreRail(
          title: AppStrings.exploreTrendingToday,
          onSeeAll: () => _todo(context, AppStrings.exploreTrendingToday),
          itemCount: ExploreDummyData.trending.length,
          itemBuilder: (_, i) => ExploreTrendingCard(
            card: ExploreDummyData.trending[i],
            rank: i + 1,
            onTap: () => _todo(context, ExploreDummyData.trending[i].title),
          ),
        ),
        SizedBox(height: gap.s),

        ExploreRail(
          title: AppStrings.exploreDevotionals,
          onSeeAll: () => _todo(context, AppStrings.exploreDevotionals),
          itemCount: ExploreDummyData.devotionals.length,
          itemBuilder: (_, i) => ExplorePosterCard(
            card: ExploreDummyData.devotionals[i],
            kindIcon: AppAssets.iconCatBible,
            onTap: () => _todo(context, ExploreDummyData.devotionals[i].title),
          ),
        ),
        SizedBox(height: gap.s),

        ExploreRail(
          title: AppStrings.exploreArticles,
          onSeeAll: () => _todo(context, AppStrings.exploreArticles),
          itemCount: ExploreDummyData.articles.length,
          itemBuilder: (_, i) => ExplorePosterCard(
            card: ExploreDummyData.articles[i],
            kindIcon: AppAssets.iconBookOpen,
            onTap: () => _todo(context, ExploreDummyData.articles[i].title),
          ),
        ),
        SizedBox(height: gap.s),

        ExploreRail(
          title: AppStrings.exploreMinistries,
          onSeeAll: () => _todo(context, AppStrings.exploreMinistries),
          itemCount: ExploreDummyData.ministries.length,
          itemBuilder: (_, i) => ExploreCreatorCard(
            creator: ExploreDummyData.ministries[i],
            onTap: () => _todo(context, ExploreDummyData.ministries[i].name),
            onFollow: () => _todo(context, 'Following a ministry'),
          ),
        ),
        SizedBox(height: gap.s),

        ExploreRail(
          title: AppStrings.exploreUpcomingEvent,
          onSeeAll: () => _todo(context, AppStrings.exploreUpcomingEvent),
          gap: 24,
          crossAxisAlignment: CrossAxisAlignment.end,
          itemCount: ExploreDummyData.events.length,
          itemBuilder: (_, i) => ExploreEventRow(
            event: ExploreDummyData.events[i],
            onTap: () => _todo(context, ExploreDummyData.events[i].title),
          ),
        ),
        SizedBox(height: gap.s),

        ExploreCategoryChips(
          categories: ExploreDummyData.categories,
          onSelected: (c) => ExploreScreen.openSearch(context, query: c.label),
        ),
      ],
    );
  }
}
