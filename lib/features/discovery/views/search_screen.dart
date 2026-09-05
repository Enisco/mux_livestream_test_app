import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/analytics/views/widgets/promoted_impression_tracker.dart';
import 'package:test_app/features/creator/views/creator_profile_screen.dart';
import 'package:test_app/features/discovery/data/recent_searches.dart';
import 'package:test_app/features/discovery/data/search_grouping.dart';
import 'package:test_app/features/discovery/data/search_query.dart';
import 'package:test_app/features/discovery/data/search_suggestions_dummy.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/discovery/views/content_detail_screen.dart';
import 'package:test_app/features/discovery/views/widgets/search_field.dart';
import 'package:test_app/features/discovery/views/widgets/search_result_rows.dart';
import 'package:test_app/features/discovery/views/widgets/search_type_tabs.dart';
import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/data/feed_card_actions.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/explore/data/explore_dummy_data.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/shared/components/auth_sheet.dart';
import 'package:test_app/shared/components/category_chip_grid.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/services/analytics_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Search: browse the catalogue by topic, or narrow it by typing.
///
/// Three states, as the design has them. An empty field offers what the reader
/// searched before and the topics they can browse. Typing offers completions
/// over a preview of what already matches. Committing a query swaps in the type
/// filter and the full grouped results.
///
/// The discovery API has no free-text search route, so a typed query filters
/// the rows the feed returned rather than what it asks for. The type filter
/// *is* a server filter, so choosing one genuinely changes the request. The
/// only invented rows on this screen are the completions — see
/// [SearchSuggestions].
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// Opens straight to results for this term rather than to an empty field.
  ///
  /// This is how a Browse chip on Explore arrives: the reader has already said
  /// what they want, so asking them to type it again would be busywork.
  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _Phase { browsing, typing, results }

class _SearchScreenState extends State<SearchScreen> {
  final _repo = getIt<DiscoveryRepo>();
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  SearchFilter _filter = SearchFilter.all;
  String _query = '';
  bool _committed = false;
  Timer? _debounce;

  List<String> _recent = const [];
  List<WebFeedItem> _items = const [];
  final _store = getIt<EngagementStore>();
  late final _actions = FeedCardActions(
    store: _store,
    requireAccount: _requireAccount,
  );
  bool _authed = false;
  String? _cursor;
  bool _loading = false;
  bool _loadingMore = false;
  bool _failed = false;

  _Phase get _phase {
    if (_query.isEmpty) return _Phase.browsing;
    return _committed ? _Phase.results : _Phase.typing;
  }

  List<WebFeedItem> get _results =>
      SearchMatcher.apply(_items, _query, _filter);

  @override
  void initState() {
    super.initState();
    _recent = RecentSearches.load();
    _scroll.addListener(_onScroll);

    final opening = widget.initialQuery?.trim() ?? '';
    if (opening.isEmpty) {
      _focus.requestFocus();
    } else {
      // Arriving with a term means the results are what was asked for; raising
      // the keyboard over them would only be in the way.
      _controller.text = opening;
      _query = opening;
      _committed = true;
    }
    _init();
  }

  Future<void> _init() async {
    // Arriving with a term is still a search the reader ran — from a Browse
    // chip on Explore — so it belongs in their history like any other.
    final opening = widget.initialQuery?.trim() ?? '';
    if (opening.isNotEmpty) {
      final next = await RecentSearches.add(opening);
      if (mounted) setState(() => _recent = next);
    }

    _authed = await getIt<TokenStorageService>().hasSession;
    if (mounted) await _load();
  }

  /// Fills in the viewer's own like/save state for rows just loaded; the feed
  /// payload does not carry it. Guests have none to fetch.
  Future<void> _hydrateInteractions(List<WebFeedItem> rows) async {
    if (!_authed || rows.isEmpty) return;

    final byType = <String, List<String>>{};
    for (final row in rows) {
      final target = InteractionTargets.fromEntityType(row.entityType);
      if (target == null) continue;
      (byType[target] ??= []).add(row.entityId);
    }
    if (byType.isEmpty) return;

    for (final entry in byType.entries) {
      final mine = await getIt<EngagementRepo>().fetchMyInteractions(
        targetType: entry.key,
        targetIds: entry.value,
      );
      if (!mounted) return;
      _store.seedInteractions(entry.key, mine);
    }
  }

