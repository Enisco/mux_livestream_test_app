import 'dart:async';

import 'package:get_it/get_it.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/explore_models/explore_models.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';
import 'package:test_app/shared/services/token_storage_service.dart';

/// Everything on the Explore tab, in one load.
///
/// **Explore introduces no routes of its own.** Every rail is a composition of
/// reads that already exist — mostly `POST /v1/search/public/query` with no
/// `q` and a `sort`, which is the supported way to browse a catalogue. (A
/// `"*"` wildcard is not, and does not behave.)
///
/// Two things shape this class:
///
/// - **Search hits carry no creator.** The index stores `meta.creatorId` and
///   nothing else, so each rail of content needs one further query to put a
///   name and an avatar under its cards. They are batched per load, not per
///   card.
/// - **An empty rail is hidden, not drawn empty.** A browse that returns
///   nothing means "not right now"; a heading over no cards reads as a claim
///   that the category has nothing in it.
class ExploreRepo {
  ExploreRepo({DiscoveryRepo? discovery})
    : _discovery = discovery ?? GetIt.instance<DiscoveryRepo>();

  final DiscoveryRepo _discovery;

  /// Load every rail at once.
  ///
  /// Each rail is independent: one failing leaves the rest alone and simply
  /// does not appear, because a half-drawn Explore is better than an error
  /// page over content that loaded fine.
  Future<ExplorePage> load() async {
    // Continue watching is signed-in only. Asking anonymously would just
    // earn a 401 per load, and the guide says to hide the rail rather than
    // render it empty.
    final signedIn = await GetIt.instance<TokenStorageService>().hasSession;

    // Started together, awaited after — the rails do not wait on each other.
    final trending = _rail(() => _media(sort: 'trending', size: 10));
    final live = _rail(() => _media(liveOnly: true, size: 10));
    final unfinished = signedIn
        ? _rail(_continueWatching)
        : Future<List<ExploreCard>>.value(const []);
    final devotionals = _rail(
      () => _byType('devotional_series', sort: 'popular'),
    );
    final articles = _rail(() => _byType('post', sort: 'recent'));
    final ministries = _rail(_ministries);
    final events = _rail(_events);

    final top = await trending;

    return ExplorePage(
      // The banner is the top trending item rather than a sold placement:
      // search marks a promoted hit but mints no delivery token, so a
      // dedicated sponsored slot here could never record a billable
      // impression. See the note in the discovery guide.
      hero: top.isEmpty ? null : _hero(top.first),
      trending: top,
      live: await live,
      continueWatching: await unfinished,
      devotionals: await devotionals,
      articles: await articles,
      ministries: await ministries,
      events: await events,
    );
  }

  /// Run one rail, and let it fail alone.
  Future<List<T>> _rail<T>(Future<List<T>> Function() build) async {
    try {
      return await build();
    } catch (e) {
      logger.w('Explore rail unavailable', error: e);
      return const [];
    }
  }

  // ---- The rails --------------------------------------------------------

  Future<List<ExploreCard>> _media({
    String sort = 'relevance',
    bool liveOnly = false,
    int size = 10,
  }) async {
    final page = await _discovery.searchPublic(
      entityTypes: const ['media'],
      sort: sort,
      size: size,
      liveOnly: liveOnly,
    );
    return _cards(page.items);
  }

  Future<List<ExploreCard>> _byType(
    String entityType, {
    required String sort,
  }) async {
    final page = await _discovery.searchPublic(
      entityTypes: [entityType],
      sort: sort,
      size: 10,
    );
    return _cards(page.items);
  }

  /// What the reader left unfinished.
  ///
  /// The route answers with bare references, so the rows are hydrated by a
  /// second query and then **put back in the order the viewer watched in** —
  /// search ranks by relevance and will not preserve it.
  Future<List<ExploreCard>> _continueWatching() async {
    final refs = await _discovery.fetchContinueWatching(limit: 10);
    if (refs.isEmpty) return const [];

    final page = await _discovery.searchPublic(
      entityTypes: const ['media'],
      entityIds: [for (final r in refs) r.mediaId],
      size: refs.length,
    );
    final byId = {for (final item in page.items) item.entityId: item};
    final hydrated = <WebFeedItem>[];
    final progress = <String, double?>{};
    for (final ref in refs) {
      final item = byId[ref.mediaId];
      if (item == null) continue;
      hydrated.add(item);
      progress[ref.mediaId] = ref.progressAgainst(item.meta.durationSeconds);
    }
    final cards = await _cards(hydrated);
    return [
      for (final card in cards)
        ExploreCard(
          id: card.id,
          title: card.title,
          creator: card.creator,
          thumbnailUrl: card.thumbnailUrl,
          badge: card.badge,
          sponsored: card.sponsored,
          progress: progress[card.id],
          source: card.source,
        ),
    ];
  }

  Future<List<ExploreCreatorRef>> _ministries() async {
    final creators = await _discovery.fetchRecommendedCreators(limit: 10);
    return [
      for (final c in creators)
        ExploreCreatorRef(
          id: c.creatorId,
          name: c.displayName,
          handle: c.handle,
          avatarUrl: AssetUrlResolver.resolve(c.avatarKey),
          verified: c.isVerified,
          isOrganisation: c.type == 'organization',
          isFollowing: c.isFollowing,
        ),
    ];
  }

