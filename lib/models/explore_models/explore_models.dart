import 'package:test_app/models/discovery_models/web_feed_item.dart';

/// hugeicons draws from path data rather than a font, so its glyphs are typed
/// as raw path lists rather than [IconData]. Named here so the shape of a
/// category is readable.
typedef HugeIconData = List<List<dynamic>>;

/// View models for the Explore tab.
///
/// Deliberately flat and presentation-shaped rather than mirrors of a payload:
/// every rail here is composed from several reads, so no single response has
/// this shape. `ExploreRepo` does the mapping.
///
/// Each one keeps the row it came from in `source`, because opening a card
/// means handing the real `WebFeedItem` to the detail screens — the flat
/// fields are for drawing, not for navigating.
class ExploreCreatorRef {
  const ExploreCreatorRef({
    required this.id,
    required this.name,
    this.handle = '',
    this.avatarAsset,
    this.avatarUrl,
    this.verified = false,
    this.subscribers = 0,
    this.isOrganisation = false,
    this.isFollowing = false,
  });

  final String id;
  final String name;

  /// Shown on a creator card, without the leading `@`.
  final String handle;

  /// A bundled placeholder. Set only while the tab runs on dummy content;
  /// real rows arrive with [avatarUrl] instead.
  final String? avatarAsset;
  final String? avatarUrl;

  final bool verified;
  final int subscribers;

  /// Organisations get a purple avatar ring, individuals a cyan one.
  final bool isOrganisation;

  /// What the server last said. The card reads the engagement store over the
  /// top of it, so a follow made anywhere shows here without a refetch.
  final bool isFollowing;
}

/// One thumbnail card in a horizontal rail.
///
/// Every rail on Explore draws the same three things — artwork, a title, and a
/// creator line — so they share one model and differ only in the geometry the
/// rail asks for and the badge the card carries.
class ExploreCard {
  const ExploreCard({
    required this.id,
    required this.title,
    required this.creator,
    this.thumbnailAsset,
    this.thumbnailUrl,
    this.badge,
    this.sponsored = false,
    this.progress,
    this.source,
  });

  final String id;
  final String title;
  final ExploreCreatorRef creator;

  final String? thumbnailAsset;
  final String? thumbnailUrl;

  /// Bottom-right pill: a runtime, a series length, or a reading time.
  final String? badge;

  final bool sponsored;

  /// How far the viewer got, 0-1. Only "Continue watching" sets it.
  final double? progress;

  /// The row this was drawn from, for opening it.
  final WebFeedItem? source;
}

class ExploreEvent {
  const ExploreEvent({
    required this.id,
    required this.title,
    required this.day,
    required this.month,
    required this.venue,
    required this.time,
    required this.creator,
    this.sponsored = false,
    this.source,
  });

  final String id;
  final String title;

  /// Kept as text: the tile prints them verbatim, and the formatting choice
  /// belongs here rather than in the widget.
  final String day;
  final String month;

  final String venue;
  final String time;
  final ExploreCreatorRef creator;
  final bool sponsored;

  /// The row this was drawn from, for opening it.
  final WebFeedItem? source;
}

class ExploreCategory {
  const ExploreCategory({
    required this.slug,
    required this.label,
    required this.icon,
  });

  final String slug;
  final String label;
  final HugeIconData icon;
}

class ExploreHero {
  const ExploreHero({
    required this.id,
    required this.title,
    required this.description,
    required this.creator,
    this.backdropAsset,
    this.backdropUrl,
    this.source,
  });

  final String id;
  final String title;
  final String description;
  final ExploreCreatorRef creator;
  final String? backdropAsset;
  final String? backdropUrl;

  /// The row this was drawn from, for opening it.
  final WebFeedItem? source;
}
