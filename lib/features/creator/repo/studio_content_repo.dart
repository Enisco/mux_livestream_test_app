import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/models/creator_models/studio_content_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// Everything a creator has made, gathered from the three services that hold
/// it.
///
/// All three routes are real and were exercised against staging. None
/// publishes a response schema; each answers the same envelope:
/// `{data: [...], meta: {total, lastPage, currentPage, perPage, prev, next}}`.
///
/// The media filter dialect is worth knowing: operators are `equals`, `in`,
/// `notEquals`, `notIn` — **not** `eq`, which is refused — and `sort` takes
/// `[{field, direction}]`.
class StudioContentRepo {
  StudioContentRepo([ApiService? api]) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? getIt<ApiService>();

  static const _pageSize = 20;

  /// One chip's worth of content.
  ///
  /// "All" asks all three services at once and interleaves the answers by
  /// recency, because no single route spans them. Each source fails on its
  /// own: a creator whose posts service is down should still see their
  /// videos.
  Future<StudioContentPage> fetch({
    required String creatorId,
    StudioContentKind? kind,
    int page = 1,
  }) async {
    final wanted = kind == null
        ? StudioContentKind.values
        : <StudioContentKind>[kind];

    final results = await Future.wait([
      if (wanted.any((k) => k.mediaTypes.isNotEmpty))
        _media(creatorId, wanted, page),
      if (wanted.contains(StudioContentKind.post)) _posts(creatorId, page),
      if (wanted.contains(StudioContentKind.event)) _events(creatorId, page),
    ]);

    final items = [for (final page in results) ...page.items]
      ..sort((a, b) => b.sortAt.compareTo(a.sortAt));
    final total = results.fold(0, (sum, page) => sum + page.total);
    return StudioContentPage(items: items, total: total);
  }

  Future<StudioContentPage> _media(
    String creatorId,
    List<StudioContentKind> wanted,
    int page,
  ) async {
    // Videos brings livestreams with it: they are a separate media type, and
    // leaving them out made a creator's Sunday service invisible here.
    final types = {for (final kind in wanted) ...kind.mediaTypes}.toList();
    return _post(
      ApiEndpoints.creatorMediaSearch(creatorId),
      page: page,
      body: {
        'filters': {
          'type': {'in': types},
        },
        'sort': [
          {'field': 'createdAt', 'direction': 'desc'},
        ],
      },
      parse: StudioContentItem.fromMedia,
      what: 'media',
    );
  }

  Future<StudioContentPage> _posts(String creatorId, int page) => _post(
    ApiEndpoints.creatorPostsSearch(creatorId),
    page: page,
    body: const {
      'sort': [
        {'field': 'createdAt', 'direction': 'desc'},
      ],
    },
    parse: StudioContentItem.fromPost,
    what: 'posts',
  );

  /// Events are the odd one out: a GET with query parameters rather than a
  /// searched POST.
  Future<StudioContentPage> _events(String creatorId, int page) async {
    try {
      final response = await _api.get(
        ApiEndpoints.creatorEventsSearch(creatorId),
        queryParameters: {'page': page, 'limit': _pageSize},
      );
      return _read(response.data, StudioContentItem.fromEvent);
    } catch (e) {
      logger.w('Studio events failed', error: e);
      return StudioContentPage.empty;
    }
  }

  Future<StudioContentPage> _post(
    String path, {
    required int page,
    required Map<String, dynamic> body,
    required StudioContentItem Function(Map<String, dynamic>) parse,
    required String what,
  }) async {
    try {
      final response = await _api.post(
        path,
        queryParameters: {'page': page, 'limit': _pageSize},
        data: body,
      );
      return _read(response.data, parse);
    } catch (e) {
      logger.w('Studio $what failed', error: e);
      return StudioContentPage.empty;
    }
  }

  static StudioContentPage _read(
    dynamic payload,
    StudioContentItem Function(Map<String, dynamic>) parse,
  ) {
    final data = payload is Map ? payload['data'] : null;
    if (data is! Map) return StudioContentPage.empty;
    final rows = data['data'];
    final meta = data['meta'];
    return StudioContentPage(
      items: [
        if (rows is List)
          for (final row in rows)
            if (row is Map<String, dynamic>) parse(row),
      ],
      total: meta is Map ? (meta['total'] as num?)?.toInt() ?? 0 : 0,
    );
  }
}
