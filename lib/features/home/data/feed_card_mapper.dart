import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

/// Turns a web-feed row into card data.
///
/// Every `entityType` the discovery API can return has to land on a
/// [FeedCardKind], and each type keeps its own fields in its own place — events
/// carry `calendarStartAt` at the top level, creators have no nested `creator`
/// object, and post/devotional bodies live in different keys again. Kept out of
/// the screen so the whole table can be tested against real payloads.
abstract final class FeedCardMapper {
  /// [interactions] is the viewer's own like/save state, keyed by entity id,
  /// as returned by the engagement batch route. Empty for guests.
  static FeedCardData toCardData(
    WebFeedItem item, {
    Map<String, Set<String>> interactions = const {},
  }) {
    final mine = interactions[item.entityId] ?? const <String>{};
    final meta = item.meta;
    final facets = item.facets;
    final creator = item.creator;
    final kind = kindOf(item);
    final isChannel = kind == FeedCardKind.channel;
    final name = item.creatorDisplayName;
    return FeedCardData(
      id: item.entityId,
      creatorId: item.creator?.creatorId ?? '',
      kind: kind,
      creatorName: name.isEmpty ? AppStrings.brandName : name,
      handle: item.creatorHandle,
      age: relativeAge(meta.publishedAt),
      title: isChannel || item.title.isEmpty ? null : item.title,
      body: bodyFor(kind, item),
      subtitle: subtitleFor(kind, item),
      planLabel: kind == FeedCardKind.devotional
          ? planLabel(facets.categorySlugs)
          : null,
      category: facets.categorySlugs.isEmpty
          ? null
          : titleCase(facets.categorySlugs.first),
      eventStart: item.startsAt,
      location: meta.locationLabel,
      thumbnailUrl: meta.thumbnailUrl,
      duration: duration(meta.durationSeconds),
      verified: item.creatorVerified,
      avatarUrl: isChannel ? meta.thumbnailUrl : null,
      sponsored: item.isPromoted,
      likes: facets.likes,
      saves: facets.favorites,
      comments: facets.comments,
      views: facets.views > 0 ? formatCount(facets.views) : null,
      viewCount: facets.views,
      following: item.isFollowingCreator || (creator?.isFollowing ?? false),
      subscribers: creator?.subscriberCount ?? 0,
      liked: mine.contains(InteractionTypes.like),
      saved: mine.contains(InteractionTypes.favorite),
    );
  }

  static FeedCardKind kindOf(WebFeedItem item) {
    if (item.isLiveNow) return FeedCardKind.live;
    return switch (item.entityType) {
      // `user` rows carry the same shape as `creator`.
      'creator' || 'user' => FeedCardKind.channel,
      'event' => FeedCardKind.event,
      'post' => FeedCardKind.post,
      'blog' || 'devotional_entry' => FeedCardKind.blog,
      'devotional_series' => FeedCardKind.devotional,
      'media_series' => FeedCardKind.series,
      _ => switch (item.mediaType) {
        MediaTypes.music => FeedCardKind.audio,
        MediaTypes.livestream => FeedCardKind.live,
        _ => FeedCardKind.video,
      },
    };
  }

  /// Prose the card renders as its own paragraph.
  static String? bodyFor(FeedCardKind kind, WebFeedItem item) => switch (kind) {
    // A post's subtitle is the excerpt itself, not a status line.
    FeedCardKind.post || FeedCardKind.blog => excerpt(item.subtitle),
    FeedCardKind.channel => excerpt(item.meta.description),
    _ => null,
  };

  /// The supporting line under the title.
  static String? subtitleFor(FeedCardKind kind, WebFeedItem item) {
    final meta = item.meta;
    return switch (kind) {
      // The series blurb lives in meta; `subtitle` is only "public · active".
      FeedCardKind.devotional =>
        excerpt(meta.description) ??
            (meta.publishedEntryCount == null
                ? null
                : '${meta.publishedEntryCount} day plan'),
      FeedCardKind.series => seriesCount(meta.videoCount, meta.musicCount),
      _ => null,
    };
  }

  static String? seriesCount(int? videos, int? music) {
    final parts = [
      if ((videos ?? 0) > 0) '$videos ${videos == 1 ? 'video' : 'videos'}',
      if ((music ?? 0) > 0) '$music ${music == 1 ? 'track' : 'tracks'}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Words the API uses for status, not for people. A subtitle made only of
  /// these is plumbing ("public · active") and must not reach the card.
  static const _statusWords = {
    'public',
    'private',
    'unlisted',
    'draft',
    'active',
    'inactive',
    'archived',
    'published',
    'scheduled',
    'video',
    'music',
    'livestream',
    'series',
  };

  static String? excerpt(String? subtitle) {
    if (subtitle == null || subtitle.trim().isEmpty) return null;
    final parts = subtitle
        .split(RegExp(r'[·•|]'))
        .map((p) => p.trim().toLowerCase())
        .where((p) => p.isNotEmpty);
    if (parts.isNotEmpty && parts.every(_statusWords.contains)) return null;
    return subtitle;
  }

  static String? planLabel(List<String> slugs) =>
      slugs.isEmpty ? null : '${titleCase(slugs.first)} plan';

  static String titleCase(String slug) => slug
      .split(RegExp(r'[-_ ]'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  static String? duration(double? seconds) {
    if (seconds == null || seconds <= 0) return null;
    final total = seconds.round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
