import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// One page of a viewer library list.
class LibraryPage {
  const LibraryPage({required this.days, this.nextCursor, this.total});

  /// Rows already grouped under the heading the design gives them.
  final List<HistoryDay> days;

  final String? nextCursor;

  /// What the server says there are in all, where it says so. The history
  /// route's `total` counts **this page**, not the viewer's whole history, so
  /// it is deliberately not read into this.
  final int? total;

  bool get isEmpty => days.isEmpty;
}

/// What the reader has watched, liked and saved.
///
/// Three lists, one row shape. History, Liked and Saved all return enriched
/// search hits with a `creator` byline, so one mapper feeds all of them and
/// the screens differ only in the heading they group under.
///
/// Two things worth knowing:
///
/// - **Removing history hides through an instant; it does not delete rows.**
///   The routes answer with a `hiddenThrough` / `clearedThrough` timestamp,
///   and watching the same thing again brings it back. Calling that
///   "permanently delete" in the UI would be a lie.
/// - **A page can come back short, or empty with a cursor.** Content deleted
///   or made private since it was watched is dropped during hydration, so the
///   caller follows `nextCursor` rather than stopping on a thin page.
class ViewerLibraryRepo {
  ViewerLibraryRepo({ApiService? api}) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? GetIt.instance<ApiService>();

  /// `GET /v1/discovery/viewer/history` — newest activity first.
  Future<LibraryPage> fetchHistory({String? cursor, int limit = 50}) async {
    final response = await _api.get(
      ApiEndpoints.viewerHistory,
      queryParameters: {'limit': limit, 'cursor': ?cursor},
    );
    final data = _data(response.data);
    return LibraryPage(
      days: _group(
        _rows(data['items']).map(_fromHistory).toList(),
        dedupe: true,
      ),
      nextCursor: data['nextCursor'] as String?,
    );
  }

  /// `DELETE /v1/discovery/viewer/history/:targetType/:targetId`.
  ///
  /// A **hide-through**, not a deletion — see the class note.
  Future<void> hideFromHistory(String targetType, String targetId) =>
      _api.delete(ApiEndpoints.viewerHistoryItem(targetType, targetId));

  /// `DELETE /v1/discovery/viewer/history`.
  Future<void> clearHistory() => _api.delete(ApiEndpoints.viewerHistory);

  /// `GET /v1/engagement/interactions/me/liked`.
  Future<LibraryPage> fetchLiked({String? cursor, int limit = 25}) =>
      _interactions(ApiEndpoints.myLiked, cursor: cursor, limit: limit);

  /// `GET /v1/engagement/interactions/me/saved`.
  Future<LibraryPage> fetchSaved({String? cursor, int limit = 25}) =>
      _interactions(ApiEndpoints.mySaved, cursor: cursor, limit: limit);

  Future<LibraryPage> _interactions(
    String path, {
    String? cursor,
    int limit = 25,
  }) async {
    final response = await _api.get(
      path,
      queryParameters: {'limit': limit, 'cursor': ?cursor},
    );
    final data = _data(response.data);
    return LibraryPage(
      days: _group(_rows(data['items']).map(_fromInteraction).toList()),
      nextCursor: data['nextCursor'] as String?,
      total: (data['total'] as num?)?.toInt(),
    );
  }

  // ---- Rows -------------------------------------------------------------

  /// A history row, which carries where the viewer got to.
  static _Row _fromHistory(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    final at = DateTime.tryParse(json['viewedAt'] as String? ?? '');
    final percent = (meta['progressPercent'] as num?)?.toDouble();
    final targetType = json['historyTargetType'] as String? ?? '';
    return _Row(
      at: at,
      entry: _entry(
        json,
        meta: meta,
        at: at,
        targetType: targetType,
        // The bar under a history still. A finished row gets none — a full
        // bar on something already watched reads as "nearly done" — and
        // neither does one never started, where an empty bar says nothing.
        progress:
            (json['completed'] as bool? ?? false) ||
                percent == null ||
                percent <= 0
            ? null
            : (percent / 100).clamp(0.0, 1.0),
      ),
      targetType: targetType,
    );
  }

  /// A liked or saved row, which carries when the viewer acted.
  static _Row _fromInteraction(Map<String, dynamic> json) {
    final at = DateTime.tryParse(json['interactionAt'] as String? ?? '');
    final targetType = json['engagementTargetType'] as String? ?? '';
    return _Row(
      at: at,
      entry: _entry(
        json,
        meta: json['meta'] as Map<String, dynamic>? ?? const {},
        at: at,
        targetType: targetType,
      ),
      targetType: targetType,
    );
  }

