class CommentAuthor {
  final String displayName;
  final String handle;
  final bool isVerified;

  const CommentAuthor({
    required this.displayName,
    required this.handle,
    this.isVerified = false,
  });

  factory CommentAuthor.fromJson(Map<String, dynamic> json) => CommentAuthor(
    displayName: json['displayName'] as String? ?? '',
    handle: json['handle'] as String? ?? '',
    isVerified: json['isVerified'] as bool? ?? false,
  );
}

class MediaComment {
  final String id;
  final String body;
  final CommentAuthor? author;
  final DateTime createdAt;
  final int likeCount;
  final int replyCount;

  const MediaComment({
    required this.id,
    required this.body,
    this.author,
    required this.createdAt,
    this.likeCount = 0,
    this.replyCount = 0,
  });

  factory MediaComment.fromJson(Map<String, dynamic> json) => MediaComment(
    id: json['id'] as String? ?? '',
    body: json['body'] as String? ?? '',
    author: json['author'] is Map<String, dynamic>
        ? CommentAuthor.fromJson(json['author'] as Map<String, dynamic>)
        : null,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    likeCount: json['likeCount'] as int? ?? 0,
    replyCount: json['replyCount'] as int? ?? 0,
  );
}

class CommentsResponse {
  final List<MediaComment> items;
  final String? nextCursor;

  const CommentsResponse({required this.items, this.nextCursor});

  factory CommentsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return CommentsResponse(
      items: (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MediaComment.fromJson)
          .toList(),
      nextCursor: data['nextCursor'] as String?,
    );
  }
}
