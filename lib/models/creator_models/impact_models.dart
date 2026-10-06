/// What a congregation sends a creator: prayers, testimonies and comments.
///
/// The three sit behind one Impact screen with a tab each. Every shape here
/// is the one in `docs/API_INTEGRATION_GUIDES/
/// client-creator-and-dashboard-integration.md` — the creator-side inboxes,
/// which are a different family from the viewer-side engagement routes.
///
/// Two things worth knowing before reading on:
///
/// - **The three tabs do not page the same way.** Prayers are keyset
///   (`cursor` + `nextCursor`); testimonies and comments are page-number
///   (`page` + `meta.next`). The envelopes differ too.
/// - **Identity is resolved by the gateway.** `requester`, `author` and
///   `assignee` are the only fields a client may render as a person. An
///   anonymous testimony comes back masked, and reconstructing a name from
///   `submitterUserId` would undo a choice the viewer made.
library;

/// Who a row came from, as the gateway resolves them.
///
/// `displayName` falls back to "GospelTube user" when user-service is briefly
/// unavailable, and to "Anonymous user" when the submitter asked to stay
/// anonymous — so it is always safe to render as-is.
class ImpactPerson {
  const ImpactPerson({
    required this.displayName,
    this.userId,
    this.avatarKey,
    this.role,
    this.anonymous = false,
  });

  factory ImpactPerson.fromJson(Map<String, dynamic> json) => ImpactPerson(
    userId: json['userId'] as String?,
    displayName: json['displayName'] as String? ?? '',
    avatarKey: json['avatarKey'] as String?,
    role: json['role'] as String?,
    anonymous: json['anonymous'] as bool? ?? false,
  );

  /// Null on an anonymous submitter — the gateway withholds it deliberately.
  final String? userId;

  final String displayName;
  final String? avatarKey;

  /// `owner`, `admin`, `editor` — only on an assignee or an assignable member.
  final String? role;

  final bool anonymous;
}

/// A person block, or null where the gateway sent none.
ImpactPerson? _person(Object? json) =>
    json is Map<String, dynamic> ? ImpactPerson.fromJson(json) : null;

/// Where a prayer is in its life.
///
/// Three states, and the card's button is a different step at each: an open
/// prayer is prayed for, a prayed one is closed, a closed one has only the
/// overflow menu.
enum PrayerFilter {
  open('open'),
  prayedFor('prayed_for'),
  closed('closed');

  const PrayerFilter(this.slug);

  final String slug;

  static PrayerFilter? bySlug(String? slug) {
    for (final value in values) {
      if (value.slug == slug) return value;
    }
    return null;
  }
}

/// What the "…" on a prayer card offers, which depends on where it already is:
///
/// | State | Menu |
/// | --- | --- |
/// | open | Assign, Resolved |
/// | prayed for | Assign, Re-open, Resolved |
/// | closed | Assign (disabled), Re-open |
enum PrayerAction { assign, reopen, resolve }

/// What a prayer was raised from.
class PrayerSource {
  const PrayerSource({required this.targetType, required this.targetId});

  static PrayerSource? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final type = json['targetType'] as String?;
    final id = json['targetId'] as String?;
    if (type == null || id == null) return null;
    return PrayerSource(targetType: type, targetId: id);
  }

  /// `media`, `post`, `event`, `devotional`, …
  final String targetType;
  final String targetId;
}

/// A prayer a member asked this ministry for.
class PrayerRequest {
  const PrayerRequest({
    required this.id,
    required this.body,
    this.status = 'open',
    this.assignedToUserId,
    this.contentRef,
    this.contentRefTitle,
    this.createdAt,
    this.requester,
    this.assignee,
  });

