import '../../analytics/models/analytics_models.dart';

class WebFeedItem {
  final String entityType;
  final String entityId;
  final String title;
  final WebFeedCreator? creator;
  final WebFeedItemMeta meta;

  const WebFeedItem({
    required this.entityType,
    required this.entityId,
    required this.title,
    this.creator,
    required this.meta,
  });

  /// Server-issued promotion attribution, or null for organic items.
  /// Lives on the feed item only — it is used to emit source-surface analytics
  /// and is never appended to a destination route.
  PromotionAttribution? get promotion => meta.promotion;

  bool get isPromoted => meta.promotion != null;

  /// `mediaType` for analytics beacons, when the feed told us.
  String? get mediaType => meta.mediaType;

  factory WebFeedItem.fromJson(Map<String, dynamic> json) => WebFeedItem(
    entityType: json['entityType'] as String? ?? '',
    entityId: json['entityId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    creator: json['creator'] is Map<String, dynamic>
        ? WebFeedCreator.fromJson(json['creator'] as Map<String, dynamic>)
        : null,
    meta: json['meta'] is Map<String, dynamic>
        ? WebFeedItemMeta.fromJson(json['meta'] as Map<String, dynamic>)
        : const WebFeedItemMeta(),
  );
}

class WebFeedCreator {
  final String creatorId;
  final String displayName;
  final String handle;
  final String? avatarKey;

  const WebFeedCreator({
    required this.creatorId,
    required this.displayName,
    required this.handle,
    this.avatarKey,
  });

  factory WebFeedCreator.fromJson(Map<String, dynamic> json) => WebFeedCreator(
    creatorId: json['creatorId'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    handle: json['handle'] as String? ?? '',
    avatarKey: json['avatarKey'] as String?,
  );
}

class WebFeedItemMeta {
  final String? thumbnailUrl;
  final String? previewUrl;
  final String? thumbnailKey;
  final String? thumbnailSource;
  final double? durationSeconds;
  final String? mediaType;
  final bool isLiveNow;
  final PromotionAttribution? promotion;

  const WebFeedItemMeta({
    this.thumbnailUrl,
    this.previewUrl,
    this.thumbnailKey,
    this.thumbnailSource,
    this.durationSeconds,
    this.mediaType,
    this.isLiveNow = false,
    this.promotion,
  });

  factory WebFeedItemMeta.fromJson(Map<String, dynamic> json) =>
      WebFeedItemMeta(
        thumbnailUrl: json['thumbnailUrl'] as String?,
        previewUrl: json['previewUrl'] as String?,
        thumbnailKey: json['thumbnailKey'] as String?,
        thumbnailSource: json['thumbnailSource'] as String?,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
        mediaType: MediaTypes.normalize(
          json['mediaType'] as String? ?? json['type'] as String?,
        ),
        isLiveNow: json['isLiveNow'] as bool? ?? false,
        promotion: PromotionAttribution.tryParse(json),
      );
}

class WebFeedResponse {
  final List<WebFeedItem> items;
  final String? nextCursor;

  const WebFeedResponse({required this.items, this.nextCursor});

  factory WebFeedResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return WebFeedResponse(
      items: (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WebFeedItem.fromJson)
          .toList(),
      nextCursor: data['nextCursor'] as String?,
    );
  }
}
