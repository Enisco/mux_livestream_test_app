import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:test_app/features/library/repo/viewer_library_repo.dart';
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/library_models/playlist_models.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/s3_upload.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// The cover is bigger than the server will take, or the ticket came back
/// malformed. Read the ceiling off the ticket's `constraints` rather than
/// hard-coding it.
class PlaylistCoverTooLarge implements Exception {
  const PlaylistCoverTooLarge();
}

/// The reader's own running orders.
class PlaylistRepo {
  PlaylistRepo({ApiService? api, S3Send? send})
    : _injected = api,
      _send = send ?? S3PresignedUpload.send;

  final ApiService? _injected;

  /// The S3 leg, injectable for the same reason [AccountRepo] injects it: so
  /// the three-step cover upload can be exercised without the network.
  final S3Send _send;

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

  /// `GET /v1/media/playlists/:id` — the owner read, items already hydrated.
  Future<Playlist> fetch(String id) async {
    final response = await _api.get(ApiEndpoints.playlist(id));
    return _detail(_data(response.data));
  }

  Future<Playlist> create({
    required String title,
    String? description,
    bool isPrivate = true,
  }) async {
    final response = await _api.post(
      ApiEndpoints.playlists,
      data: {
        'title': title,
        'description': ?description,
        'visibility': isPrivate ? 'private' : 'public',
      },
    );
    return _detail(_data(response.data));
  }

  /// `PATCH /v1/media/playlists/:id`.
  Future<void> update(
    String id, {
    String? title,
    String? description,
    bool clearDescription = false,
    bool? isPrivate,
  }) async {
    await _api.patch(
      ApiEndpoints.playlist(id),
      data: {
        'title': ?title,
        'visibility': ?switch (isPrivate) {
          null => null,
          true => 'private',
          false => 'public',
        },
        if (clearDescription)
          'description': null
        else
          'description': ?description,
      },
    );
  }

  Future<void> delete(String id) => _api.delete(ApiEndpoints.playlist(id));

  /// Put a cover on a playlist: ticket, S3, then name the `fileId`.
  Future<void> uploadCover(String playlistId, PickedImage image) async {
    final ticket = await _api.post(
      ApiEndpoints.playlistCoverUploadUrl(playlistId),
      data: {
        'filename': image.filename,
        'mimeType': image.mimeType,
        'size': image.size,
      },
    );
    final data = _data(ticket.data);
    final maxBytes =
        (data['constraints'] as Map<String, dynamic>?)?['maxSizeBytes'] as int?;
    if (maxBytes != null && image.size > maxBytes) {
      throw const PlaylistCoverTooLarge();
    }

    final fileId = data['fileId'] as String?;
    final uploadUrl = data['uploadUrl'] as String?;
    final fields = (data['fields'] as Map<String, dynamic>?) ?? const {};
    if (fileId == null || uploadUrl == null || fields.isEmpty) {
      throw const PlaylistCoverTooLarge();
    }

    await _send(
      uploadUrl: uploadUrl,
      fields: fields,
      bytes: image.bytes,
      filename: image.filename,
    );

    // Naming it on the playlist is what confirms the upload and promotes the
    // key out of `quarantine/`.
    await _api.patch(
      ApiEndpoints.playlist(playlistId),
      data: {'coverFileId': fileId},
    );
  }

  /// Back to the derived cover — the first public, published item.
  Future<void> removeCover(String playlistId) => _api.patch(
    ApiEndpoints.playlist(playlistId),
    data: {'coverFileId': null},
  );

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

  /// A detail read. `items` arrives as media search hits in playlist order.
  static Playlist _detail(Map<String, dynamic> json) {
    final items = _rows(json['items']).map(_item).toList();
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
      // The server counts these now — content deleted or made private since
      // it was added.
      unavailableCount:
          (json['unavailableCount'] as num?)?.toInt() ??
          (declared - items.length).clamp(0, declared),
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
      source: WebFeedItem.fromJson(json),
    );
  }

  /// "3h 24m" — the whole thing end to end.
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
  static Playlist debugDetail(Map<String, dynamic> json) => _detail(json);

  static Map<String, dynamic> _data(Object? body) {
    final data = (body as Map<String, dynamic>?)?['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  static List<Map<String, dynamic>> _rows(Object? rows) => [
    for (final row in rows as List? ?? const [])
      if (row is Map<String, dynamic>) row,
  ];
}
