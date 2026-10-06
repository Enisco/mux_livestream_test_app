import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:test_app/features/library/repo/viewer_library_repo.dart';
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/models/library_models/playlist_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// The reader's own running orders.
///
/// **Staging and the integration guide disagree about these routes**, and
/// what follows matches staging, probed on 2026-10-06. See
/// `docs/OPEN_ISSUES.md`; the differences are not small:
///
/// - **`visibility` cannot be written.** The guide documents it on create and
///   on PATCH; both answer "property visibility should not exist". Every
///   playlist is `private`, so the design's "Anyone with the link" group has
///   nothing to hold.
/// - **The detail read does not carry its items.** The guide says `items`
///   arrive as media search hits ready to render; staging returns
///   `orderedMediaIds` and nothing else, so this class hydrates them the way
///   the Explore rails hydrate continue-watching — one search, then the
///   playlist's own order put back.
/// - **There is no public read.** `/v1/public/media/playlists/:id` answers
///   `Cannot GET`, so a playlist cannot be shared at all yet.
/// - **No `owner` or `unavailableCount`** comes back either, so the detail
///   screen cannot name whose list it is or say how much of it has gone.
///
/// What the guide gets right:
///
/// - The list is a Prisma advanced search, so it pages by number
///   (`?page=&limit=`) with a `{data, meta}` envelope — not the cursor the
///   discovery feeds use. Searching is a `title.contains` filter, not a `q`.
/// - **Adding is not idempotent.** A duplicate answers 409 "Media is already
///   in this playlist" rather than quietly doing nothing, and a playlist
///   holds at most 500 items.
class PlaylistRepo {
  PlaylistRepo({ApiService? api}) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? GetIt.instance<ApiService>();

  /// At most this many items in one playlist (`MEDIA_PLAYLIST_SERIES_MAX_ITEMS`).
  static const maxItems = 500;

  /// `POST /v1/media/playlists/search`.
  Future<List<Playlist>> search({String? query, int page = 1}) async {
    final response = await _api.post(
      '${ApiEndpoints.playlistSearch}?page=$page&limit=50',
      data: {
        if (query != null && query.trim().isNotEmpty)
          'filters': {
            'title': {'contains': query.trim()},
          },
        'sort': [
          {'field': 'updatedAt', 'direction': 'desc'},
        ],
      },
    );
    final data = _data(response.data);
    return _rows(data['data']).map(_summary).toList();
  }

  /// `GET /v1/media/playlists/:id` — the owner read, items included.
  /// `GET /v1/media/playlists/:id`, then one search to put titles and
  /// artwork on the ids it returns.
  ///
  /// Search ranks by relevance, so the playlist's own order is restored
  /// afterwards — and an id the search cannot resolve is dropped and counted
  /// as unavailable rather than drawn blank.
  Future<Playlist> fetch(String id) async {
    final response = await _api.get(ApiEndpoints.playlist(id));
    final json = _data(response.data);
    final ids = [
      for (final v in json['orderedMediaIds'] as List? ?? const [])
        if (v is String) v,
    ];
    return _detail(json, await _hydrate(ids));
  }

  /// Turn ids into rows, in the order the playlist holds them.
  Future<List<HistoryEntry>> _hydrate(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final response = await _api.post(
      ApiEndpoints.publicSearch,
      data: {
        'entityTypes': ['media'],
        'filters': [
          {'field': 'entityId', 'values': ids},
        ],
        'size': ids.length,
      },
    );
    final byId = {
      for (final row in _rows(_data(response.data)['hits']))
        row['entityId'] as String? ?? '': _item(row),
    };
    return [for (final id in ids) ?byId[id]];
  }

  Future<Playlist> create({required String title, String? description}) async {
    final response = await _api.post(
      ApiEndpoints.playlists,
      // No `visibility`: staging refuses it, and every playlist is private.
      data: {'title': title, 'description': ?description},
    );
    return _detail(_data(response.data), const []);
  }

  /// `PATCH /v1/media/playlists/:id`.
  ///
  /// Omitting a key leaves it unchanged; [clearDescription] sends an explicit
  /// `null`, which is what empties it.
  Future<void> update(
    String id, {
    String? title,
    String? description,
    bool clearDescription = false,
  }) async {
    await _api.patch(
      ApiEndpoints.playlist(id),
      data: {
        'title': ?title,
        if (clearDescription)
          'description': null
        else
          'description': ?description,
      },
    );
  }

