import 'package:test_app/models/analytics_models/analytics_models.dart';

class WebFeedItem {
  final String entityType;
  final String entityId;
  final String title;
  final WebFeedCreator? creator;
  final WebFeedItemMeta meta;
  final WebFeedFacets facets;
  final String? subtitle;
  final bool isFollowingCreator;

  const WebFeedItem({
    required this.entityType,
    required this.entityId,
    required this.title,
    this.creator,
    required this.meta,
    this.facets = const WebFeedFacets(),
    this.subtitle,
    this.isFollowingCreator = false,
  });

  PromotionAttribution? get promotion => meta.promotion;

  bool get isPromoted => meta.promotion != null;

  String? get mediaType => facets.mediaType ?? meta.mediaType;

  bool get isLiveNow => facets.isLiveNow || meta.isLiveNow;

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
    facets: json['facets'] is Map<String, dynamic>
        ? WebFeedFacets.fromJson(json['facets'] as Map<String, dynamic>)
        : const WebFeedFacets(),
    subtitle: json['subtitle'] as String?,
    isFollowingCreator: json['isFollowingCreator'] as bool? ?? false,
  );
}

class WebFeedCreator {
  final String creatorId;
  final String displayName;
  final String handle;
  final String? avatarKey;
  final bool isVerified;
  final bool isFollowing;
  final int subscriberCount;

  const WebFeedCreator({
    required this.creatorId,
    required this.displayName,
    required this.handle,
    this.avatarKey,
    this.isVerified = false,
    this.isFollowing = false,
    this.subscriberCount = 0,
  });

  factory WebFeedCreator.fromJson(Map<String, dynamic> json) => WebFeedCreator(
    creatorId: json['creatorId'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    handle: json['handle'] as String? ?? '',
    avatarKey: json['avatarKey'] as String?,
    isVerified: json['isVerified'] as bool? ?? json['verifiedAt'] != null,
    isFollowing: json['isFollowing'] as bool? ?? false,
    subscriberCount: (json['subscriberCount'] as num?)?.toInt() ?? 0,
  );
}

class WebFeedFacets {
  final String? mediaType;
  final bool isLiveNow;
  final List<String> categorySlugs;
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final int favorites;

  const WebFeedFacets({
    this.mediaType,
    this.isLiveNow = false,
    this.categorySlugs = const [],
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.favorites = 0,
  });

  factory WebFeedFacets.fromJson(Map<String, dynamic> json) => WebFeedFacets(
    mediaType: MediaTypes.normalize(json['mediaType'] as String?),
    isLiveNow: json['isLiveNow'] as bool? ?? false,
    categorySlugs: (json['categorySlugs'] as List<dynamic>? ?? [])
        .cast<String>(),
    views: (json['analyticsViews'] as num?)?.toInt() ?? 0,
    likes: (json['engagementLikeCount'] as num?)?.toInt() ?? 0,
    comments: (json['engagementCommentCount'] as num?)?.toInt() ?? 0,
    shares: (json['engagementShareCount'] as num?)?.toInt() ?? 0,
    favorites: (json['engagementFavoriteCount'] as num?)?.toInt() ?? 0,
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
  final DateTime? publishedAt;
  final DateTime? scheduledAt;
  final PromotionAttribution? promotion;

  const WebFeedItemMeta({
    this.thumbnailUrl,
    this.previewUrl,
    this.thumbnailKey,
    this.thumbnailSource,
    this.durationSeconds,
    this.mediaType,
    this.isLiveNow = false,
    this.publishedAt,
    this.scheduledAt,
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
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
        scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? ''),
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
