import 'package:get_it/get_it.dart';

import 'package:test_app/models/creator_models/impact_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// One page of something, whichever way the route pages.
///
/// The three Impact inboxes do not agree: prayers are keyset, testimonies and
/// comments are page-number. Both are normalised here so the screen asks for
/// "the next page" and does not care which.
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
///
/// Every route here is the creator-side inbox documented in
/// `docs/API_INTEGRATION_GUIDES/client-creator-and-dashboard-integration.md`.
/// They are a different family from the viewer-side engagement routes: a
/// viewer's own prayers live under `/v1/engagement/prayers/mine`, and the
/// public testimony wall under `/v1/public/engagement/testimonies`.
///
/// **Reads hang off the creator; writes do not.** Each `PATCH` takes the
/// row's own id with no creator segment.
class ImpactRepo {
  ImpactRepo({ApiService? api}) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? GetIt.instance<ApiService>();

  // ---- Prayers ----------------------------------------------------------

  /// `GET /v1/creator/:id/engagement/prayers` — keyset, newest first.
  ///
  /// `cursor` is the previous page's `nextCursor`; omit it for the first
  /// page. `total` is for display only — building an offset from it would
  /// page the list wrongly.
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
  ///
  /// Both fields are optional and `null` is not absence: passing
  /// [unassign] sends an explicit `null` to clear the assignment, while
  /// leaving both assignment arguments alone keeps whatever is there. Mixing
  /// those up silently keeps a stale assignee.
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
  ///
  /// One `status` write covers every action the inbox offers:
  /// approve (`pending → approved`), reject (`pending → rejected`), remove
  /// from the wall (`approved → rejected`) and restore for review
  /// (`rejected → pending`).
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
  ///
  /// It returns only `flagged` and `hidden` rows. Omitting `status` means
  /// both of those, never "every comment"; `status=visible` is rejected by
  /// the gateway and nothing here sends it.
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
  ///
  /// Moderating to `visible` **removes the row from the queue** — that is
  /// what the queue is for, so the caller should expect it to disappear.
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