  factory PrayerRequest.fromJson(Map<String, dynamic> json) => PrayerRequest(
    id: json['id'] as String? ?? '',
    body: json['body'] as String? ?? '',
    status: json['status'] as String? ?? 'open',
    assignedToUserId: json['assignedToUserId'] as String?,
    contentRef: PrayerSource.fromJson(json['contentRef']),
    contentRefTitle: json['contentRefTitle'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    requester: _person(json['requester']),
    assignee: _person(json['assignee']),
  );

  final String id;
  final String body;

  /// `open`, `prayed_for` or `closed`.
  final String status;

  /// Who on the team is carrying it. Null is the design's "Not assigned".
  final String? assignedToUserId;

  /// Set when the prayer came from a piece of content rather than the wall.
  final PrayerSource? contentRef;

  /// The title behind [contentRef], for `On "Walking by Faith"`.
  ///
  /// **Best effort — absence is normal, not an error.** It goes missing when
  /// the content was deleted, belongs to another creator, or has no title at
  /// all. The card falls back to a label for the type rather than blanking
  /// the line. Never show it to a viewer; it is unpublished-aware on purpose.
  final String? contentRefTitle;

  final DateTime? createdAt;
  final ImpactPerson? requester;
  final ImpactPerson? assignee;

  PrayerFilter get state => PrayerFilter.bySlug(status) ?? PrayerFilter.open;

  bool get isAssigned => (assignedToUserId ?? '').isNotEmpty;
  bool get isPrayedFor => state == PrayerFilter.prayedFor;
  bool get isClosed => state == PrayerFilter.closed;

  /// "From your wall" when nothing links it to a piece of content.
  bool get fromWall => contentRef == null;

  /// The next step this prayer can take, or null when it is closed.
  PrayerFilter? get nextState => switch (state) {
    PrayerFilter.open => PrayerFilter.prayedFor,
    PrayerFilter.prayedFor => PrayerFilter.closed,
    PrayerFilter.closed => null,
  };

  /// The same prayer after a change, for the optimistic redraw. `assignee`
  /// set to a person with a null `userId` means "unassigned".
  PrayerRequest copyWith({PrayerFilter? state, ImpactPerson? assignee}) =>
      PrayerRequest(
        id: id,
        body: body,
        status: state?.slug ?? status,
        assignedToUserId: assignee == null ? assignedToUserId : assignee.userId,
        contentRef: contentRef,
        contentRefTitle: contentRefTitle,
        createdAt: createdAt,
        requester: requester,
        assignee: assignee == null
            ? this.assignee
            : (assignee.userId == null ? null : assignee),
      );
}

/// The prayer inbox's counts — `{ open, closed, assigned, receivedThisMonth }`.
class PrayerSummary {
  const PrayerSummary({
    this.open = 0,
    this.closed = 0,
    this.assigned = 0,
    this.receivedThisMonth = 0,
  });

  factory PrayerSummary.fromJson(Map<String, dynamic> json) => PrayerSummary(
    open: json['open'] as int? ?? 0,
    closed: json['closed'] as int? ?? 0,
    assigned: json['assigned'] as int? ?? 0,
    receivedThisMonth: json['receivedThisMonth'] as int? ?? 0,
  );

  final int open;
  final int closed;
  final int assigned;
  final int receivedThisMonth;
}

/// Which testimonies the creator is looking at.
///
/// These three are the whole state machine, so every inbox action is one
/// `status` write. There is no separate "unpublish": taking an approved
/// story off the wall moves it to `rejected`, and restoring puts it back in
/// the pending queue rather than straight back on the wall.
enum TestimonyFilter {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const TestimonyFilter(this.slug);

  final String slug;
}

/// A story a member sent in.
///
/// **Private until approved.** Nothing a viewer submits reaches the public
/// wall without a moderation write.
class CreatorTestimony {
  const CreatorTestimony({
    required this.id,
    required this.body,
    this.status = 'pending',
    this.displayAsAnonymous = false,
    this.mediaId,
    this.impactTags = const [],
    this.createdAt,
    this.author,
  });

  factory CreatorTestimony.fromJson(Map<String, dynamic> json) =>
      CreatorTestimony(
        id: json['id'] as String? ?? '',
        body: json['body'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        displayAsAnonymous: json['displayAsAnonymous'] as bool? ?? false,
        mediaId: json['mediaId'] as String?,
        impactTags: [
          for (final t in json['impactTags'] as List? ?? const [])
            if (t is String) t,
        ],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        author: _person(json['author']),
      );

  final String id;
  final String body;

  /// `pending`, `approved` or `rejected`.
  final String status;

  /// Sent without a name attached. [author] already comes back masked when
  /// this is true; the flag is kept so the card can say so explicitly.
  final bool displayAsAnonymous;

  final String? mediaId;

  /// Platform vocabulary, not free text — see [testimonyImpactTagLabel].
  final List<String> impactTags;

  final DateTime? createdAt;
  final ImpactPerson? author;

  bool get isApproved => status == TestimonyFilter.approved.slug;
  bool get isRejected => status == TestimonyFilter.rejected.slug;

  CreatorTestimony copyWith({TestimonyFilter? state}) => CreatorTestimony(
    id: id,
    body: body,
    status: state?.slug ?? status,
    displayAsAnonymous: displayAsAnonymous,
    mediaId: mediaId,
    impactTags: impactTags,
    createdAt: createdAt,
    author: author,
  );
}

/// The ten impact tags the platform ships (`TESTIMONY_IMPACT_TAGS`).
///
/// A tag added to the platform before this app's next release must still
/// render, so anything unrecognised is humanised rather than dropped.
const _impactTagLabels = <String, String>{
  'healing': 'Healing',
  'salvation': 'Salvation',
  'deliverance': 'Deliverance',
  'restoration': 'Restoration',
  'provision': 'Provision',
  'answered_prayer': 'Answered prayer',
  'mental_health': 'Mental health',
  'purpose': 'Purpose',
  'community': 'Community',
  'miracle': 'Miracle',
};

String testimonyImpactTagLabel(String slug) {
  if (_impactTagLabels[slug] case final known?) return known;
  final words = slug.replaceAll('_', ' ').trim();
  if (words.isEmpty) return slug;
  return words[0].toUpperCase() + words.substring(1);
}

/// The testimony inbox's counts.
class TestimonySummary {
  const TestimonySummary({
    this.received = 0,
    this.pending = 0,
    this.approved = 0,
    this.receivedThisMonth = 0,
  });

