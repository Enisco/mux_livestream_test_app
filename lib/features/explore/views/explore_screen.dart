import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/views/creator_profile_screen.dart';
import 'package:test_app/features/discovery/views/content_detail_screen.dart';
import 'package:test_app/features/discovery/views/search_screen.dart';
import 'package:test_app/features/explore/data/explore_categories.dart';
import 'package:test_app/features/library/views/add_to_playlist_sheet.dart';
import 'package:test_app/features/explore/repo/explore_repo.dart';
import 'package:test_app/features/explore/views/widgets/explore_category_chips.dart';
import 'package:test_app/features/explore/views/widgets/explore_cards.dart';
import 'package:test_app/features/explore/views/widgets/explore_creator_card.dart';
import 'package:test_app/features/explore/views/widgets/explore_event_row.dart';
import 'package:test_app/features/explore/views/widgets/explore_hero.dart';
import 'package:test_app/features/explore/views/widgets/explore_rail.dart';
import 'package:test_app/features/discovery/data/search_query.dart';
import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/explore_models/explore_models.dart';
import 'package:test_app/shared/components/auth_sheet.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/services/analytics_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Explore: the catalogue as rails — what is live now, what the reader left
/// unfinished, and what is worth starting.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.repo});

  /// Defaults to the real thing; a test supplies its own.
  final ExploreRepo? repo;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();

  static void openSearch(BuildContext context, {String? query}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: query)),
    );
  }
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final _repo = widget.repo ?? ExploreRepo();

  ExplorePage? _page;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await _repo.load();
      if (!mounted) return;
      // The cards read the store, so it has to be told what the rows said:
      // without this the store answers "not following" for every ministry
      // here, and a tap on a followed one sends a second follow rather than
      // the unfollow the green tick offers.
      //
      // Asked through `isRegistered` because follow state is not worth
      // taking the whole tab down for — the rails are the point, and a
      // widget test that only cares about them registers no store.
      if (getIt.isRegistered<EngagementStore>()) {
        final store = getIt<EngagementStore>();
        for (final ministry in page.ministries) {
          store.seedFollowing(ministry.id, ministry.isFollowing);
        }
      }
      setState(() {
        _page = page;
        _loading = false;
        // Every rail failing is a real error. One or two being quiet is not.
        _failed = page.isEmpty;
      });
    } catch (e) {
      logger.w('Explore failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _openCard(ExploreCard card) {
    final item = card.source;
    if (item == null) return;
    getIt<AnalyticsService>().trackContentClick(
      mediaId: item.entityId,
      contentType: ContentTypes.fromEntityType(item.entityType),
      creatorId: card.creator.id,
      mediaType: item.mediaType,
      source: AnalyticsSource.explore,
      promotion: item.promotion,
    );
    openContentDetail(context, item, source: AnalyticsSource.explore);
  }

  void _openCreator(String creatorId) {
    if (creatorId.isEmpty) return;
    openCreatorProfile(context, creatorId: creatorId);
  }

  /// Follow from the rail, without leaving it.
  Future<void> _toggleFollow(ExploreCreatorRef creator) async {
    if (creator.id.isEmpty) return;
    if (!await _requireAccount('follow creators')) return;
    await getIt<EngagementStore>().toggleFollow(
      creator.id,
      fallback: creator.isFollowing,
    );
  }

  /// Explore is a public tab, so the reader may well have no account. Asking
  /// the store to post without one leaves the tick toggling and rolling back
  /// with nothing to explain it.
  Future<bool> _requireAccount(String feature) async {
    if (await getIt<TokenStorageService>().hasSession) return true;
    if (mounted) showAuthSheet(context, feature);
    return false;
  }

  /// The design's second hero action. It used to push the playlists
  /// *browse* screen, which cannot be told what is being added, so nothing
  /// ever was — the same fault the card sheet's row had.
  Future<void> _addToPlaylist(String mediaId) async {
    if (!await _requireAccount('use playlists')) return;
    if (!mounted) return;
    final result = await showAddToPlaylistSheet(context, mediaId: mediaId);
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// The page less anything the reader has blocked, muted, hidden or
  /// reported.
  ///
  /// Explore is a tab inside an `IndexedStack`, so it keeps whatever it
  /// loaded for as long as the app runs. A ministry blocked from the home
  /// feed or from search would otherwise go on filling these rails until
  /// a restart — and blocking is not a suggestion.
  ExplorePage _visible(ExplorePage page) {
    if (!getIt.isRegistered<EngagementStore>()) return page;
    final store = getIt<EngagementStore>();
    bool keep(String creatorId, String id) =>
        !store.hidesRow(creatorId: creatorId, targetId: id);
    List<ExploreCard> cards(List<ExploreCard> rows) =>
        rows.where((c) => keep(c.creator.id, c.id)).toList(growable: false);

    final trending = cards(page.trending);
    final hero = page.hero;
    return ExplorePage(
      // The hero's Watch opens the top trending card, so a hero without
      // one behind it is a button with nothing to press. It is drawn from
      // that card in the first place, so the two normally go together —
      // this is the case where filtering parts them.
      hero:
          hero != null && trending.isNotEmpty && keep(hero.creator.id, hero.id)
          ? hero
          : null,
      trending: trending,
      live: cards(page.live),
      continueWatching: cards(page.continueWatching),
      devotionals: cards(page.devotionals),
      articles: cards(page.articles),
      // A ministry row is the ministry, so its own id is both.
      ministries: page.ministries
          .where((m) => keep(m.id, m.id))
          .toList(growable: false),
      events: page.events
          .where((e) => keep(e.creator.id, e.id))
          .toList(growable: false),
    );
  }

  /// The hero's row, when it is a piece of media with an id to file.
  String? get _heroMediaId {
    final row = _page?.hero?.source;
    if (row == null || row.entityType != 'media') return null;
    return row.entityId.isEmpty ? null : row.entityId;
  }

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
            RefreshIndicator(
              color: AppColors.brandPrimary,
              backgroundColor: AppColors.base1,
              onRefresh: _load,
              child: _body(),
            ),
            _FloatingSearch(onTap: () => ExploreScreen.openSearch(context)),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }
    if (_failed || _page == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          ErrorStateView(onRetry: _load),
        ],
      );
    }
    // The rails watch the store so a ministry blocked elsewhere leaves
    // them without a refetch.
    if (!getIt.isRegistered<EngagementStore>()) return _rails(_page!);
    return ListenableBuilder(
      listenable: getIt<EngagementStore>().hiddenChanges,
      builder: (context, _) => _rails(_visible(_page!)),
    );
  }

  Widget _rails(ExplorePage page) {
    return _Content(
      page: page,
      onOpenCard: _openCard,
      onOpenCreator: _openCreator,
      onFollow: _toggleFollow,
      onAddToPlaylist: switch (_heroMediaId) {
        final id? => () => unawaited(_addToPlaylist(id)),
        null => null,
      },
      onTopic: (category) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchScreen(initialCategory: category),
        ),
      ),
      onSeeAll: (filter) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SearchScreen(initialFilter: filter)),
      ),
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
  const _Content({
    required this.page,
    required this.onOpenCard,
    required this.onOpenCreator,
    required this.onFollow,
    required this.onAddToPlaylist,
    required this.onTopic,
    required this.onSeeAll,
  });

  final ExplorePage page;
  final ValueChanged<ExploreCard> onOpenCard;
  final ValueChanged<String> onOpenCreator;
  final ValueChanged<ExploreCreatorRef> onFollow;

  /// Null when the hero is not a piece of media, which hides the
  /// control rather than drawing one that cannot work.
  final VoidCallback? onAddToPlaylist;

  /// A Browse chip is a category, so it narrows by slug rather than running
  /// a search for the label's words.
  final ValueChanged<ExploreCategory> onTopic;

  /// A rail is a kind of thing, so "See all" opens that type tab rather than
  /// searching for the heading's words.
  final ValueChanged<SearchFilter> onSeeAll;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    const gap = kExploreSectionGap;

    /// One rail, or nothing at all when it has no rows.
    List<Widget> rail(
      String title,
      int count,
      Widget Function(BuildContext, int) builder, {
      SearchFilter? seeAll,
      double itemGap = 16,
      CrossAxisAlignment align = CrossAxisAlignment.start,
    }) => count == 0
        ? const []
        : [
            ExploreRail(
              key: ValueKey('explore-rail-$title'),
              title: title,
              // Trending and Continue watching are orderings, not types —
              // there is no tab that means either, so they offer no See all
              // rather than one that lands somewhere arbitrary.
              onSeeAll: seeAll == null ? null : () => onSeeAll(seeAll),
              gap: itemGap,
              crossAxisAlignment: align,
              itemCount: count,
              itemBuilder: builder,
            ),
            SizedBox(height: gap.s),
          ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        // Clear of the floating nav bar at the bottom of the shell.
        bottom: MediaQuery.paddingOf(context).bottom + 110.s,
      ),
      children: [
        if (page.hero case final hero?) ...[
          ExploreHeroPanel(
            hero: hero,
            topInset: topInset,
            onWatch: () => onOpenCard(page.trending.first),
            onAddToPlaylist: onAddToPlaylist,
            // The hero names a ministry and draws its logo; both have to
            // open that ministry, as they do on every other surface.
            onCreatorTap: () => onOpenCreator(hero.creator.id),
          ),
          SizedBox(height: 16.s),
        ] else
          SizedBox(height: topInset + 76.s),

        ...rail(
          seeAll: SearchFilter.live,
          AppStrings.exploreLive,
          page.live.length,
          (_, i) => ExploreLiveCard(
            card: page.live[i],
            onTap: () => onOpenCard(page.live[i]),
          ),
        ),

        ...rail(
          AppStrings.exploreContinueWatching,
          page.continueWatching.length,
          (_, i) => ExploreContinueCard(
            card: page.continueWatching[i],
            onTap: () => onOpenCard(page.continueWatching[i]),
          ),
        ),

        ...rail(
          AppStrings.exploreTrendingToday,
          page.trending.length,
          (_, i) => ExploreTrendingCard(
            card: page.trending[i],
            rank: i + 1,
            onTap: () => onOpenCard(page.trending[i]),
          ),
        ),

        ...rail(
          seeAll: SearchFilter.devotionals,
          AppStrings.exploreDevotionals,
          page.devotionals.length,
          (_, i) => ExplorePosterCard(
            card: page.devotionals[i],
            kindIcon: AppAssets.iconCatBible,
            onTap: () => onOpenCard(page.devotionals[i]),
          ),
        ),

        ...rail(
          seeAll: SearchFilter.blogs,
          AppStrings.exploreArticles,
          page.articles.length,
          (_, i) => ExplorePosterCard(
            card: page.articles[i],
            kindIcon: AppAssets.iconBookOpen,
            onTap: () => onOpenCard(page.articles[i]),
          ),
        ),

        ...rail(
          seeAll: SearchFilter.creators,
          AppStrings.exploreMinistries,
          page.ministries.length,
          (_, i) => ListenableBuilder(
            // The store is the one truth for follow state, so a follow made
            // on a channel page shows here too, without a refetch.
            listenable: getIt<EngagementStore>(),
            builder: (_, _) => ExploreCreatorCard(
              creator: page.ministries[i],
              isFollowing: getIt<EngagementStore>().isFollowing(
                page.ministries[i].id,
                fallback: page.ministries[i].isFollowing,
              ),
              onTap: () => onOpenCreator(page.ministries[i].id),
              onFollow: () => onFollow(page.ministries[i]),
            ),
          ),
        ),

        ...rail(
          seeAll: SearchFilter.events,
          AppStrings.exploreUpcomingEvent,
          page.events.length,
          (_, i) => ExploreEventRow(
            event: page.events[i],
            onTap: () {
              final source = page.events[i].source;
              if (source != null) {
                openContentDetail(
                  context,
                  source,
                  source: AnalyticsSource.explore,
                );
              }
            },
          ),
          itemGap: 24,
          align: CrossAxisAlignment.end,
        ),

        ExploreCategoryChips(
          categories: ExploreCategories.all,
          onSelected: onTopic,
        ),
      ],
    );
  }
}
