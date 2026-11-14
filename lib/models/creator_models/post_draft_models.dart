/// Writing an article.
///
/// A post is markdown and images in the **content** service — nothing is
/// uploaded to Mux and nothing is transcoded. Its images go through the
/// same `/v1/content/assets/upload-url` ticket an event's cover does.
///
/// Everything here was read off staging.
library;

/// What a creator is about to file.
class PostDraft {
  const PostDraft({
    required this.title,
    this.body = '',
    this.excerpt = '',
    this.categorySlugs = const [],
    this.visibility = 'public',
    this.coverThumbnailFileId,
  });

  /// **Required, 1–500 characters — even to save a draft.** The design
  /// calls the headline "optional, but it helps people find your post";
  /// the API refuses the post without one, so the form asks for it.
  final String title;

  /// GFM markdown. Inline images are `![alt](file:{fileId})`, which the
  /// content service confirms when the post naming them is saved.
  final String body;

  final String excerpt;
  final List<String> categorySlugs;

  /// `public`, `unlisted` or `private`.
  final String visibility;

  final String? coverThumbnailFileId;

  /// An article as `GET /v1/content/posts/{id}` returns it, so the editor
  /// can open what is already there.
  ///
  /// The cover comes back as **two** fields: `coverThumbnailFileId`, which
  /// is what a write takes, and `coverThumbnailKey`, which is where the
  /// picture is. Only the id is carried here; the key is what the screen
  /// shows, and it is read separately.
  factory PostDraft.fromJson(Map<String, dynamic> json) => PostDraft(
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    excerpt: json['excerpt'] as String? ?? '',
    categorySlugs: [
      for (final slug in json['categorySlugs'] as List? ?? const [])
        if (slug is String) slug,
    ],
    visibility: json['visibility'] as String? ?? 'public',
    coverThumbnailFileId: json['coverThumbnailFileId'] as String?,
  );

  PostDraft copyWith({
    String? title,
    String? body,
    String? excerpt,
    List<String>? categorySlugs,
    String? visibility,
    String? coverThumbnailFileId,
  }) => PostDraft(
    title: title ?? this.title,
    body: body ?? this.body,
    excerpt: excerpt ?? this.excerpt,
    categorySlugs: categorySlugs ?? this.categorySlugs,
    visibility: visibility ?? this.visibility,
    coverThumbnailFileId: coverThumbnailFileId ?? this.coverThumbnailFileId,
  );

  /// What `PATCH /v1/content/posts/{id}` takes.
  ///
  /// Unlike [toJson] this sends empty strings rather than leaving the key
  /// out, because on an edit an empty field is the creator **clearing**
  /// something, and a key left out would silently keep the old value.
  /// `creatorId` is not sent: the route resolves ownership from the path.
  /// `scheduledAt` is not sent either — it is a publishing decision, and
  /// setting it from the editor would reschedule a post the creator only
  /// meant to correct a typo in.
  Map<String, dynamic> toPatchJson() => {
    'title': title,
    'body': body,
    'excerpt': excerpt,
    'categorySlugs': categorySlugs,
    'visibility': visibility,
    'coverThumbnailFileId': ?coverThumbnailFileId,
  };

  /// What `POST /v1/content/posts` takes.
  ///
  /// `scheduledAt` is deliberately absent: create refuses it ("property
  /// scheduledAt should not exist") and it goes on with a PATCH instead.
  Map<String, dynamic> toJson(String creatorId) => {
    'creatorId': creatorId,
    'title': title,
    if (body.isNotEmpty) 'body': body,
    if (excerpt.isNotEmpty) 'excerpt': excerpt,
    if (categorySlugs.isNotEmpty) 'categorySlugs': categorySlugs,
    'visibility': visibility,
    'coverThumbnailFileId': ?coverThumbnailFileId,
  };

  /// Whether the API will let this be published rather than only saved.
  /// Publishing is readiness-gated on a non-empty title *and* body.
  PostPublishBlock? get publishBlock {
    if (title.trim().isEmpty) return PostPublishBlock.title;
    if (body.trim().isEmpty) return PostPublishBlock.body;
    return null;
  }

  /// "2 min read", the way the design's preview writes it. Two hundred
  /// words a minute, and never less than a minute.
  int get readMinutes {
    final words = body
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .length;
    return words <= 0 ? 1 : (words / 200).ceil().clamp(1, 999);
  }
}

/// What the publish check would refuse this draft for.
enum PostPublishBlock { title, body }

/// One `![alt](file:{id})` in a body, as the resolver answers for it.
///
/// `POST /v1/content/posts/body-embeds/resolve` takes `{creatorId, body}`
/// and returns one of these per token. An image that has been uploaded but
/// is not yet named by a saved post comes back `available: false` with
/// `reason: not_uploaded` — that is an unsaved draft, not a failure.
class BodyEmbed {
  const BodyEmbed({
    required this.fileId,
    this.alt = '',
    this.available = false,
    this.url,
    this.reason,
  });

  factory BodyEmbed.fromJson(Map<String, dynamic> json) => BodyEmbed(
    fileId: json['fileId'] as String? ?? '',
    alt: json['alt'] as String? ?? '',
    available: json['available'] as bool? ?? false,
    url: json['url'] as String?,
    reason: json['reason'] as String?,
  );

  final String fileId;
  final String alt;
  final bool available;

  /// A CloudFront URL once the post naming it has been saved.
  final String? url;

  final String? reason;
}
