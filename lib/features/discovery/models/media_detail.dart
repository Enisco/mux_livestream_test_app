import 'web_feed_item.dart';

class MediaDetailData {
  final MediaInfo media;
  final PlaybackInfo? playback;
  final MediaCreatorInfo? creator;
  final ViewerInfo? viewer;
  final List<WebFeedItem> suggestions;
  final String? nextSuggestionsCursor;

  const MediaDetailData({
    required this.media,
    this.playback,
    this.creator,
    this.viewer,
    this.suggestions = const [],
    this.nextSuggestionsCursor,
  });

  factory MediaDetailData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final suggestionsMap = data['suggestions'] as Map<String, dynamic>?;
    return MediaDetailData(
      media: data['media'] is Map<String, dynamic>
          ? MediaInfo.fromJson(data['media'] as Map<String, dynamic>)
          : const MediaInfo(),
      playback: data['playback'] is Map<String, dynamic>
          ? PlaybackInfo.fromJson(data['playback'] as Map<String, dynamic>)
          : null,
      creator: data['creator'] is Map<String, dynamic>
          ? MediaCreatorInfo.fromJson(data['creator'] as Map<String, dynamic>)
          : null,
      viewer: data['viewer'] is Map<String, dynamic>
          ? ViewerInfo.fromJson(data['viewer'] as Map<String, dynamic>)
          : null,
      suggestions: (suggestionsMap?['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WebFeedItem.fromJson)
          .toList(),
      nextSuggestionsCursor: suggestionsMap?['nextCursor'] as String?,
    );
  }
}

class ViewerInfo {
  final List<String> interactionTypes;
  final bool isFollowingCreator;
  final bool isOwnedByViewer;

  const ViewerInfo({
    this.interactionTypes = const [],
    this.isFollowingCreator = false,
    this.isOwnedByViewer = false,
  });

  bool get hasLiked => interactionTypes.contains('like');
  bool get hasDisliked => interactionTypes.contains('dislike');

  factory ViewerInfo.fromJson(Map<String, dynamic> json) => ViewerInfo(
    interactionTypes: (json['interactionTypes'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList(),
    isFollowingCreator: json['isFollowingCreator'] as bool? ?? false,
    isOwnedByViewer: json['isOwnedByViewer'] as bool? ?? false,
  );
}

class MediaInfo {
  final String id;
  final String type;
  final String title;
  final String? description;
  final String visibility;
  final String status;

  const MediaInfo({
    this.id = '',
    this.type = 'video',
    this.title = '',
    this.description,
    this.visibility = 'public',
    this.status = '',
  });

  factory MediaInfo.fromJson(Map<String, dynamic> json) => MediaInfo(
    id: json['id'] as String? ?? '',
    type: json['type'] as String? ?? 'video',
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    visibility: json['visibility'] as String? ?? 'public',
    status: json['status'] as String? ?? '',
  );
}

class PlaybackInfo {
  final String mediaId;
  final String mediaType;
  final String playbackId;
  final String playbackUrl;
  final String? thumbnailUrl;
  final double? durationSeconds;
  final List<String> availableResolutions;
  final bool canSelectResolution;

  const PlaybackInfo({
    required this.mediaId,
    required this.mediaType,
    required this.playbackId,
    required this.playbackUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.availableResolutions = const [],
    this.canSelectResolution = false,
  });

  factory PlaybackInfo.fromJson(Map<String, dynamic> json) => PlaybackInfo(
    mediaId: json['mediaId'] as String? ?? '',
    mediaType: json['mediaType'] as String? ?? 'video',
    playbackId: json['playbackId'] as String? ?? '',
    playbackUrl: json['playbackUrl'] as String? ?? '',
    thumbnailUrl: json['thumbnailUrl'] as String?,
    durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
    availableResolutions: (json['availableResolutions'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList(),
    canSelectResolution: json['canSelectResolution'] as bool? ?? false,
  );
}

class MediaCreatorInfo {
  final String creatorId;
  final String displayName;
  final String handle;
  final String? avatarKey;
  final bool isVerified;
  final bool isOwnedByViewer;

  const MediaCreatorInfo({
    required this.creatorId,
    required this.displayName,
    required this.handle,
    this.avatarKey,
    this.isVerified = false,
    this.isOwnedByViewer = false,
  });

  factory MediaCreatorInfo.fromJson(Map<String, dynamic> json) => MediaCreatorInfo(
    creatorId: json['creatorId'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    handle: json['handle'] as String? ?? '',
    avatarKey: json['avatarKey'] as String?,
    isVerified: json['isVerified'] as bool? ?? false,
    isOwnedByViewer: json['isOwnedByViewer'] as bool? ?? false,
  );
}
