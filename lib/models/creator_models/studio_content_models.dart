/// What a creator has made, flattened into one list.
///
/// Media, written posts and calendar events come from three services with
/// three shapes. The Content tab shows them in one list, so each is parsed
/// into this common row rather than the screen learning all three.
///
/// Every field was read off a live staging response; the search routes
/// publish no response schema.
library;

import 'package:test_app/shared/services/asset_url_resolver.dart';

/// The kinds the Content tab filters by. `music` is the API's word for what
/// the design calls Audio.
///
/// A **livestream is not a video**: the API keeps it as a third media type,
/// created only through the live provision/session routes — `POST /v1/media`
/// answers *"Use livestream provision/start endpoints for livestream sessions
/// instead of CREATE_MEDIA"*. It is filed under the Videos chip because the
/// design offers no other home for it, but it is modelled, labelled and
/// counted on its own terms.
enum StudioContentKind {
  video('Videos'),
  livestream('Videos'),
  audio('Audio'),
  post('Posts'),
  event('Events');

  const StudioContentKind(this.chip);

  /// The filter chip's label. Livestreams share the Videos chip.
  final String chip;

  /// The distinct chips, in the order the design shows them — `values` would
  /// draw Videos twice.
  static const chips = [video, audio, post, event];

  /// The `type` values the media search should ask for under this chip.
  List<String> get mediaTypes => switch (this) {
    video || livestream => const ['video', 'livestream'],
    audio => const ['music'],
    _ => const [],
  };
}

/// Where a piece of content stands. Drawn from `status` plus, for anything
/// published, `visibility` — the design shows one line combining both.
/// Every value here is one the API actually returns. The three services
/// publish three different status enums, which the search filter's own
/// refusal spells out:
///
///  * media — `archived, blocked, draft, failed, processing, published,
///    ready, scheduled, under_review`
///  * posts — `archived, draft, published, scheduled`
///  * events — `draft, published, cancelled, completed`
enum StudioContentState {
  draft,
  processing,
  scheduled,

  /// Broadcasting right now. No status says this; `isLiveNow` does.
  live,

  /// The recording a finished broadcast left behind. This is a **video**
  /// row carrying `sourceLivestreamMediaId`, not the livestream session —
  /// ending a stream produces both, and only the archive is watchable.
  replay,

  /// A broadcast that has finished. Its recording, if it kept one, is a
  /// separate row.
  ended,

  published,

  /// The transcode failed. Left unnamed, this read as "Public · 2d".
  failed,

  /// Waiting on moderation, or refused by it.
  inReview,
  blocked,

  archived,

  /// An event that will not happen after all.
  cancelled,

  other,
}