  bool _requireAccount(String feature) {
    if (_authed) return true;
    showAuthSheet(context, feature);
    return false;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    // Filtering happens on rows already in hand, so this only needs to be slow
    // enough to avoid rebuilding the list on every keystroke.
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        // Any edit puts the reader back among the completions. Without this a
        // committed query stayed on the results list while they typed, and the
        // suggestions never came back until the field was cleared entirely.
        _committed = false;
      });
    });
  }

  /// Runs a query for real: remembers it, closes the keyboard, shows results.
  Future<void> _commit(String value) async {
    final term = value.trim();
    if (term.isEmpty) return;

    _debounce?.cancel();
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    _focus.unfocus();
    setState(() {
      _query = term;
      _committed = true;
    });

    final next = await RecentSearches.add(term);
    if (mounted) setState(() => _recent = next);
  }

  void _clearQuery() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _query = '';
      _committed = false;
    });
    _focus.requestFocus();
  }

  Future<void> _forgetRecent(String term) async {
    final next = await RecentSearches.remove(term);
    if (mounted) setState(() => _recent = next);
  }

  Future<void> _clearRecent() async {
    final next = await RecentSearches.clear();
    if (mounted) setState(() => _recent = next);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await _repo.fetchWebFeed(
        limit: 20,
        sort: 'recent',
        entityTypes: _filter.entityTypes,
        liveOnly: _filter.liveOnly,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _cursor = page.nextCursor;
        _loading = false;
      });
      FeedCardActions.seedRows(_store, page.items);
      unawaited(_hydrateInteractions(page.items));
    } catch (e) {
      logger.w('Search feed failed', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.fetchWebFeed(
        limit: 20,
        sort: 'recent',
        cursor: _cursor,
        entityTypes: _filter.entityTypes,
        liveOnly: _filter.liveOnly,
      );
      if (!mounted) return;
      FeedCardActions.seedRows(_store, page.items);
      setState(() {
        _items = [..._items, ...page.items];
        _cursor = page.nextCursor;
        _loadingMore = false;
      });
      unawaited(_hydrateInteractions(page.items));
    } catch (e) {
      logger.w('Search page failed', error: e);
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _selectFilter(SearchFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _load();
  }

  void _open(WebFeedItem item) {
    // The click beacon belongs to the surface that was activated, and goes out
    // before navigation.
    getIt<AnalyticsService>().trackContentClick(
      mediaId: item.entityId,
      contentType: ContentTypes.fromEntityType(item.entityType),
      creatorId: item.creator?.creatorId ?? '',
      mediaType: item.mediaType,
      source: AnalyticsSource.search,
      promotion: item.promotion,
    );
    if (item.isCreatorRow) {
      openCreatorProfile(context, creatorId: item.profileCreatorId);
      return;
    }
    openContentDetail(context, item, source: AnalyticsSource.search);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SearchHeaderField(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onQueryChanged,
              onSubmitted: _commit,
              onClear: _clearQuery,
            ),
            // The type filter belongs to the results state only; while the
            // reader is still typing it would be narrowing nothing.
            if (_phase == _Phase.results)
              SearchTypeTabs(selected: _filter, onSelected: _selectFilter),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() => switch (_phase) {
    _Phase.browsing => _browsing(),
    _Phase.typing => _typing(),
    _Phase.results => _resultsList(),
  };

  /// Empty field: what was searched before, and what can be browsed.
  Widget _browsing() {
    return ListView(
      padding: EdgeInsets.only(top: 8.s, bottom: 110.s),
      children: [
        if (_recent.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(20.s, 0, 20.s, 10.s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.searchRecent,
                  style: AppStyles.label(
                    12,
                    weight: AppStyles.black,
                    color: AppColors.neutral400,
                    lineHeight: 16 / 12,
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _clearRecent,
                  child: Text(
                    AppStrings.searchClearRecent,
                    style: AppStyles.label(12, color: AppColors.neutral400),
                  ),
                ),
              ],
            ),
          ),
          for (final term in _recent)
            RecentSearchRow(
              term: term,
              onTap: () => _commit(term),
              onRemove: () => _forgetRecent(term),
            ),
          SizedBox(height: 24.s),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(20.s, 0, 20.s, 10.s),
          child: Text(
            AppStrings.searchBrowse,
            style: AppStyles.label(
              12,
              weight: AppStyles.black,
              color: AppColors.neutral400,
              lineHeight: 16 / 12,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.s),
          child: CategoryChipGrid(
            categories: ExploreDummyData.categories,
            onSelected: (c) => _commit(c.label),
          ),
        ),
      ],
    );
  }

  /// Mid-query: completions over a preview of what already matches.
  Widget _typing() {
    final suggestions = SearchSuggestions.forQuery(_query);
    return ListView(
      padding: EdgeInsets.only(top: 8.s, bottom: 110.s),
      children: [
        for (final phrase in suggestions)
          SearchSuggestionRow(
            phrase: phrase,
            onTap: () => _commit(phrase),
            onFill: () {
              _controller.text = phrase;
              _controller.selection = TextSelection.collapsed(
                offset: phrase.length,
              );
              setState(() => _query = phrase);
            },
          ),
        if (suggestions.isNotEmpty) SizedBox(height: 16.s),
        ..._groups(),
      ],
    );
  }

  Widget _resultsList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }
    if (_failed) return ErrorStateView(onRetry: _load);

    final groups = _groups();
    if (groups.isEmpty) return _empty();

    return ListView(
      controller: _scroll,
      padding: EdgeInsets.only(top: 8.s, bottom: 110.s),
      children: [
        ...groups,
        if (_cursor != null)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.s),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.brandPrimary),
            ),
          ),
      ],
    );
  }

  /// The grouped rows, shared by the typing preview and the results list.
  List<Widget> _groups() {
    final out = <Widget>[];
    for (final group in SearchGrouping.apply(_results)) {
      out.add(SearchGroupHeader(label: group.kind.heading));
      for (final item in group.items) {
        out.add(
          PromotedImpressionTracker(
            promotion: item.promotion,
            mediaId: item.entityId,
            contentType: ContentTypes.fromEntityType(item.entityType),
            creatorId: item.creator?.creatorId ?? '',
            mediaType: item.mediaType,
            source: AnalyticsSource.search,
            child: _row(group.kind, item),
          ),
        );
      }
      out.add(SizedBox(height: 20.s));
    }
    return out;
  }

  Widget _row(SearchGroupKind kind, WebFeedItem item) => switch (kind) {
    SearchGroupKind.ministries => SearchMinistryRow(
      item: item,
      following: _store.isFollowing(
        item.profileCreatorId ?? '',
        fallback: item.isFollowingCreator,
      ),
      onTap: () => _open(item),
      onFollow: _actions.follow(item),
      onMore: () => _requireAccount('use that'),
    ),
    SearchGroupKind.events => SearchEventRow(
      item: item,
      onTap: () => _open(item),
      onRsvp: () => _requireAccount('RSVP'),
    ),
    _ => SearchContentRow(
      item: item,
      kindLabel: kind.rowLabel,
      onTap: () => _open(item),
      onMore: () => _requireAccount('use that'),
    ),
  };

  Widget _empty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              color: AppColors.neutral700,
              size: 44.s,
            ),
            SizedBox(height: 16.s),
            Text(
              'Nothing matched "$_query"',
              textAlign: TextAlign.center,
              style: AppStyles.heading(16),
            ),
            SizedBox(height: 8.s),
            Text(
              'Try a different word, or widen the filter above.',
              textAlign: TextAlign.center,
              style: AppStyles.body(13, color: AppColors.neutral400),
            ),
            if (_cursor != null) ...[
              SizedBox(height: 20.s),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _loadMore,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.s,
                    vertical: 10.s,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.s),
                    border: Border.all(color: AppColors.neutral700),
                  ),
                  child: Text(
                    _loadingMore ? 'Loading…' : 'Look further back',
                    style: AppStyles.label(13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
