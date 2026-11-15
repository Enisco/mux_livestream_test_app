import 'package:get_it/get_it.dart';

import 'package:test_app/models/creator_models/impact_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// One page of something, whichever way the route pages.
class ImpactPage<T> {
  const ImpactPage({
    required this.items,
    this.total,
    this.nextCursor,
    this.nextPage,
  });

  final List<T> items;

  /// How many rows match in all, for a count beside a tab. Display only —
  /// the prayer list's keyset pagination must not derive offsets from it.
  final int? total;

  /// Prayers: pass back as `cursor`. Null on the last page.
  final String? nextCursor;

  /// Testimonies and comments: pass back as `page`. Null on the last page.
  final int? nextPage;

  bool get hasMore => nextCursor != null || nextPage != null;
}

/// What a congregation has sent a creator.
class ImpactRepo {
  ImpactRepo({ApiService? api}) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? GetIt.instance<ApiService>();

  // ---- Prayers ----------------------------------------------------------

  /// `GET /v1/creator/:id/engagement/prayers` — keyset, newest first.
  Future<ImpactPage<PrayerRequest>> fetchPrayers(
    String creatorId, {
    PrayerFilter? status,
    String? cursor,
    int limit = 25,
  }) async {
    final response = await _api.get(
      ApiEndpoints.creatorPrayers(creatorId),
      queryParameters: {
        'status': ?status?.slug,
        'cursor': ?cursor,
        'limit': limit,
      },
    );
    final data = _data(response.data);
    return ImpactPage(
      items: _list(data['items']).map(PrayerRequest.fromJson).toList(),
      total: data['total'] as int?,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<PrayerSummary> fetchPrayerSummary(String creatorId) async {
    final response = await _api.get(
      ApiEndpoints.creatorPrayerSummary(creatorId),
    );
    return PrayerSummary.fromJson(_data(response.data));
  }

  /// Who a prayer may be handed to — `owner`, `admin` and `editor` members
  /// only. The assignment picker is populated from here, never from the
  /// general member list, which includes people who cannot be assigned.
  Future<List<ImpactPerson>> fetchAssignees(String creatorId) async {
    final response = await _api.get(
      ApiEndpoints.creatorPrayerAssignees(creatorId),
    );
    return _list(
      _data(response.data)['items'],
    ).map(ImpactPerson.fromJson).toList();
  }

  /// `PATCH /v1/creator/engagement/prayers/:id`, which takes the **prayer
  /// id**, not a creator id.
  Future<void> updatePrayer(
    String prayerId, {
    PrayerFilter? status,
    String? assignedToUserId,
    bool unassign = false,
  }) async {
    await _api.patch(
      ApiEndpoints.creatorPrayerUpdate(prayerId),
      data: {
        if (status != null) 'status': status.slug,
        if (unassign)
          'assignedToUserId': null
        else
          'assignedToUserId': ?assignedToUserId,
      },
    );
  }

  // ---- Testimonies ------------------------------------------------------

  /// `GET /v1/creator/:id/engagement/testimonies` — a page-number search,
  /// not a keyset list. The envelope is `{ data, meta }`.
  Future<ImpactPage<CreatorTestimony>> fetchTestimonies(
    String creatorId, {
    TestimonyFilter? status,
    int page = 1,
    int limit = 25,
  }) async {
    final response = await _api.get(
      ApiEndpoints.creatorTestimonies(creatorId),
      queryParameters: {'status': ?status?.slug, 'page': page, 'limit': limit},
    );
    final data = _data(response.data);
    return ImpactPage(
      items: _list(data['data']).map(CreatorTestimony.fromJson).toList(),
      total: _total(data['meta']),
      nextPage: _nextPage(data['meta']),
    );
  }

  Future<TestimonySummary> fetchTestimonySummary(String creatorId) async {
    final response = await _api.get(
      ApiEndpoints.creatorTestimonySummary(creatorId),
    );
    return TestimonySummary.fromJson(_data(response.data));
  }

  /// `PATCH /v1/creator/engagement/testimonies/:id/moderate`.
  Future<void> moderateTestimony(
    String testimonyId,
    TestimonyFilter status,
  ) async {
    await _api.patch(
      ApiEndpoints.creatorTestimonyModerate(testimonyId),
      data: {'status': status.slug},
    );
  }

  // ---- Comment moderation queue -----------------------------------------

  /// `GET /v1/creator/:id/engagement/comments` — **the moderation queue, not
  /// a comment feed.**
  Future<ImpactPage<ImpactComment>> fetchComments(
    String creatorId, {
    CommentFilter filter = CommentFilter.both,
    int page = 1,
    int limit = 25,
  }) async {
    final response = await _api.get(
      ApiEndpoints.creatorComments(creatorId),
      queryParameters: {'status': ?filter.slug, 'page': page, 'limit': limit},
    );
    final data = _data(response.data);
    return ImpactPage(
      items: _list(data['data']).map(ImpactComment.fromJson).toList(),
      total: _total(data['meta']),
      nextPage: _nextPage(data['meta']),
    );
  }

  /// `PATCH /v1/creator/engagement/comments/:commentId/moderate`.
  Future<void> moderateComment(
    String commentId,
    CommentModeration status,
  ) async {
    await _api.patch(
      ApiEndpoints.creatorCommentModerate(commentId),
      data: {'status': status.slug},
    );
  }

  // ---- Envelope helpers -------------------------------------------------

  static Map<String, dynamic> _data(Object? body) {
    final data = (body as Map<String, dynamic>?)?['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  static List<Map<String, dynamic>> _list(Object? rows) => [
    for (final row in rows as List? ?? const [])
      if (row is Map<String, dynamic>) row,
  ];

  /// `meta.next` is the next page number, or null on the last page.
  static int? _nextPage(Object? meta) =>
      meta is Map<String, dynamic> ? meta['next'] as int? : null;

  static int? _total(Object? meta) =>
      meta is Map<String, dynamic> ? meta['total'] as int? : null;
}