  Future<void> delete(String id) => _api.delete(ApiEndpoints.playlist(id));

  /// Add one media. Throws on a duplicate — see [PlaylistAddOutcome].
  Future<void> addItem(String playlistId, String mediaId) => _api.post(
    ApiEndpoints.playlistItems(playlistId),
    data: {'mediaId': mediaId},
  );

  Future<void> removeItem(String playlistId, String mediaId) =>
      _api.delete(ApiEndpoints.playlistItem(playlistId, mediaId));

  // ---- Mapping ----------------------------------------------------------

  /// A list row: no items, just the cover and the count.
  static Playlist _summary(Map<String, dynamic> json) {
    final cover = json['cover'] as Map<String, dynamic>?;
    final art = cover == null
        ? null
        : AssetUrlResolver.imageFor(
            url: cover['thumbnailUrl'] as String?,
            key: cover['thumbnailKey'] as String?,
          );
    return Playlist(
      id: json['id'] as String? ?? '',
      name: json['title'] as String? ?? '',
      updatedAgo: shortAge(
        DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      ),
      covers: [?art],
      items: const [],
      isPrivate: json['visibility'] != 'public',
      // The card's label is `itemCount`, never the length of a partially
      // loaded items array.
      declaredCount: (json['itemCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// A detail read, with the rows its ids hydrated to.
  static Playlist _detail(Map<String, dynamic> json, List<HistoryEntry> items) {
    final declared = (json['itemCount'] as num?)?.toInt() ?? items.length;
    return Playlist(
      id: json['id'] as String? ?? '',
      name: json['title'] as String? ?? '',
      updatedAgo: shortAge(
        DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      ),
      covers: [for (final item in items) ?item.thumbnailUrl],
      items: items,
      isPrivate: json['visibility'] != 'public',
      declaredCount: declared,
      runtime: _runtime(items),
      // Nothing the search could not resolve: deleted, or no longer public.
      unavailableCount: (declared - items.length).clamp(0, declared),
      description: json['description'] as String?,
    );
  }

  static HistoryEntry _item(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    final facets = json['facets'] as Map<String, dynamic>? ?? const {};
    final creator = json['creator'] as Map<String, dynamic>?;
    final seconds = (meta['durationSeconds'] as num?)?.toDouble();
    return HistoryEntry(
      id: json['entityId'] as String? ?? json['id'] as String? ?? '',
      kind: facets['mediaType'] == 'music'
          ? HistoryKind.audio
          : HistoryKind.video,
      title: json['title'] as String? ?? '',
      creatorName: creator?['displayName'] as String? ?? '',
      creatorVerified:
          creator?['isVerified'] as bool? ?? creator?['verifiedAt'] != null,
      age: shortAge(DateTime.tryParse(meta['publishedAt'] as String? ?? '')),
      thumbnailUrl: AssetUrlResolver.imageFor(
        url: meta['thumbnailUrl'] as String?,
        key: meta['thumbnailKey'] as String?,
      ),
      count: (facets['analyticsViews'] as num?)?.toInt() ?? 0,
      duration: seconds == null ? null : clock(seconds),
      targetType: 'media',
    );
  }

  /// "3h 24m" — the whole thing end to end.
  ///
  /// A playlist holding something whose runtime is unknown is left without a
  /// total rather than quietly under-reporting it.
  static String _runtime(List<HistoryEntry> items) {
    var total = Duration.zero;
    for (final item in items) {
      final d = item.duration;
      if (d == null) return '';
      final parts = d.split(':').map(int.tryParse).toList();
      if (parts.any((p) => p == null)) return '';
      total += parts.length == 3
          ? Duration(hours: parts[0]!, minutes: parts[1]!, seconds: parts[2]!)
          : Duration(minutes: parts[0]!, seconds: parts[1]!);
    }
    if (total == Duration.zero) return '';
    final minutes = total.inMinutes;
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  /// Build a detail without a network, for tests that pin the arithmetic.
  @visibleForTesting
  static Playlist debugDetail(
    Map<String, dynamic> json,
    List<HistoryEntry> items,
  ) => _detail(json, items);

  static Map<String, dynamic> _data(Object? body) {
    final data = (body as Map<String, dynamic>?)?['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  static List<Map<String, dynamic>> _rows(Object? rows) => [
    for (final row in rows as List? ?? const [])
      if (row is Map<String, dynamic>) row,
  ];
}
