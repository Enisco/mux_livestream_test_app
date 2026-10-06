/// The kinds of thing a reader can narrow a search to.
///
/// `entityTypes` are the values both `POST /v1/discovery/web-feed` and
/// `POST /v1/search/public/query` accept; `all` sends none, which is the
/// mixed default on either route.
enum SearchFilter {
  all('All', []),
  videos('Videos', ['media']),
  live('Live', ['media']),
  audio('Audio', ['media']),
  series('Series', ['media_series']),
  creators('Creators', ['creator']),
  blogs('Blogs', ['post']),
  devotionals('Devotionals', ['devotional_series', 'devotional_entry']),
  events('Events', ['event']);

  const SearchFilter(this.label, this.entityTypes);

  final String label;
  final List<String> entityTypes;

  /// `liveOnly` is a media-only server filter, so it rides with the Live tab.
  bool get liveOnly => this == SearchFilter.live;

  /// Video and Audio share the `media` entity type. The split is the
  /// `media.mediaType` search filter — a server filter, not a client sift.
  String? get mediaType => switch (this) {
    SearchFilter.videos => 'video',
    SearchFilter.audio => 'music',
    _ => null,
  };
}
