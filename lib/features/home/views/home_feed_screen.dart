import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/analytics/views/widgets/promoted_impression_tracker.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart';
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

/// The home feed. Public: a guest sees the same Discover content as a signed-in
/// viewer, and only hits the auth wall on Following or when acting on a card.
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

  /// Design's chip rail. The API taxonomy doesn't match these yet, so they are
  /// display-only until that's resolved — see docs/OPEN_ISSUES.md.
  static const _topics = [
    'Trending',
    'Worship',
    'Preaching',
    'Bible Study',
    'Youth',
  ];

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

  /// Guests use `explore_only`, which the gateway serves unauthenticated.
  String get _mode => _authed ? 'mixed' : 'explore_only';

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await _repo.fetchWebFeed(mode: _mode);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _cursor = result.nextCursor;
        _loading = false;
      });
    } catch (e) {
      logger.e('Home feed load failed', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _cursor == null) return;
    _loadingMore = true;
    try {
      final result = await _repo.fetchWebFeed(cursor: _cursor, mode: _mode);
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

  void _onTabChanged(HomeTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  /// Everything that writes to an account is gated; browsing never is.
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
            onTopicChanged: (t) => setState(() => _topic = t),
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
    if (_loading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }
    if (_failed && _items.isEmpty) {
      return _Empty(
        title: AppStrings.failedToLoad,
        body: AppStrings.feedEmptyBody,
        actionLabel: AppStrings.feedRetry,
        onAction: _load,
      );
    }
    if (_items.isEmpty) {
      return const _Empty(
        title: AppStrings.feedEmptyTitle,
        body: AppStrings.feedEmptyBody,
      );
    }

    return RefreshIndicator(
      color: AppColors.brandPrimary,
      backgroundColor: AppColors.base1,
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        // Clears the floating nav pill, which the body extends underneath.
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
            data: _toCardData(item),
            onTap: () => _openItem(item),
            // The creator profile screen is a later section; the row opens the
            // item until it exists.
            onCreatorTap: () => _openItem(item),
            onFollow: () => _requireAccount('follow creators'),
            onLike: () => _requireAccount('like this'),
            onSave: () => _requireAccount('save this'),
            onComment: () => _openItem(item),
            onMore: () => _requireAccount('use that'),
          );

          // The billable impression belongs to this row — the surface that
          // served the placement.
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

  FeedCardData _toCardData(WebFeedItem item) {
    final meta = item.meta;
    final facets = item.facets;
    final creator = item.creator;
    final kind = _kindOf(item);
    final isChannel = kind == FeedCardKind.channel;
    // A `creator` row is *about* the creator: its name is the item title and
    // its handle the subtitle. Everything else nests them under `creator`.
    final name = isChannel
        ? item.title
        : creator?.displayName ?? AppStrings.brandName;
    final handle = isChannel
        ? (item.subtitle ?? '').replaceFirst('@', '')
        : creator?.handle ?? '';
    return FeedCardData(
      id: item.entityId,
      kind: kind,
      creatorName: name.isEmpty ? AppStrings.brandName : name,
      handle: handle,
      age: relativeAge(meta.publishedAt),
      title: isChannel || item.title.isEmpty ? null : item.title,
      // The feed exposes no bio, so a channel card shows none; blogs reuse
      // `subtitle` as the excerpt.
      body: kind == FeedCardKind.blog ? _excerpt(item.subtitle) : null,
      subtitle: kind == FeedCardKind.devotional
          ? _excerpt(item.subtitle)
          : null,
      planLabel: kind == FeedCardKind.devotional
          ? _planLabel(facets.categorySlugs)
          : null,
      category: facets.categorySlugs.isEmpty
          ? null
          : _titleCase(facets.categorySlugs.first),
      eventStart: meta.scheduledAt,
      thumbnailUrl: meta.thumbnailUrl,
      duration: _duration(meta.durationSeconds),
      verified: creator?.isVerified ?? false,
      avatarUrl: meta.thumbnailUrl != null && isChannel
          ? meta.thumbnailUrl
          : null,
      sponsored: item.isPromoted,
      likes: facets.likes,
      saves: facets.favorites,
      comments: facets.comments,
      views: facets.views > 0 ? formatCount(facets.views) : null,
      viewCount: facets.views,
      following: item.isFollowingCreator || (creator?.isFollowing ?? false),
      subscribers: creator?.subscriberCount ?? 0,
    );
  }

  FeedCardKind _kindOf(WebFeedItem item) {
    if (item.isLiveNow) return FeedCardKind.live;
    return switch (item.entityType) {
      'creator' => FeedCardKind.channel,
      'event' => FeedCardKind.event,
      'post' => FeedCardKind.post,
      // Devotionals are titled prose with a cover, which is the blog layout.
      // The design also has dedicated "Devotional plan" and series cards that
      // aren't built yet — see docs/OPEN_ISSUES.md.
      'blog' || 'devotional_entry' => FeedCardKind.blog,
      'devotional_series' => FeedCardKind.devotional,
      'media_series' => FeedCardKind.series,
      _ => switch (item.mediaType) {
        MediaTypes.music => FeedCardKind.audio,
        MediaTypes.livestream => FeedCardKind.live,
        _ => FeedCardKind.video,
      },
    };
  }

  /// The feed has no excerpt field, so `subtitle` stands in — but for some
  /// entity types it is only status metadata ("public · active"), which must
  /// not be shown as body copy.
  static const _statusWords = {
    'public',
    'private',
    'unlisted',
    'draft',
    'active',
    'inactive',
    'archived',
    'published',
    'scheduled',
    'video',
    'music',
    'livestream',
  };

  static String? _excerpt(String? subtitle) {
    if (subtitle == null || subtitle.trim().isEmpty) return null;
    final parts = subtitle
        .split(RegExp(r'[·•|]'))
        .map((p) => p.trim().toLowerCase())
        .where((p) => p.isNotEmpty);
    if (parts.isNotEmpty && parts.every(_statusWords.contains)) return null;
    return subtitle;
  }

  /// The design overlays a plan length ("14-day devotional plan"). The feed
  /// doesn't expose one, so the category stands in until it does.
  static String? _planLabel(List<String> slugs) =>
      slugs.isEmpty ? null : '${_titleCase(slugs.first)} plan';

  static String _titleCase(String slug) => slug
      .split(RegExp(r'[-_ ]'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  String? _duration(double? seconds) {
    if (seconds == null || seconds <= 0) return null;
    final total = seconds.round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Following has nothing to show a guest — the feed is built from who you
/// follow, which needs an account.
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
