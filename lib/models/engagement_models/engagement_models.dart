class CommentAuthor {
  final String userId;
  final String displayName;
  final String handle;
  final bool isVerified;

  /// The creator of the thing being commented on — earns the "Creator" pill.
  final bool isCreator;
  final String? avatarKey;

  const CommentAuthor({
    this.userId = '',
    required this.displayName,
    required this.handle,
    this.isVerified = false,
    this.isCreator = false,
    this.avatarKey,
  });

  factory CommentAuthor.fromJson(Map<String, dynamic> json) => CommentAuthor(
    userId: json['userId'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    handle: json['handle'] as String? ?? '',
    isVerified: json['isVerified'] as bool? ?? false,
    isCreator: json['isCreator'] as bool? ?? false,
    avatarKey: json['avatarKey'] as String?,
  );
}

/// The viewer's own vote on a comment. The API answers `like`, `dislike` or
/// null; nothing else is accepted back.
enum CommentVote {
  like,
  dislike;

  static CommentVote? parse(Object? raw) => switch (raw) {
    'like' => CommentVote.like,
    'dislike' => CommentVote.dislike,
    _ => null,
  };

  String get wire => name;
}

class MediaComment {
  final String id;
  final String body;
  final CommentAuthor? author;
  final DateTime createdAt;
  final int likeCount;
  final int dislikeCount;
  final int replyCount;
  final CommentVote? myVote;
  final String? parentCommentId;
  final bool edited;

  const MediaComment({
    required this.id,
    required this.body,
    this.author,
    required this.createdAt,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.replyCount = 0,
    this.myVote,
    this.parentCommentId,
    this.edited = false,
  });

  bool get isReply => parentCommentId != null;

  MediaComment copyWith({
    int? likeCount,
    int? dislikeCount,
    int? replyCount,
    CommentVote? myVote,
    bool clearVote = false,
  }) => MediaComment(
    id: id,
    body: body,
    author: author,
    createdAt: createdAt,
    likeCount: likeCount ?? this.likeCount,
    dislikeCount: dislikeCount ?? this.dislikeCount,
    replyCount: replyCount ?? this.replyCount,
    myVote: clearVote ? null : (myVote ?? this.myVote),
    parentCommentId: parentCommentId,
    edited: edited,
  );

  factory MediaComment.fromJson(Map<String, dynamic> json) => MediaComment(
    id: json['id'] as String? ?? '',
    body: json['body'] as String? ?? '',
    author: json['author'] is Map<String, dynamic>
        ? CommentAuthor.fromJson(json['author'] as Map<String, dynamic>)
        : null,
    createdAt: () {
      final raw = json['createdAt'];
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      return DateTime.now();
    }(),
    likeCount: json['likeCount'] as int? ?? 0,
    dislikeCount: json['dislikeCount'] as int? ?? 0,
    replyCount: json['replyCount'] as int? ?? 0,
    myVote: CommentVote.parse(json['myVote']),
    parentCommentId: json['parentCommentId'] as String?,
    edited: json['edited'] as bool? ?? false,
  );
}

class CommentsResponse {
  final List<MediaComment> items;
  final String? nextCursor;

  const CommentsResponse({required this.items, this.nextCursor});

  factory CommentsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    return CommentsResponse(
      items: (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MediaComment.fromJson)
          .toList(),
      nextCursor: data['nextCursor'] as String?,
    );
  }
}

/// The interaction kinds the API accepts.
///
/// Not `dislike` — the API rejects it, which is why the card's second action is
/// save rather than a thumbs-down.
abstract final class InteractionTypes {
  static const like = 'like';
  static const favorite = 'favorite';
  static const amen = 'amen';
  static const share = 'share';

  /// "Not interested" — a real suppression, not a stored preference.
  ///
  /// It **increments nothing**: no public counter moves, no creator metric
  /// moves, and nothing on the server will ever say how many viewers hid an
  /// item. The sheet must render no count beside it. Unlike [share], which is
  /// action-based and does increment `engagementShareCount`.
  ///
  /// Accepted on the five types that can appear as a discovery row —
  /// `media`, `post`, `devotional`, `devotional_entry`, `event`. A testimony
  /// or the verse of the day is a `400`: neither is something ranking chose
  /// to show you.
  static const notInterested = 'not_interested';

