import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/analytics/views/widgets/promoted_impression_tracker.dart';
import 'package:test_app/features/creator/views/creator_profile_screen.dart';
import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/data/feed_card_actions.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/home/data/feed_autoplay_coordinator.dart';
import 'package:test_app/features/home/data/feed_card_mapper.dart';
import 'package:test_app/features/home/views/widgets/empty_tab_views.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'package:test_app/features/home/views/widgets/home_loader.dart';
import 'package:test_app/features/home/views/widgets/home_feed_header.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/features/discovery/views/content_detail_screen.dart';
import 'package:test_app/shared/components/auth_sheet.dart';
import 'package:test_app/shared/components/error_state_view.dart';
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

class _HomeFeedScreenState extends State<HomeFeedScreen>
    with WidgetsBindingObserver {
  final _repo = getIt<DiscoveryRepo>();
  final _playback = getIt<PlaybackController>();
  final _engagement = getIt<EngagementRepo>();
  final _store = getIt<EngagementStore>();
  final _scroll = ScrollController();
  late final _actions = FeedCardActions(
    store: _store,
    requireAccount: _requireAccount,
  );
  late final _autoplay = FeedAutoplayCoordinator(playback: _playback);

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
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoplay.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Nothing should autoplay behind a locked screen or another app; audio the
    // reader started is left alone, since that is the one thing meant to keep
    // going in the background.
    if (state == AppLifecycleState.resumed) {
      _autoplay.resume();
    } else {
      _autoplay.suspend();
    }
  }

  Future<void> _init() async {
    _authed = await getIt<TokenStorageService>().hasSession;
    if (mounted) await _load();
  }

  /// Fills in like/save state for rows just loaded.
  ///
  /// The feed payload does not carry the viewer's own interactions, so without
  /// this every card renders unliked until its detail screen is opened.
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
      final mine = await _engagement.fetchMyInteractions(
        targetType: entry.key,
        targetIds: entry.value,
      );
      if (!mounted) return;
      _store.seedInteractions(entry.key, mine);
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  /// Following needs a session; guests only ever get the public feed.
  ///
  /// `following_only` is rejected outright without auth ("Following feed
  /// requires authentication"), so it is never sent for a guest — the tab shows
  /// its empty state instead, which is where signing in is offered.
  String get _mode => switch (_tab) {
    HomeTab.following when _authed => 'following_only',
    _ => _authed ? 'mixed' : 'explore_only',
  };

  /// Whether this tab has anything to ask the API for.
  bool get _canQueryTab => _tab != HomeTab.following || _authed;

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
    if (!_canQueryTab) {
      setState(() {
        _items = const [];
        _cursor = null;
        _loading = false;
      });
      await _loadEmptyCompanions();
      return;
    }
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
      FeedCardActions.seedRows(_store, result.items);
      if (result.items.isEmpty) await _loadEmptyCompanions();
      unawaited(_hydrateInteractions(result.items));
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
      if (_tab == HomeTab.following && _suggestions.isEmpty) {
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
    if (_loadingMore || _loading || _cursor == null || !_canQueryTab) return;
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
      FeedCardActions.seedRows(_store, result.items);
      unawaited(_hydrateInteractions(result.items));
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
      contentType: ContentTypes.fromEntityType(item.entityType),
      creatorId: item.creator?.creatorId ?? '',
      mediaType: item.mediaType,
      source: AnalyticsSource.homeFeed,
      promotion: item.promotion,
    );
    openContentDetail(context, item, source: AnalyticsSource.homeFeed);
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
    if (_failed && _items.isEmpty) return ErrorStateView(onRetry: _load);
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
            // A channel row IS the creator, so its body opens the profile.
            onTap: () => item.isCreatorRow
                ? openCreatorProfile(context, creatorId: item.profileCreatorId)
                : _openItem(item),
            onCreatorTap: () =>
                openCreatorProfile(context, creatorId: item.profileCreatorId),
            onFollow: _actions.follow(item),
            onLike: _actions.like(item),
            onSave: _actions.save(item),
            // Straight to the thread rather than the detail page behind it:
            // the tap was on the comment count, not on the content.
            onComment: _actions.comment(context, item),
            onMore: () => _requireAccount('use that'),
            playback: _playback,
            coordinator: _autoplay,
            videoController: _playback.videoController,
            engagement: _store,
            source: AnalyticsSource.homeFeed,
          );

          return PromotedImpressionTracker(
            mediaId: item.entityId,
            contentType: ContentTypes.fromEntityType(item.entityType),
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
      onOpenCreator: (c) => openCreatorProfile(context, creatorId: c.creatorId),
      onEditTopics: () {
        if (_requireAccount('edit your topics')) {
          context.push(AppRouter.interests);
        }
      },
    ),
    HomeTab.live => LiveEmptyView(
      events: _upcoming,
      onOpenEvent: _openItem,
      onOpenCreator: (e) =>
          openCreatorProfile(context, creatorId: e.profileCreatorId),
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