  Future<List<ExploreEvent>> _events() async {
    final items = await _discovery.fetchUpcomingEvents(limit: 10);
    return [
      for (final item in items)
        if (item.startsAt case final at?)
          ExploreEvent(
            id: item.entityId,
            title: item.title,
            day: at.day.toString().padLeft(2, '0'),
            month: _months[at.month - 1],
            venue: item.meta.locationLabel ?? '',
            time: _clock(at),
            // Event rows arrive with a creator summary already attached, so
            // unlike every other rail they need no second lookup.
            creator: ExploreCreatorRef(
              id: item.creator?.creatorId ?? '',
              name: item.creator?.displayName ?? '',
              handle: item.creator?.handle ?? '',
              avatarUrl: AssetUrlResolver.resolve(item.creator?.avatarKey),
              verified: item.creator?.isVerified ?? false,
              isOrganisation: item.creator?.type == 'organization',
            ),
            sponsored: item.isPromoted,
            source: item,
          ),
    ];
  }

  // ---- Hits to cards ----------------------------------------------------

  /// Map hits onto cards, resolving the creators in one further query.
  ///
  /// If that lookup fails the cards still render — without a byline rather
  /// than not at all.
  Future<List<ExploreCard>> _cards(List<WebFeedItem> hits) async {
    if (hits.isEmpty) return const [];
    final creators = await _creatorsFor(hits);
    return [
      for (final hit in hits)
        ExploreCard(
          id: hit.entityId,
          title: hit.title,
          creator:
              creators[hit.meta.creatorId] ??
              const ExploreCreatorRef(id: '', name: ''),
          thumbnailUrl: _artwork(hit),
          badge: _badge(hit),
          sponsored: hit.isPromoted,
          source: hit,
        ),
    ];
  }

  Future<Map<String, ExploreCreatorRef>> _creatorsFor(
    List<WebFeedItem> hits,
  ) async {
    final ids = {
      for (final hit in hits)
        if (hit.meta.creatorId case final id?)
          if (id.isNotEmpty) id,
    };
    if (ids.isEmpty) return const {};
    try {
      final page = await _discovery.searchPublic(
        entityTypes: const ['creator'],
        entityIds: ids.toList(),
        size: ids.length,
      );
      return {
        for (final row in page.items)
          row.entityId: ExploreCreatorRef(
            id: row.entityId,
            name: row.title,
            handle: row.creatorHandle,
            avatarUrl: AssetUrlResolver.resolve(row.meta.avatarKey),
            verified: row.meta.isVerified,
            isOrganisation: row.meta.creatorType == 'organization',
          ),
      };
    } catch (e) {
      logger.w('Explore creator lookup failed', error: e);
      return const {};
    }
  }

  /// `meta.thumbnailUrl` is usually null on a search hit; the key and the CDN
  /// are what it actually carries. A gateway proxy path in `thumbnailUrl` is
  /// used verbatim — rewriting it breaks the signature.
  static String? _artwork(WebFeedItem hit) =>
      hit.meta.thumbnailUrl ?? AssetUrlResolver.resolve(hit.meta.thumbnailKey);

  /// The pill in the corner: a runtime for media, a length for a series.
  static String? _badge(WebFeedItem hit) {
    if (hit.isLiveNow) return null;
    if (hit.meta.durationSeconds case final seconds?) {
      final total = seconds.round();
      final minutes = total ~/ 60;
      if (minutes >= 60) {
        return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
      }
      return '$minutes:${(total % 60).toString().padLeft(2, '0')}';
    }
    if (hit.meta.publishedEntryCount case final days?) {
      return days == 1 ? '1 day' : '$days days';
    }
    if (hit.meta.videoCount case final videos?) {
      return videos == 1 ? '1 video' : '$videos videos';
    }
    return null;
  }

  static ExploreHero _hero(ExploreCard top) => ExploreHero(
    id: top.id,
    title: top.title,
    description: '',
    creator: top.creator,
    backdropUrl: top.thumbnailUrl,
    source: top.source,
  );

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  static String _clock(DateTime at) {
    final local = at.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
  }
}

/// Everything the Explore tab draws, loaded once.
class ExplorePage {
  const ExplorePage({
    this.hero,
    this.trending = const [],
    this.live = const [],
    this.continueWatching = const [],
    this.devotionals = const [],
    this.articles = const [],
    this.ministries = const [],
    this.events = const [],
  });

  /// Null when nothing is trending — the panel is left out rather than
  /// drawn over an empty frame.
  final ExploreHero? hero;

  final List<ExploreCard> trending;
  final List<ExploreCard> live;
  final List<ExploreCard> continueWatching;
  final List<ExploreCard> devotionals;
  final List<ExploreCard> articles;
  final List<ExploreCreatorRef> ministries;
  final List<ExploreEvent> events;

  // There is no "topics you follow" rail here. `user-app` has one, built on
  // `preferenceBoostCategorySlugs`, but this app's design ends at Browse —
  // and `searchPublic` still takes the boost when a rail wants it.

  /// Nothing came back at all, as against one rail being quiet.
  bool get isEmpty =>
      hero == null &&
      trending.isEmpty &&
      live.isEmpty &&
      continueWatching.isEmpty &&
      devotionals.isEmpty &&
      articles.isEmpty &&
      ministries.isEmpty &&
      events.isEmpty;
}
