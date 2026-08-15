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

  /// Events carry their schedule at the top level, not in `meta`.
  final DateTime? calendarStartAt;
  final DateTime? calendarEndAt;

  const WebFeedItem({
    required this.entityType,
    required this.entityId,
    required this.title,
    this.creator,
    required this.meta,
    this.facets = const WebFeedFacets(),
    this.subtitle,
    this.isFollowingCreator = false,
    this.calendarStartAt,
    this.calendarEndAt,
  });

  PromotionAttribution? get promotion => meta.promotion;

  bool get isPromoted => meta.promotion != null;

  String? get mediaType => facets.mediaType ?? meta.mediaType;

  bool get isLiveNow => facets.isLiveNow || meta.isLiveNow;

  /// When this starts. Events use the calendar fields; media uses `scheduledAt`.
  DateTime? get startsAt => calendarStartAt ?? meta.scheduledAt;

  /// A `creator` row has no nested `creator` object — its identity is in `meta`
  /// and `title`/`subtitle`. Everything else has the nested object.
  bool get isCreatorRow => entityType == 'creator' || entityType == 'user';

  String get creatorDisplayName =>
      isCreatorRow ? title : creator?.displayName ?? '';

  String get creatorHandle =>
      (isCreatorRow ? meta.handle ?? subtitle ?? '' : creator?.handle ?? '')
          .replaceFirst('@', '');

  /// The creator this row belongs to — for a creator row that is the row
  /// itself, for content it is the nested creator.
  String? get profileCreatorId {
    if (isCreatorRow) return entityId.isEmpty ? null : entityId;
    final id = creator?.creatorId;
    return id == null || id.isEmpty ? null : id;
  }

  bool get creatorVerified =>
      isCreatorRow ? meta.isVerified : creator?.isVerified ?? false;

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
    calendarStartAt: DateTime.tryParse(
      json['calendarStartAt'] as String? ?? '',
    ),
    calendarEndAt: DateTime.tryParse(json['calendarEndAt'] as String? ?? ''),
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

  /// Creator rows.
  final String? handle;
  final bool isVerified;
  final String? avatarKey;
  final String? creatorType;

  /// Events.
  final String? locationLabel;

  /// Devotional series.
  final String? description;
  final int? publishedEntryCount;

  /// Devotional entries.
  final int? dayNumber;
  final String? seriesTitle;

  /// Media series.
  final int? videoCount;
  final int? musicCount;

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
    this.handle,
    this.isVerified = false,
    this.avatarKey,
    this.creatorType,
    this.locationLabel,
    this.description,
    this.publishedEntryCount,
    this.dayNumber,
    this.seriesTitle,
    this.videoCount,
    this.musicCount,
  });

  factory WebFeedItemMeta.fromJson(Map<String, dynamic> json) =>
      WebFeedItemMeta(
        thumbnailUrl: json['thumbnailUrl'] as String?,
        previewUrl: json['previewUrl'] as String?,
        thumbnailKey:
            json['thumbnailKey'] as String? ??
            json['coverThumbnailKey'] as String? ??
            json['coverImageKey'] as String?,
        thumbnailSource: json['thumbnailSource'] as String?,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
        mediaType: MediaTypes.normalize(
          json['mediaType'] as String? ?? json['type'] as String?,
        ),
        isLiveNow: json['isLiveNow'] as bool? ?? false,
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
        scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? ''),
        promotion: PromotionAttribution.tryParse(json),
        handle: json['handle'] as String?,
        isVerified: json['isVerified'] as bool? ?? json['verifiedAt'] != null,
        avatarKey: json['avatarKey'] as String?,
        creatorType: json['creatorType'] as String?,
        locationLabel: json['locationLabel'] as String?,
        description: json['description'] as String?,
        publishedEntryCount: (json['publishedEntryCount'] as num?)?.toInt(),
        dayNumber: (json['dayNumber'] as num?)?.toInt(),
        seriesTitle: json['seriesTitle'] as String?,
        videoCount: (json['videoCount'] as num?)?.toInt(),
        musicCount: (json['musicCount'] as num?)?.toInt(),
      );
}

class WebFeedResponse {
  final List<WebFeedItem> items;
  final String? nextCursor;

  /// Only the library search reports a total.
  final int? total;

  const WebFeedResponse({required this.items, this.nextCursor, this.total});

  /// Feeds return `data.items`; the creator-library search returns `data.hits`
  /// with a `total`. Same row shape either way.
  factory WebFeedResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final rows = data['items'] ?? data['hits'];
    return WebFeedResponse(
      total: (data['total'] as num?)?.toInt(),
      items: (rows as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WebFeedItem.fromJson)
          .toList(),
      nextCursor: data['nextCursor'] as String?,
    );
  }
}

/// A ministry suggested on the empty Following tab.
class RecommendedCreator {
  const RecommendedCreator({
    required this.creatorId,
    required this.displayName,
    required this.handle,
    this.avatarKey,
    this.isVerified = false,
    this.isFollowing = false,
  });

  final String creatorId;
  final String displayName;
  final String handle;
  final String? avatarKey;
  final bool isVerified;
  final bool isFollowing;

  factory RecommendedCreator.fromJson(Map<String, dynamic> json) =>
      RecommendedCreator(
        creatorId: json['creatorId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        handle: (json['handle'] as String? ?? '').replaceFirst('@', ''),
        avatarKey: json['avatarKey'] as String?,
        isVerified: json['isVerified'] as bool? ?? json['verifiedAt'] != null,
        isFollowing: json['isFollowing'] as bool? ?? false,
      );
}