class StudioContentItem {
  const StudioContentItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.state,
    this.visibility = '',
    this.thumbnailKey,
    this.durationSeconds,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.goingCount = 0,
    this.startsAt,
    this.updatedAt,
    this.publishedAt,
    this.endedAt,
    this.venue = '',
    this.categorySlugs = const [],
  });

  /// A media row: `POST /v1/media/creator/{id}/search`.
  factory StudioContentItem.fromMedia(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? '';
    final isLive = json['isLiveNow'] as bool? ?? false;
    final kind = switch (json['type']) {
      'music' => StudioContentKind.audio,
      'livestream' => StudioContentKind.livestream,
      _ => StudioContentKind.video,
    };
    final ended = DateTime.tryParse(json['endedAt'] as String? ?? '');
    final scheduledAt = DateTime.tryParse(json['scheduledAt'] as String? ?? '');
    // Ending a broadcast leaves two rows: the session, and a video archive
    // that points back at it. The archive is the replay.
    final isReplay = json['sourceLivestreamMediaId'] != null;
    return StudioContentItem(
      id: json['id'] as String? ?? '',
      kind: kind,
      title: json['title'] as String? ?? '',
      // A stream's own history outranks its `status`: airing now is live,
      // a finished one has ended, and one still to come is scheduled. The
      // backend does set `scheduled` when a session carries a schedule, but
      // an unscheduled session sits at `ready`, which alone would read as
      // published — hence the explicit order.
      state: isLive
          ? StudioContentState.live
          : isReplay
          ? StudioContentState.replay
          : kind == StudioContentKind.livestream
          ? ended != null
                ? StudioContentState.ended
                : scheduledAt != null && scheduledAt.isAfter(DateTime.now())
                ? StudioContentState.scheduled
                : _stateOf(status)
          : _stateOf(status),
      visibility: json['visibility'] as String? ?? '',
      thumbnailKey: json['thumbnailKey'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      views: (json['analyticsViews'] as num?)?.toInt() ?? 0,
      likes: (json['engagementLikeCount'] as num?)?.toInt() ?? 0,
      comments: (json['engagementCommentCount'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      startsAt: scheduledAt,
      endedAt: ended,
      categorySlugs: _slugs(json),
    );
  }

  /// A written post: `POST /v1/content/posts/creator/{id}/search`.
  ///
  /// Posts count reads in `analyticsViews`, the same field media uses — the
  /// design calls them reads, the API does not.
  factory StudioContentItem.fromPost(Map<String, dynamic> json) =>
      StudioContentItem(
        id: json['id'] as String? ?? '',
        kind: StudioContentKind.post,
        title: json['title'] as String? ?? '',
        state: _stateOf(json['status'] as String? ?? ''),
        visibility: json['visibility'] as String? ?? '',
        thumbnailKey: json['coverThumbnailKey'] as String?,
        likes: (json['engagementLikeCount'] as num?)?.toInt() ?? 0,
        comments: (json['engagementCommentCount'] as num?)?.toInt() ?? 0,
        views: (json['analyticsViews'] as num?)?.toInt() ?? 0,
        startsAt: DateTime.tryParse(json['scheduledAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
        categorySlugs: _slugs(json),
      );

  /// A calendar event:
  /// `GET /v1/content/calendar/events/creator/{id}/search`.
  ///
  /// The row carries `startAt` at the top level *and* inside `schedule`; the
  /// top-level one is read, with the nested one as a fallback. The venue is
  /// `location.label`, and those going are `attendingCount`.
  factory StudioContentItem.fromEvent(Map<String, dynamic> json) {
    final schedule = json['schedule'];
    final location = json['location'];
    return StudioContentItem(
      id: json['id'] as String? ?? '',
      kind: StudioContentKind.event,
      title: json['title'] as String? ?? '',
      state: _stateOf(json['status'] as String? ?? ''),
      visibility: json['visibility'] as String? ?? '',
      thumbnailKey: json['coverImageKey'] as String?,
      goingCount: (json['attendingCount'] as num?)?.toInt() ?? 0,
      likes: (json['engagementLikeCount'] as num?)?.toInt() ?? 0,
      comments: (json['engagementCommentCount'] as num?)?.toInt() ?? 0,
      venue: location is Map ? location['label'] as String? ?? '' : '',
      startsAt: DateTime.tryParse(
        json['startAt'] as String? ??
            (schedule is Map ? schedule['startAt'] as String? ?? '' : ''),
      ),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      categorySlugs: _slugs(json),
    );
  }

  static List<String> _slugs(Map<String, dynamic> json) {
    final raw = json['categorySlugs'];
    return raw is List
        ? [
            for (final s in raw)
              if (s is String) s,
          ]
        : const [];
  }

  static StudioContentState _stateOf(String status) => switch (status) {
    // `ready` is not published: it means Mux has finished transcoding and
    // the row is waiting on `POST /v1/media/{id}/publish`. Reading it as
    // published told a creator their video was out when it was not.
    'draft' || 'ready' => StudioContentState.draft,
    'processing' => StudioContentState.processing,
    'scheduled' => StudioContentState.scheduled,
    // An event that has happened is still out there to look at.
    'published' || 'completed' => StudioContentState.published,
    'failed' => StudioContentState.failed,
    'under_review' => StudioContentState.inReview,
    'blocked' => StudioContentState.blocked,
    'archived' => StudioContentState.archived,
    'cancelled' => StudioContentState.cancelled,
    _ => StudioContentState.other,
  };

  final String id;
  final StudioContentKind kind;
  final String title;
  final StudioContentState state;

  /// `public`, `unlisted` or `private`.
  final String visibility;

  final String? thumbnailKey;

  /// Whether tapping this should open the player.
  ///
  /// Only media, and only once there is something to play: a draft has no
  /// transcode yet, a failed one never will, and a livestream session is not
  /// watchable at all — its recording is a separate row.
  bool get isPlayable =>
      (kind == StudioContentKind.video || kind == StudioContentKind.audio) &&
      (state == StudioContentState.published ||
          state == StudioContentState.replay);

  /// The still to show for this row, or null when there is nothing to show.
  ///
  /// Two sources, because the API uses two. An uploaded cover arrives as a
  /// `thumbnailKey` on the CDN; a video left to Mux carries no key at all and
  /// its generated first frame comes from the public asset route instead.
  /// Posts and events only ever have the former.
  String? get stillUrl {
    final fromKey = AssetUrlResolver.resolve(thumbnailKey);
    if (fromKey != null) return fromKey;
    return switch (kind) {
      StudioContentKind.video ||
      StudioContentKind.livestream ||
      StudioContentKind.audio => AssetUrlResolver.mediaThumbnail(id),
      StudioContentKind.post || StudioContentKind.event => null,
    };
  }

  /// Video and audio only.
  final int? durationSeconds;

  /// Views for video, plays for audio, reads for a post.
  final int views;
  final int likes;
  final int comments;

  /// Events only.
  final int goingCount;
  final String venue;

  /// What it was filed under. Only slugs come back on these rows, so the
  /// detail screen prettifies rather than looking names up.
  final List<String> categorySlugs;

  /// When an event starts, or when scheduled content goes out.
  final DateTime? startsAt;

  final DateTime? updatedAt;
  final DateTime? publishedAt;

  /// When a livestream stopped broadcasting. Only livestreams carry it.
  final DateTime? endedAt;

  bool get isDraft => state == StudioContentState.draft;

  /// Broadcast, not uploaded. The two are created through entirely separate
  /// routes and the studio should never present one as the other.
  bool get isLivestream => kind == StudioContentKind.livestream;

  /// The recording a broadcast left behind, rather than the broadcast.
  bool get isReplay => state == StudioContentState.replay;

  /// The moment the list sorts by: what happened to this most recently.
  DateTime get sortAt =>
      publishedAt ??
      endedAt ??
      startsAt ??
      updatedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

/// One page of content, with whatever the server says is left.
class StudioContentPage {
  const StudioContentPage({required this.items, required this.total});

  static const empty = StudioContentPage(items: [], total: 0);

  final List<StudioContentItem> items;
  final int total;
}
