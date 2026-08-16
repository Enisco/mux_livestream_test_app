import 'package:test_app/models/discovery_models/web_feed_item.dart';

/// The kinds of thing a reader can narrow a search to.
///
/// `entityTypes` are the values `POST /v1/discovery/web-feed` accepts; `all`
/// sends none, which is the API's default mixed feed.
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

  /// Video and Audio share one entity type, so the split happens on the client
  /// against each row's media type.
  String? get mediaType => switch (this) {
    SearchFilter.videos => 'video',
    SearchFilter.audio => 'music',
    _ => null,
  };
}

/// Client-side matching for a typed query.
///
/// The discovery API has no free-text search (see `docs/OPEN_ISSUES.md`), so a
/// query narrows what the feed returned rather than what it asks for. Kept pure
/// so the matching rules can be tested directly.
abstract final class SearchMatcher {
  /// Splits on whitespace; every word must appear somewhere in the row.
  ///
  /// Matching all words rather than any keeps two-word queries useful — "kids
  /// worship" should not return every row with "worship" in it.
  static bool matches(WebFeedItem item, String query) {
    final terms = tokens(query);
    if (terms.isEmpty) return true;
    final haystack = _haystack(item);
    return terms.every(haystack.contains);
  }

  static List<String> tokens(String query) => query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  static String _haystack(WebFeedItem item) => [
    item.title,
    item.subtitle ?? '',
    item.creatorDisplayName,
    item.creatorHandle,
    item.meta.description ?? '',
    item.meta.seriesTitle ?? '',
    item.meta.locationLabel ?? '',
  ].join(' ').toLowerCase();

  /// Applies the type filter the API cannot express on its own.
  static bool passesFilter(WebFeedItem item, SearchFilter filter) {
    final wanted = filter.mediaType;
    if (wanted == null) return true;
    return item.mediaType == wanted;
  }

  static List<WebFeedItem> apply(
    List<WebFeedItem> items,
    String query,
    SearchFilter filter,
  ) => items
      .where((i) => passesFilter(i, filter) && matches(i, query))
      .toList(growable: false);
}
