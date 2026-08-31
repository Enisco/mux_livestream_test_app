import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/analytics/views/widgets/promoted_impression_tracker.dart';
import 'package:test_app/features/creator/views/creator_profile_screen.dart';
import 'package:test_app/features/discovery/data/search_query.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/data/feed_card_actions.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/discovery/views/content_detail_screen.dart';
import 'package:test_app/features/home/data/feed_card_mapper.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/auth_sheet.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/services/analytics_service.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Explore: browse the catalogue by kind and topic, and narrow it by typing.
///
/// The discovery API has no free-text search route, so a typed query filters
/// what the feed returned rather than what it asks for. Kind and topic *are*
/// server-side filters, so those genuinely change the request.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _repo = getIt<DiscoveryRepo>();
  final _playback = getIt<PlaybackController>();
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  /// Topic labels to the category slugs the API knows.
  static const _topics = <String, String>{
    'Worship': 'worship',
    'Preaching': 'sermons',
    'Bible Study': 'bible-study',
    'Youth': 'youth',
  };

  SearchFilter _filter = SearchFilter.all;
  String? _topic;
  String _query = '';
  Timer? _debounce;

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

  List<WebFeedItem> get _results =>
      SearchMatcher.apply(_items, _query, _filter);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _init();
  }

  Future<void> _init() async {
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
      if (mounted) setState(() => _query = value.trim());
    });
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
        categorySlugs: _topic == null ? null : [_topic!],
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
        categorySlugs: _topic == null ? null : [_topic!],
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

  void _selectTopic(String? slug) {
    if (slug == _topic) return;
    setState(() => _topic = slug);
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
            _buildHeader(),
            _buildFilters(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.s, 8.s, 16.s, 12.s),
      child: Row(
        children: [
          const GTubeBackButton(),
          SizedBox(width: 10.s),
          Expanded(
            child: Container(
              height: 44.s,
              padding: EdgeInsets.symmetric(horizontal: 14.s),
              decoration: BoxDecoration(
                color: AppColors.neutral900,
                borderRadius: BorderRadius.circular(22.s),
                border: Border.all(color: AppColors.neutral800),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    color: AppColors.neutral400,
                    size: 18,
                  ),
                  SizedBox(width: 10.s),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: _onQueryChanged,
                      textInputAction: TextInputAction.search,
                      style: AppStyles.body(14),
                      cursorColor: AppColors.brandPrimary,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Search GospelTube',
                        hintStyle: AppStyles.body(
                          14,
                          color: AppColors.neutral400,
                        ),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                      child: Padding(
                        padding: EdgeInsets.only(left: 6.s),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.neutral400,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 36.s,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.s),
            children: [
              for (final filter in SearchFilter.values) ...[
                _Chip(
                  label: filter.label,
                  selected: filter == _filter,
                  onTap: () => _selectFilter(filter),
                ),
                SizedBox(width: 8.s),
              ],
            ],
          ),
        ),
        SizedBox(height: 8.s),
        SizedBox(
          height: 32.s,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.s),
            children: [
              _Chip(
                label: 'Any topic',
                selected: _topic == null,
                subtle: true,
                onTap: () => _selectTopic(null),
              ),
              SizedBox(width: 8.s),
              for (final entry in _topics.entries) ...[
                _Chip(
                  label: entry.key,
                  selected: _topic == entry.value,
                  subtle: true,
                  onTap: () => _selectTopic(entry.value),
                ),
                SizedBox(width: 8.s),
              ],
            ],
          ),
        ),
        SizedBox(height: 12.s),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }
    if (_failed) return ErrorStateView(onRetry: _load);

    final results = _results;
    if (results.isEmpty) return _buildEmpty();

    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.only(bottom: 110.s),
      itemCount: results.length + (_cursor == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index >= results.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 24.s),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.brandPrimary),
            ),
          );
        }
        final item = results[index];
        return PromotedImpressionTracker(
          promotion: item.promotion,
          mediaId: item.entityId,
          contentType: ContentTypes.fromEntityType(item.entityType),
          creatorId: item.creator?.creatorId ?? '',
          mediaType: item.mediaType,
          source: AnalyticsSource.search,
          child: FeedCard(
            data: FeedCardMapper.toCardData(item),
            playback: _playback,
            engagement: _store,
            source: AnalyticsSource.search,
            onTap: () => _open(item),
            onCreatorTap: () =>
                openCreatorProfile(context, creatorId: item.profileCreatorId),
            onFollow: _actions.follow(item),
            onLike: _actions.like(item),
            onSave: _actions.save(item),
            onComment: _actions.comment(context, item),
            onMore: () => _requireAccount('use that'),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    final searching = _query.isNotEmpty;
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
              searching ? 'Nothing matched "$_query"' : 'Nothing here yet',
              textAlign: TextAlign.center,
              style: AppStyles.heading(16),
            ),
            SizedBox(height: 8.s),
            Text(
              searching
                  ? 'Try a different word, or widen the filters above.'
                  : 'Try another kind of content or topic.',
              textAlign: TextAlign.center,
              style: AppStyles.body(13, color: AppColors.neutral400),
            ),
            if (searching && _cursor != null) ...[
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtle = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 14.s),
        decoration: BoxDecoration(
          color: selected
              ? (subtle ? AppColors.brandPrimary : AppColors.textPrimary)
              : AppColors.neutral900,
          borderRadius: BorderRadius.circular(18.s),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.neutral800,
          ),
        ),
        child: Text(
          label,
          style: AppStyles.label(
            subtle ? 12 : 13,
            color: selected
                ? (subtle ? AppColors.textPrimary : AppColors.base1)
                : AppColors.neutral400,
            weight: AppStyles.bold,
          ),
        ),
      ),
    );
  }
}
