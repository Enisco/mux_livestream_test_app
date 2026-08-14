import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/analytics/views/widgets/promoted_impression_tracker.dart';
import 'package:test_app/features/home/data/feed_card_mapper.dart';
import 'package:test_app/features/home/views/widgets/empty_tab_views.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'package:test_app/features/home/views/widgets/home_loader.dart';
import 'package:test_app/features/home/views/widgets/home_feed_header.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/features/discovery/views/media_detail_screen.dart';
import 'package:test_app/shared/components/auth_sheet.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/analytics_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key, this.initialTab = HomeTab.discover});

  final HomeTab initialTab;

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final _repo = getIt<DiscoveryRepo>();
  final _scroll = ScrollController();

  late HomeTab _tab = widget.initialTab;
  String? _topic;
  List<WebFeedItem> _items = const [];
  String? _cursor;
  bool _loading = false;
  bool _loadingMore = false;
  bool _failed = false;
  bool _authed = false;

  /// Empty-tab companions. Fetched lazily, only when a tab comes up empty.
  List<RecommendedCreator> _suggestions = const [];
  List<WebFeedItem> _upcoming = const [];
  final Set<String> _followPending = {};

  /// Chip label → the category slugs the API knows. 'Trending' is a sort, not
  /// a category, so it carries no slugs.
  static const _topicSlugs = <String, List<String>>{
    'Trending': [],
    'Worship': ['worship'],
    'Preaching': ['sermons'],
    'Bible Study': ['bible-study'],
    'Youth': ['youth'],
  };

  static final _topics = _topicSlugs.keys.toList();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _authed = await getIt<TokenStorageService>().hasSession;
    if (mounted) await _load();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  /// Following needs a session; guests only ever get the public feed.
  String get _mode => switch (_tab) {
    HomeTab.following => 'following_only',
    _ => _authed ? 'mixed' : 'explore_only',
  };

  /// The Live tab is the same feed restricted to what is broadcasting now.
  bool get _liveOnly => _tab == HomeTab.live;

  String get _sort => _topic == 'Trending' ? 'trending' : 'recent';

  List<String> get _categorySlugs => _topicSlugs[_topic] ?? const [];

  /// With no chip picked, let the server lean on the viewer's saved interests.
  bool get _usePrefs => _authed && _topic == null;

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await _repo.fetchWebFeed(
        mode: _mode,
        sort: _sort,
        categorySlugs: _categorySlugs,
        liveOnly: _liveOnly,
        useViewerCategoryPrefs: _usePrefs,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _cursor = result.nextCursor;
        _loading = false;
      });
      if (result.items.isEmpty) await _loadEmptyCompanions();
    } catch (e) {
      logger.e('Home feed load failed', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// The designed empty states are not blank slates — Following offers
  /// ministries to follow, Live lists what is coming up.
  Future<void> _loadEmptyCompanions() async {
    try {
      if (_tab == HomeTab.following && _authed && _suggestions.isEmpty) {
        final creators = await _repo.fetchRecommendedCreators();
        if (mounted) setState(() => _suggestions = creators);
      } else if (_tab == HomeTab.live && _upcoming.isEmpty) {
        final events = await _repo.fetchUpcomingEvents();
        if (mounted) setState(() => _upcoming = events);
      }
    } catch (e) {
      logger.w('Empty-tab companions failed', error: e);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _cursor == null) return;
    _loadingMore = true;
    try {
      final result = await _repo.fetchWebFeed(
        cursor: _cursor,
        mode: _mode,
        sort: _sort,
        categorySlugs: _categorySlugs,
        liveOnly: _liveOnly,
        useViewerCategoryPrefs: _usePrefs,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...result.items];
        _cursor = result.nextCursor;
      });
    } catch (e) {
      logger.w('Home feed page failed', error: e);
    } finally {
      _loadingMore = false;
    }
  }

  /// Each tab is a different query, so switching has to refetch — otherwise
  /// Following and Live just re-show Discover's results.
  void _onTabChanged(HomeTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _items = const [];
      _cursor = null;
    });
    _load();
  }

  void _onTopicChanged(String? topic) {
    if (topic == _topic) return;
    setState(() {
      _topic = topic;
      _items = const [];
      _cursor = null;
    });
    _load();
  }

  Future<void> _toggleFollow(RecommendedCreator creator) async {
    if (!_requireAccount('follow creators')) return;
    setState(() => _followPending.add(creator.creatorId));
    try {
      await _repo.setFollowing(creator.creatorId, follow: !creator.isFollowing);
      if (!mounted) return;
      // Following someone means the tab has content now.
      setState(() {
        _suggestions = _suggestions
            .where((c) => c.creatorId != creator.creatorId)
            .toList();
      });
      await _load();
    } catch (e) {
      logger.w('Follow failed', error: e);
    } finally {
      if (mounted) {
        setState(() => _followPending.remove(creator.creatorId));
      }
    }
  }

  bool _requireAccount(String feature) {
    if (_authed) return true;
    showAuthSheet(context, feature);
    return false;
  }

  void _openItem(WebFeedItem item) {
    GetIt.instance<AnalyticsService>().trackContentClick(
      mediaId: item.entityId,
      creatorId: item.creator?.creatorId ?? '',
      mediaType: item.mediaType,
      source: AnalyticsSource.homeFeed,
      promotion: item.promotion,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MediaDetailScreen(item: item, source: AnalyticsSource.homeFeed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.base1,
      child: Column(
        children: [
          HomeFeedHeader(
            tab: _tab,
            onTabChanged: _onTabChanged,
            topics: _topics,
            selectedTopic: _topic,
            onTopicChanged: _onTopicChanged,
            onEditTopics: () {
              if (_requireAccount('edit your topics')) {
                context.push(AppRouter.interests);
              }
            },
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_tab == HomeTab.following && !_authed) {
      return const _FollowingAuthWall();
    }
    if (_loading && _items.isEmpty) return const HomeLoader();
    if (_failed && _items.isEmpty) {
      return _Empty(
        title: AppStrings.failedToLoad,
        body: AppStrings.feedEmptyBody,
        actionLabel: AppStrings.feedRetry,
        onAction: _load,
      );
    }
    if (_items.isEmpty) return _emptyForTab();

    return RefreshIndicator(
      color: AppColors.brandPrimary,
      backgroundColor: AppColors.base1,
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.only(
          bottom: 92 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: _items.length + (_cursor == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.brandPrimary),
              ),
            );
          }
          final item = _items[index];
          final card = FeedCard(
            data: FeedCardMapper.toCardData(item),
            onTap: () => _openItem(item),
            onCreatorTap: () => _openItem(item),
            onFollow: () => _requireAccount('follow creators'),
            onLike: () => _requireAccount('like this'),
            onSave: () => _requireAccount('save this'),
            onComment: () => _openItem(item),
            onMore: () => _requireAccount('use that'),
          );

          return PromotedImpressionTracker(
            mediaId: item.entityId,
            creatorId: item.creator?.creatorId ?? '',
            mediaType: item.mediaType,
            source: AnalyticsSource.homeFeed,
            promotion: item.promotion,
            child: card,
          );
        },
      ),
    );
  }

  Widget _emptyForTab() => switch (_tab) {
    HomeTab.following => FollowingEmptyView(
      suggestions: _suggestions,
      pending: _followPending,
      onFollow: _toggleFollow,
      onEditTopics: () {
        if (_requireAccount('edit your topics')) {
          context.push(AppRouter.interests);
        }
      },
    ),
    HomeTab.live => LiveEmptyView(
      events: _upcoming,
      onOpenEvent: _openItem,
      onMore: (_) => _requireAccount('use that'),
    ),
    HomeTab.discover => const _Empty(
      title: AppStrings.feedEmptyTitle,
      body: AppStrings.feedEmptyBody,
    ),
  };
}

class _FollowingAuthWall extends StatelessWidget {
  const _FollowingAuthWall();

  @override
  Widget build(BuildContext context) {
    return _Empty(
      title: AppStrings.feedFollowingGuestTitle,
      body: AppStrings.feedFollowingGuestBody,
      actionLabel: AppStrings.createAccount,
      onAction: () => showAuthSheet(context, 'follow creators'),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppStyles.heading(18, lineHeight: 24 / 18),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppStyles.body(13, color: AppColors.neutral400),
            ),
            if (actionLabel case final label?) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: PrimaryButton(
                  label: label,
                  height: 48,
                  onPressed: onAction ?? () {},
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