  static const all = {like, favorite, amen, share, notInterested};

  /// What a card's overflow sheet may offer "Not interested" on.
  static const notInterestedTargets = {
    'media',
    'post',
    'devotional',
    'devotional_entry',
    'event',
  };
}

/// Hiding a creator from the surfaces that recommend them.
///
/// **Mute and block are not two sizes of the same thing**, and the difference
/// decides what the confirmation says:
///
/// | | Mute | Block |
/// | --- | --- | --- |
/// | Feeds, Explore, search | Hidden | Hidden |
/// | Channel page and library | **Still reachable** | Gone |
/// | The follow | **Kept** | **Dropped** |
/// | Their comments | **Still shown** | Hidden |
///
/// A viewer who mutes their own church still wants to open that church's page
/// on Sunday. So a muted creator stays in `following-creators`, which carries
/// `isMuted` and is the screen a viewer uses to undo it.
class HiddenCreator {
  const HiddenCreator({
    required this.creatorId,
    this.displayName = '',
    this.handle = '',
    this.avatarKey,
    this.at,
  });

  final String creatorId;
  final String displayName;
  final String handle;
  final String? avatarKey;

  /// `mutedAt` or `blockedAt`, whichever list this came from.
  final DateTime? at;

  factory HiddenCreator.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    return HiddenCreator(
      creatorId: json['creatorId'] as String? ?? '',
      displayName:
          creator?['displayName'] as String? ??
          json['displayName'] as String? ??
          '',
      handle: creator?['handle'] as String? ?? json['handle'] as String? ?? '',
      avatarKey:
          creator?['avatarKey'] as String? ?? json['avatarKey'] as String?,
      at: DateTime.tryParse(
        (json['mutedAt'] ?? json['blockedAt']) as String? ?? '',
      ),
    );
  }
}

abstract final class CreatorHiding {
  /// Removing one will not clear the other, and both are idempotent — so a
  /// client that offers "Unmute" for a blocked creator gets a `200` and no
  /// visible change. Do not offer it.
  static const muted = 'muted';
  static const blocked = 'blocked';
}

/// What an interaction can be attached to.
///
/// A third naming scheme, distinct from the feed's `entityType` and the
/// analytics `contentType`. Mixing them up is silent: the API rejects the
/// unknown value and the viewer's like state never loads.
///
/// | feed entityType    | beacon contentType  | interaction targetType |
/// | ------------------ | ------------------- | ---------------------- |
/// | `media`            | (uses `mediaId`)    | `media`                |
/// | `post`             | `post`              | `post`                 |
/// | `devotional_series`| `devotional_series` | `devotional`           |
/// | `devotional_entry` | `devotional_entry`  | `devotional_entry`     |
/// | `event`            | `calendar_event`    | `event`                |
/// | `creator`          | `creator`           | — none —               |
/// | `media_series`     | `media_series`      | — none —               |
abstract final class InteractionTargets {
  static const media = 'media';
  static const post = 'post';
  static const devotional = 'devotional';
  static const devotionalEntry = 'devotional_entry';
  static const event = 'event';
  static const testimony = 'testimony';
  static const verseOfDay = 'verse_of_day';

  /// Verified against staging; anything else is a 400.
  static const all = {
    media,
    post,
    devotional,
    devotionalEntry,
    event,
    testimony,
    verseOfDay,
  };

  /// The target type for a discovery feed row, or null when the row cannot
  /// carry interactions (creators and media series).
  static String? fromEntityType(String? entityType) => switch (entityType) {
    'media' => media,
    'post' => post,
    'devotional_series' => devotional,
    'devotional_entry' => devotionalEntry,
    'event' || 'calendar_event' => event,
    _ => null,
  };
}