  static HistoryEntry _entry(
    Map<String, dynamic> json, {
    required Map<String, dynamic> meta,
    required DateTime? at,
    required String targetType,
    double? progress,
  }) {
    final creator = json['creator'] as Map<String, dynamic>?;
    // Counts live in `facets`, not `meta` — these are search hits, and the
    // two halves carry different things.
    final facets = json['facets'] as Map<String, dynamic>? ?? const {};
    final entityType = json['entityType'] as String? ?? '';
    final mediaType =
        facets['mediaType'] as String? ?? meta['mediaType'] as String?;
    final seconds = (meta['durationSeconds'] as num?)?.toDouble();

    return HistoryEntry(
      id: json['entityId'] as String? ?? '',
      kind: _kind(entityType, mediaType),
      title: json['title'] as String? ?? '',
      // `creator` may be absent when its lookup degraded. The row renders
      // without a byline rather than being dropped.
      creatorName: creator?['displayName'] as String? ?? '',
      creatorVerified:
          creator?['isVerified'] as bool? ?? creator?['verifiedAt'] != null,
      age: shortAge(at),
      thumbnailUrl: AssetUrlResolver.imageFor(
        url: meta['thumbnailUrl'] as String?,
        key: meta['thumbnailKey'] as String?,
      ),
      count:
          (facets['analyticsViews'] as num?)?.toInt() ??
          (meta['analyticsViews'] as num?)?.toInt() ??
          0,
      duration: seconds == null ? null : clock(seconds),
      progress: progress,
      targetType: targetType,
      // The hit kept whole, so tapping the row opens the thing it stands
      // for. Only the fields the design draws are unpacked above; the entity
      // type a post, event or series is opened by is not one of them.
      source: WebFeedItem.fromJson(json),
    );
  }

  /// Which word the row leads with. One list mixes every entity type.
  static HistoryKind _kind(String entityType, String? mediaType) =>
      switch (entityType) {
        'post' => HistoryKind.blog,
        'event' => HistoryKind.event,
        'devotional_series' || 'devotional_entry' => HistoryKind.devotional,
        _ => mediaType == 'music' ? HistoryKind.audio : HistoryKind.video,
      };

  // ---- Grouping ---------------------------------------------------------

  /// Group rows under Today / Yesterday / a date, in the order they arrived.
  ///
  /// [dedupe] drops a repeat of the same thing further down the list:
  /// something watched again while the viewer is paging moves to the top and
  /// can appear on two pages.
  static List<HistoryDay> _group(List<_Row> rows, {bool dedupe = false}) {
    final seen = <String>{};
    final buckets = <String, List<HistoryEntry>>{};
    final order = <String>[];

    for (final row in rows) {
      if (dedupe && !seen.add('${row.targetType}:${row.entry.id}')) continue;
      final label = dayLabel(row.at);
      if (!buckets.containsKey(label)) {
        buckets[label] = [];
        order.add(label);
      }
      buckets[label]!.add(row.entry);
    }
    return [
      for (final label in order)
        HistoryDay(label: label, entries: buckets[label]!),
    ];
  }

  /// Map raw history rows without a network, for tests that pin the wording
  /// each entity type lands on.
  @visibleForTesting
  static List<HistoryEntry> debugMap(List<Map<String, dynamic>> rows) =>
      rows.map(_fromHistory).map((r) => r.entry).toList();

  // ---- Envelope ---------------------------------------------------------

  static Map<String, dynamic> _data(Object? body) {
    final data = (body as Map<String, dynamic>?)?['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  static List<Map<String, dynamic>> _rows(Object? rows) => [
    for (final row in rows as List? ?? const [])
      if (row is Map<String, dynamic>) row,
  ];
}

/// An entry plus the two things only the grouping needs.
class _Row {
  const _Row({required this.entry, required this.at, required this.targetType});

  final HistoryEntry entry;
  final DateTime? at;
  final String targetType;
}

/// Join a new page onto a list, folding a day that spans the page boundary
/// into the one already on screen rather than heading it twice.
List<HistoryDay> mergeDays(List<HistoryDay> a, List<HistoryDay> b) {
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  final out = [...a];
  for (final day in b) {
    final i = out.indexWhere((d) => d.label == day.label);
    if (i == -1) {
      out.add(day);
    } else {
      out[i] = HistoryDay(
        label: day.label,
        entries: [...out[i].entries, ...day.entries],
      );
    }
  }
  return out;
}

/// "Today", "Yesterday", "12 June" — the headings the design groups under.
///
/// The gateway sends UTC, and a calendar day is a local idea. Reading
/// `.year/.month/.day` straight off the parsed value compares a UTC date
/// against a local one, so west of Greenwich an evening row headed itself
/// "Today" a day early, and east of it everything watched between midnight
/// and the UTC offset was headed "Yesterday". Convert first, then bucket.
String dayLabel(DateTime? at) {
  if (at == null) return 'Earlier';
  final local = at.toLocal();
  final now = DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  final gap = today.difference(day).inDays;
  if (gap <= 0) return 'Today';
  if (gap == 1) return 'Yesterday';
  final date = '${local.day} ${_months[local.month - 1]}';
  return local.year == now.year ? date : '$date ${local.year}';
}

/// "6d", "3w" — the compact age on a library row.
String shortAge(DateTime? at) {
  if (at == null) return '';
  final gap = DateTime.now().difference(at);
  if (gap.inMinutes < 60) return '${gap.inMinutes}m';
  if (gap.inHours < 24) return '${gap.inHours}h';
  if (gap.inDays < 7) return '${gap.inDays}d';
  if (gap.inDays < 365) return '${(gap.inDays / 7).floor()}w';
  return '${(gap.inDays / 365).floor()}y';
}

/// "25:14" or "1:05:30" on a still.
String clock(double seconds) {
  final total = seconds.round();
  final s = (total % 60).toString().padLeft(2, '0');
  final m = total ~/ 60;
  if (m < 60) return '$m:$s';
  return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}:$s';
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
