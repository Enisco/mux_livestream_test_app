class VerticalFeedItem {
  final String mediaId;
  final String creatorId;
  final String title;
  final String type;
  final bool isLiveNow;
  final String? thumbnailUrl;
  final String? previewUrl;
  final double? durationSeconds;

  const VerticalFeedItem({
    required this.mediaId,
    required this.creatorId,
    required this.title,
    required this.type,
    required this.isLiveNow,
    this.thumbnailUrl,
    this.previewUrl,
    this.durationSeconds,
  });

  factory VerticalFeedItem.fromJson(Map<String, dynamic> json) => VerticalFeedItem(
    mediaId: json['mediaId'] as String? ?? '',
    creatorId: json['creatorId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    type: json['type'] as String? ?? 'video',
    isLiveNow: json['isLiveNow'] as bool? ?? false,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    previewUrl: json['previewUrl'] as String?,
    durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
  );
}

class VerticalFeedResponse {
  final List<VerticalFeedItem> items;
  final String? nextCursor;

  const VerticalFeedResponse({required this.items, this.nextCursor});

  factory VerticalFeedResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return VerticalFeedResponse(
      items: (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(VerticalFeedItem.fromJson)
          .toList(),
      nextCursor: data['nextCursor'] as String?,
    );
  }
}