  factory TestimonySummary.fromJson(Map<String, dynamic> json) =>
      TestimonySummary(
        received: json['received'] as int? ?? 0,
        pending: json['pending'] as int? ?? 0,
        approved: json['approved'] as int? ?? 0,
        receivedThisMonth: json['receivedThisMonth'] as int? ?? 0,
      );

  final int received;
  final int pending;

  /// "Live on your wall".
  final int approved;

  final int receivedThisMonth;
}

/// Which part of the moderation queue the creator is looking at.
///
/// **This is a queue, not a comment stream.** It holds only comments that
/// need a decision. [both] omits the `status` parameter, which means "both
/// moderation states" — never "everything". `status=visible` is rejected by
/// the gateway and no path here sends it.
enum CommentFilter {
  both(null),
  flagged('flagged'),
  hidden('hidden');

  const CommentFilter(this.slug);

  final String? slug;
}

/// What a decision on a queued comment does.
enum CommentModeration {
  /// Keep it public — this takes the comment **out of the queue**.
  visible('visible'),

  /// Hide it from the creator's content.
  hidden('hidden');

  const CommentModeration(this.slug);

  final String slug;
}

/// A comment waiting on a decision.
class ImpactComment {
  const ImpactComment({
    required this.id,
    required this.body,
    this.status = 'flagged',
    this.targetType = '',
    this.targetId = '',
    this.targetTitle,
    this.parentCommentId,
    this.replyCount = 0,
    this.createdAt,
    this.author,
  });

  factory ImpactComment.fromJson(Map<String, dynamic> json) => ImpactComment(
    id: json['id'] as String? ?? '',
    body: json['body'] as String? ?? '',
    status: json['status'] as String? ?? 'flagged',
    targetType: json['targetType'] as String? ?? '',
    targetId: json['targetId'] as String? ?? '',
    targetTitle: json['targetTitle'] as String?,
    parentCommentId: json['parentCommentId'] as String?,
    replyCount: json['replyCount'] as int? ?? 0,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    author: _person(json['author']),
  );

  final String id;
  final String body;

  /// `flagged` or `hidden`. The queue returns nothing else.
  final String status;

  final String targetType;
  final String targetId;

  /// The content this sits under, hydrated best-effort like
  /// [PrayerRequest.contentRefTitle]. Group on [targetType] + [targetId],
  /// never on this — two pieces of content can share a title.
  final String? targetTitle;

  final String? parentCommentId;

  /// Direct replies on a top-level comment. The thread loads on expand.
  final int replyCount;

  final DateTime? createdAt;
  final ImpactPerson? author;

  bool get isHidden => status == CommentFilter.hidden.slug;
  bool get isFlagged => status == CommentFilter.flagged.slug;
  bool get isReply => (parentCommentId ?? '').isNotEmpty;

  bool matches(CommentFilter filter) =>
      filter.slug == null || filter.slug == status;

  ImpactComment copyWith({String? status}) => ImpactComment(
    id: id,
    body: body,
    status: status ?? this.status,
    targetType: targetType,
    targetId: targetId,
    targetTitle: targetTitle,
    parentCommentId: parentCommentId,
    replyCount: replyCount,
    createdAt: createdAt,
    author: author,
  );
}

/// Why a comment is being reported to the platform.
///
/// `POST /v1/engagement/reports` takes exactly these eight, read off the
/// validator. The design offers eight options too, but they are not the same
/// eight: **"Copyright or impersonation" has no value of its own** and is
/// carried as `other`, which loses the distinction for whoever reviews it.
enum ReportReason {
  spam('spam'),
  hate('hate'),
  harassment('harassment'),
  sexualContent('sexual_content'),
  violence('violence'),
  misinformation('misinformation'),
  abuse('abuse'),
  other('other');

  const ReportReason(this.slug);

  final String slug;
}
