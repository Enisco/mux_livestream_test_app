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
  /// the API refuses the post without one (OPEN_ISSUES 32).
  final String title;

  /// GFM markdown. Inline images are `![alt](file:{fileId})`, which the
  /// content service confirms when the post naming them is saved.
  final String body;

  final String excerpt;
  final List<String> categorySlugs;

  /// `public`, `unlisted` or `private`.
  final String visibility;

  final String? coverThumbnailFileId;

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
