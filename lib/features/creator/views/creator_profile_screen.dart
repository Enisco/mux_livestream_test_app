import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizing/sizing.dart';

import 'package:go_router/go_router.dart';

import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/analytics/views/widgets/promoted_impression_tracker.dart';
import 'package:test_app/features/creator/views/widgets/creator_profile_parts.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/discovery/views/content_detail_screen.dart';
import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/data/feed_card_actions.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/home/data/feed_card_mapper.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'package:test_app/features/home/views/widgets/home_loader.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/creator_models/creator_profile.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/shared/components/auth_sheet.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';

/// Opens the creator profile. Every creator affordance in the app routes here —
/// feed card avatars and names, following suggestions, event and livestream
/// rows, and the detail screens' creator row.
void openCreatorProfile(
  BuildContext context, {
  String? creatorId,
  String? handle,
}) {
  if ((creatorId == null || creatorId.isEmpty) &&
      (handle == null || handle.isEmpty)) {
    return;
  }
  context.push(
    creatorId != null && creatorId.isNotEmpty
        ? AppRouter.creatorProfileById(creatorId)
        : AppRouter.creatorProfileByHandle(handle!),
  );
}

/// Creator profile, viewer's point of view (Figma `11117-123441`).
///
/// Reachable by id from anywhere a creator is named, or by handle from a link.
class CreatorProfileScreen extends StatefulWidget {
  const CreatorProfileScreen({super.key, this.creatorId, this.handle})
    : assert(
        creatorId != null || handle != null,
        'need a creator id or a handle',
      );

  final String? creatorId;
  final String? handle;

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  final _repo = getIt<DiscoveryRepo>();
  final _playback = getIt<PlaybackController>();
  final _engagement = getIt<EngagementRepo>();
  final _store = getIt<EngagementStore>();
  late final _actions = FeedCardActions(
    store: _store,
    requireAccount: _requireAccount,
  );

  CreatorProfile? _profile;
  bool _loading = true;
  bool _failed = false;
  bool _authed = false;
  bool _followBusy = false;

  CreatorTab _tab = CreatorTab.latest;

