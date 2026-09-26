// Detail payloads for the content types that are *not* media.
//
// `GET /v1/discovery/media/:id/detail` only knows media — asking it for a
// post, devotional or event returns 404. Each of these has its own public
// route (see docs/OPEN_ISSUES.md, issue 26).

class ContentEngagement {
  const ContentEngagement({
    this.views = 0,
    this.likes = 0,
    this.favorites = 0,
    this.comments = 0,
  });

  final int views;
  final int likes;
  final int favorites;
  final int comments;

  factory ContentEngagement.fromJson(Map<String, dynamic> json) =>
      ContentEngagement(
        views: (json['analyticsViews'] as num?)?.toInt() ?? 0,
        likes: (json['engagementLikeCount'] as num?)?.toInt() ?? 0,
        favorites: (json['engagementFavoriteCount'] as num?)?.toInt() ?? 0,
        comments: (json['engagementCommentCount'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /v1/public/content/posts/:id`
class ContentPost {
  const ContentPost({
    required this.id,
    required this.creatorId,
    required this.title,
    this.excerpt,
    this.body,
    this.publishedAt,
    this.scriptureRefs = const [],
    this.categorySlugs = const [],
    this.engagement = const ContentEngagement(),
  });

  final String id;
  final String creatorId;
  final String title;
  final String? excerpt;
  final String? body;
  final DateTime? publishedAt;
  final List<String> scriptureRefs;
  final List<String> categorySlugs;
  final ContentEngagement engagement;

  factory ContentPost.fromJson(Map<String, dynamic> json) {
    final d = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return ContentPost(
      id: d['id'] as String? ?? '',
      creatorId: d['creatorId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      excerpt: d['excerpt'] as String?,
      body: d['body'] as String?,
      publishedAt: DateTime.tryParse(d['publishedAt'] as String? ?? ''),
      scriptureRefs: (d['scriptureRefs'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      categorySlugs: (d['categorySlugs'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      engagement: ContentEngagement.fromJson(d),
    );
  }
}

/// One day inside a devotional series.
class DevotionalEntry {
  const DevotionalEntry({
    required this.id,
    required this.title,
    this.dayNumber,
    this.reflection,
    this.prayer,
    this.memoryVerseRef,
    this.memoryVerseText,
    this.reflectionQuestions = const [],
    this.scriptureRefs = const [],
  });

  final String id;
  final String title;
  final int? dayNumber;
  final String? reflection;
  final String? prayer;
  final String? memoryVerseRef;
  final String? memoryVerseText;
  final List<String> reflectionQuestions;
  final List<String> scriptureRefs;

  factory DevotionalEntry.fromJson(Map<String, dynamic> json) =>
      DevotionalEntry(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        dayNumber: (json['dayNumber'] as num?)?.toInt(),
        reflection: json['reflection'] as String?,
        prayer: json['prayer'] as String?,
        memoryVerseRef: json['memoryVerseRef'] as String?,
        memoryVerseText: json['memoryVerseText'] as String?,
        reflectionQuestions:
            (json['reflectionQuestions'] as List<dynamic>? ?? [])
                .whereType<String>()
                .toList(),
        scriptureRefs: (json['scriptureRefs'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
      );
}

/// `GET /v1/public/content/devotionals/series/:id`
class DevotionalSeriesDetail {
  const DevotionalSeriesDetail({
    required this.id,
    required this.creatorId,
    required this.title,
    this.description,
    this.status,
    this.entries = const [],
    this.completedEntryIds = const [],
    this.currentEntryId,
    this.engagement = const ContentEngagement(),
  });

  final String id;
  final String creatorId;
  final String title;
  final String? description;
  final String? status;
  final List<DevotionalEntry> entries;

  /// From `viewerProgress`; empty for signed-out viewers.
  final List<String> completedEntryIds;
  final String? currentEntryId;
  final ContentEngagement engagement;

  int get entryCount => entries.length;

  bool isCompleted(String entryId) => completedEntryIds.contains(entryId);

  factory DevotionalSeriesDetail.fromJson(Map<String, dynamic> json) {
    final d = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final progress = d['viewerProgress'];
    final progressMap = progress is Map<String, dynamic>
        ? progress
        : const <String, dynamic>{};
    return DevotionalSeriesDetail(
      id: d['id'] as String? ?? '',
      creatorId: d['creatorId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      description: d['description'] as String?,
      status: d['status'] as String?,
      entries: (d['entries'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DevotionalEntry.fromJson)
          .toList(),
      completedEntryIds:
          (progressMap['completedEntryIds'] as List<dynamic>? ?? [])
              .whereType<String>()
              .toList(),
      currentEntryId: progressMap['currentEntryId'] as String?,
      engagement: ContentEngagement.fromJson(d),
    );
  }
}

/// `GET /v1/public/content/events/:id`
class EventDetail {
  const EventDetail({
    required this.id,
    required this.creatorId,
    required this.title,
    this.description,
    this.startAt,
    this.endAt,
    this.locationLabel,
    this.addressLine,
    this.city,
    this.meetingUrl,
    this.venueType,
    this.status,
    this.scriptureRefs = const [],
    this.engagement = const ContentEngagement(),
  });

  final String id;
  final String creatorId;
  final String title;
  final String? description;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? locationLabel;

  /// The street and the city, which is what a map app needs. The event
  /// carries no coordinates, so this text *is* the location.
  final String? addressLine;
  final String? city;

  /// Where a virtual or hybrid event actually happens.
  final String? meetingUrl;

  final String? venueType;
  final String? status;
  final List<String> scriptureRefs;
  final ContentEngagement engagement;

  bool get isOnline => venueType == 'online' || venueType == 'virtual';

  /// Everything that describes where to go, in the order it reads.
  String? get fullAddress {
    final parts = [
      locationLabel?.trim(),
      addressLine?.trim(),
      city?.trim(),
    ].whereType<String>().where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Whether there is enough to point a map at. The venue name alone is
  /// often enough for a well-known place, so it counts.
  bool get hasPlace => (fullAddress ?? '').isNotEmpty && !isOnline;

  factory EventDetail.fromJson(Map<String, dynamic> json) {
    final d = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final location = d['location'];
    final locationMap = location is Map<String, dynamic>
        ? location
        : const <String, dynamic>{};
    return EventDetail(
      id: d['id'] as String? ?? '',
      creatorId: d['creatorId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      description: d['description'] as String?,
      startAt: DateTime.tryParse(d['startAt'] as String? ?? ''),
      endAt: DateTime.tryParse(d['endAt'] as String? ?? ''),
      locationLabel:
          locationMap['label'] as String? ??
          locationMap['name'] as String? ??
          locationMap['address'] as String?,
      addressLine: locationMap['addressLine'] as String?,
      city: locationMap['city'] as String?,
      meetingUrl: locationMap['meetingUrl'] as String?,
      venueType: d['venueType'] as String?,
      status: d['status'] as String?,
      scriptureRefs: (d['scriptureRefs'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      engagement: ContentEngagement.fromJson(d),
    );
  }
}

/// `GET /v1/public/media/series/{id}` — a run of videos and tracks.
///
/// The feed row only says how many of each there are; this is what names
/// them, in the order the creator arranged.
class MediaSeriesDetail {
  const MediaSeriesDetail({
    required this.id,
    required this.title,
    this.creatorId = '',
    this.description = '',
    this.coverThumbnailKey,
    this.categorySlugs = const [],
    this.videoCount = 0,
    this.musicCount = 0,
    this.orderedMediaIds = const [],
  });

  factory MediaSeriesDetail.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return MediaSeriesDetail(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      creatorId: data['creatorId'] as String? ?? '',
      description: data['description'] as String? ?? '',
      coverThumbnailKey: data['coverThumbnailKey'] as String?,
      categorySlugs: [
        for (final s in data['categorySlugs'] as List? ?? const [])
          if (s is String) s,
      ],
      videoCount: (data['videoCount'] as num?)?.toInt() ?? 0,
      musicCount: (data['musicCount'] as num?)?.toInt() ?? 0,
      orderedMediaIds: [
        for (final s in data['orderedMediaIds'] as List? ?? const [])
          if (s is String) s,
      ],
    );
  }

  final String id;
  final String title;
  final String creatorId;
  final String description;
  final String? coverThumbnailKey;
  final List<String> categorySlugs;
  final int videoCount;
  final int musicCount;

  /// The running order. Each id opens on the media detail screen.
  final List<String> orderedMediaIds;

  int get itemCount => orderedMediaIds.length;
}
