class VerticalFeedItem {
  final String mediaId;
  final String creatorId;
  final String? creatorHandle;
  final String? creatorDisplayName;
  final String title;
  final String type;
  final bool isLiveNow;
  final String? thumbnailUrl;
  final String? previewUrl;
  final double? durationSeconds;
  final int? likeCount;
  final int? commentCount;

  const VerticalFeedItem({
    required this.mediaId,
    required this.creatorId,
    this.creatorHandle,
    this.creatorDisplayName,
    required this.title,
    required this.type,
    required this.isLiveNow,
    this.thumbnailUrl,
    this.previewUrl,
    this.durationSeconds,
    this.likeCount,
    this.commentCount,
  });

  factory VerticalFeedItem.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] is Map<String, dynamic>
        ? json['creator'] as Map<String, dynamic>
        : null;
    return VerticalFeedItem(
      mediaId: json['mediaId'] as String? ?? '',
      creatorId: json['creatorId'] as String? ?? '',
      creatorHandle: creator?['handle'] as String?,
      creatorDisplayName: creator?['displayName'] as String?,
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'video',
      isLiveNow: json['isLiveNow'] as bool? ?? false,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      previewUrl: json['previewUrl'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
      likeCount: json['likeCount'] as int?,
      commentCount: json['commentCount'] as int?,
    );
  }
}

class VerticalFeedResponse {
  final List<VerticalFeedItem> items;
  final String? nextCursor;

  const VerticalFeedResponse({required this.items, this.nextCursor});

  factory VerticalFeedResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    return VerticalFeedResponse(
      items: (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(VerticalFeedItem.fromJson)
          .toList(),
      nextCursor: data['nextCursor'] as String?,
    );
  }
}