  /// Rows per tab, so switching back does not refetch.
  final Map<CreatorTab, List<WebFeedItem>> _rows = {};
  final Set<CreatorTab> _loaded = {};
  bool _tabLoading = false;
  List<CreatorTestimony> _testimonies = const [];
  List<LibrarySection> _library = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _authed = await getIt<TokenStorageService>().hasSession;
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final profile = widget.creatorId != null
          ? await _repo.fetchCreatorById(widget.creatorId!)
          : await _repo.fetchCreatorByHandle(widget.handle!);
      if (!mounted) return;
      _store.seedFollowing(profile.id, profile.isFollowing);
      setState(() {
        _profile = profile;
        _loading = false;
      });
      await _loadTab(_tab);
    } catch (e) {
      logger.e('Creator profile load failed', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _loadTab(CreatorTab tab) async {
    final id = _profile?.id;
    if (id == null || id.isEmpty || _loaded.contains(tab)) return;
    setState(() => _tabLoading = true);
    try {
      switch (tab) {
        case CreatorTab.latest:
          final result = await _repo.fetchCreatorFeed(id);
          _rows[tab] = result.items;
        case CreatorTab.library:
          // The design groups the library by section, so they stay separate.
          final results = await Future.wait(
            LibrarySection.order.keys.map(
              (key) => _repo
                  .fetchCreatorLibrary(id, key)
                  .then(
                    (r) => LibrarySection(
                      key: key,
                      title: LibrarySection.order[key]!,
                      items: r.items,
                      total: r.total ?? r.items.length,
                    ),
                  )
                  .catchError((Object e) {
                    logger.w('library/$key failed', error: e);
                    return LibrarySection(
                      key: key,
                      title: LibrarySection.order[key]!,
                      items: const <WebFeedItem>[],
                    );
                  }),
            ),
          );
          _library = results.where((s) => s.items.isNotEmpty).toList();
        case CreatorTab.live:
          final result = await _repo.fetchCreatorFeed(id, limit: 20);
          _rows[tab] = result.items.where((i) => i.isLiveNow).toList();
        case CreatorTab.testimonies:
          _testimonies = await _repo.fetchCreatorTestimonies(id);
        case CreatorTab.about:
          break;
      }
      _loaded.add(tab);
      final rows = [
        ...?_rows[tab],
        ..._library.expand((section) => section.items),
      ];
      FeedCardActions.seedRows(_store, rows);
      unawaited(_hydrateInteractions(rows));
    } catch (e) {
      logger.w('Creator tab ${tab.label} failed', error: e);
    } finally {
      if (mounted) setState(() => _tabLoading = false);
    }
  }

  void _onTabChanged(CreatorTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _loadTab(tab);
  }

  bool _requireAccount(String feature) {
    if (_authed) return true;
    showAuthSheet(context, feature);
    return false;
  }

  /// The header's own follow button.
  ///
  /// The subscriber count is this screen's to keep — the store tracks the flag,
  /// which is what the cards below and every other surface read.
  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _followBusy) return;
    if (!_requireAccount('follow creators')) return;
    final was = _store.isFollowing(profile.id, fallback: profile.isFollowing);
    setState(() {
      _profile = profile.copyWith(
        subscriberCount: (profile.subscriberCount + (was ? -1 : 1)).clamp(
          0,
          1 << 31,
        ),
      );
      _followBusy = true;
    });
    await _store.toggleFollow(profile.id, fallback: profile.isFollowing);
    if (!mounted) return;
    // Rolled back by the store if the server refused, so the count follows it.
    if (_store.isFollowing(profile.id, fallback: profile.isFollowing) == was) {
      setState(() => _profile = profile);
    }
    setState(() => _followBusy = false);
  }

  void _openItem(WebFeedItem item) {
    openContentDetail(context, item, source: AnalyticsSource.creatorProfile);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(backgroundColor: AppColors.base1, body: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const HomeLoader();
    final loaded = _profile;
    if (_failed || loaded == null) {
      return SafeArea(child: ErrorStateView(onRetry: _loadProfile));
    }
    // The header's follow state comes from the store, so following from one of
    // the cards below — or from anywhere else in the session — shows here too.
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) => _content(
        loaded.copyWith(
          isFollowing: _store.isFollowing(
            loaded.id,
            fallback: loaded.isFollowing,
          ),
        ),
      ),
    );
  }

  Widget _content(CreatorProfile profile) {
    return RefreshIndicator(
      color: AppColors.brandPrimary,
      backgroundColor: AppColors.base1,
      onRefresh: () async {
        _loaded.clear();
        _rows.clear();
        _library = const [];
        await _loadProfile();
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: CreatorProfileHeader(
              profile: profile,
              busy: _followBusy,
              onBack: () => Navigator.of(context).maybePop(),
              onFollow: _toggleFollow,
              onGive: () => _requireAccount('give to this ministry'),
              onMore: () => _requireAccount('use that'),
            ),
          ),
          SliverToBoxAdapter(
            child: CreatorTabBar(selected: _tab, onChanged: _onTabChanged),
          ),
          ..._tabSlivers(profile),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 92.s + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _tabSlivers(CreatorProfile profile) {
    if (_tabLoading && !_loaded.contains(_tab)) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 64.s),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.brandPrimary),
            ),
          ),
        ),
      ];
    }

    if (_tab == CreatorTab.about) {
      return [SliverToBoxAdapter(child: CreatorAboutTab(profile: profile))];
    }

    if (_tab == CreatorTab.library) {
      if (_library.isEmpty) return [_emptySliver()];
      return [
        SliverToBoxAdapter(
          child: CreatorLibraryTab(
            sections: _library,
            onOpen: _openItem,
            onMore: (_) => _requireAccount('use that'),
          ),
        ),
      ];
    }

    if (_tab == CreatorTab.testimonies) {
      if (_testimonies.isEmpty) return [_emptySliver()];
      return [
        SliverList.builder(
          itemCount: _testimonies.length,
          itemBuilder: (_, i) => CreatorTestimonyCard(item: _testimonies[i]),
        ),
      ];
    }

    final rows = _rows[_tab] ?? const [];
    if (rows.isEmpty) return [_emptySliver()];
    return [
      SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (_, i) => PromotedImpressionTracker(
          promotion: rows[i].promotion,
          mediaId: rows[i].entityId,
          contentType: ContentTypes.fromEntityType(rows[i].entityType),
          creatorId: rows[i].creator?.creatorId ?? widget.creatorId ?? '',
          mediaType: rows[i].mediaType,
          source: AnalyticsSource.creatorProfile,
          child: FeedCard(
            data: FeedCardMapper.toCardData(rows[i]),
            onTap: () => _openItem(rows[i]),
            onCreatorTap: () => openCreatorProfile(
              context,
              creatorId: rows[i].profileCreatorId,
            ),
            onFollow: _actions.follow(rows[i]),
            onLike: _actions.like(rows[i]),
            onSave: _actions.save(rows[i]),
            onComment: _actions.comment(context, rows[i]),
            onMore: () => _requireAccount('use that'),
            playback: _playback,
            engagement: _store,
            source: AnalyticsSource.creatorProfile,
          ),
        ),
      ),
    ];
  }

  /// Fills in the viewer's own like/save state for rows just loaded.
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

  Widget _emptySliver() => SliverToBoxAdapter(
    child: CreatorTabEmptyState(
      tab: _tab,
      onAction: () => _requireAccount(_tab.emptyActionFeature),
    ),
  );
}
