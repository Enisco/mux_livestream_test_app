/// hugeicons draws from path data rather than a font, so its glyphs are typed
/// as raw path lists rather than [IconData]. Named here so the shape of a
/// category is readable.
typedef HugeIconData = List<List<dynamic>>;

/// View models for the Explore tab.
///
/// These are deliberately flat and presentation-shaped rather than mirrors of
/// an API payload: the discovery endpoints for Explore do not exist yet, so
/// there is nothing to mirror. When the backend guides land, the mapping layer
/// parses into these and only [ExploreDummyData] goes away — the widgets keep
/// reading the same fields.
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
  });

  final String id;
  final String title;

  /// Kept as text, not a DateTime: the tile prints them verbatim and the API
  /// has not settled on a format yet.
  final String day;
  final String month;

  final String venue;
  final String time;
  final ExploreCreatorRef creator;
  final bool sponsored;
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
  });

  final String id;
  final String title;
  final String description;
  final ExploreCreatorRef creator;
  final String? backdropAsset;
  final String? backdropUrl;
}
