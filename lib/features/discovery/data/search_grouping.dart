import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

/// How a result is presented.
///
/// The design draws three groups because its sample only held three kinds. The
/// feed returns more, so every kind gets a group rather than being forced into
/// one that misnames it.
enum SearchGroupKind {
  ministries(AppStrings.searchGroupMinistries),
  videos(AppStrings.searchGroupVideos, AppStrings.searchKindVideo),
  audio(AppStrings.searchGroupAudio, AppStrings.searchKindAudio),
  devotionals(
    AppStrings.searchGroupDevotionals,
    AppStrings.searchKindDevotional,
  ),
  blogs(AppStrings.searchGroupBlogs, AppStrings.searchKindBlog),
  series(AppStrings.searchGroupSeries, AppStrings.searchKindSeries),
  events(AppStrings.searchGroupEvents);

  const SearchGroupKind(this.heading, [this.rowLabel = '']);

  /// The caption above the group.
  final String heading;

  /// What a row's meta line leads with. Empty for groups whose rows do not
  /// carry one.
  final String rowLabel;
}

class SearchGroup {
  const SearchGroup(this.kind, this.items);

  final SearchGroupKind kind;
  final List<WebFeedItem> items;
}

/// Sorts results into the groups the screen renders, in a fixed order.
///
/// Order is by usefulness, not by count: a reader searching a ministry's name
/// wants the ministry itself first, and an event is time-sensitive enough to
/// deserve the bottom slot where it will not be scrolled past.
abstract final class SearchGrouping {
  static const _order = [
    SearchGroupKind.ministries,
    SearchGroupKind.videos,
    SearchGroupKind.audio,
    SearchGroupKind.devotionals,
    SearchGroupKind.blogs,
    SearchGroupKind.series,
    SearchGroupKind.events,
  ];

  static SearchGroupKind kindOf(WebFeedItem item) {
    if (item.isCreatorRow) return SearchGroupKind.ministries;
    return switch (item.entityType) {
      'event' => SearchGroupKind.events,
      'post' => SearchGroupKind.blogs,
      'devotional_series' || 'devotional_entry' => SearchGroupKind.devotionals,
      'media_series' => SearchGroupKind.series,
      _ =>
        item.meta.mediaType == 'music' || item.facets.mediaType == 'music'
            ? SearchGroupKind.audio
            : SearchGroupKind.videos,
    };
  }

  /// Non-empty groups only, so the screen never draws a bare heading.
  static List<SearchGroup> apply(List<WebFeedItem> items) {
    final buckets = <SearchGroupKind, List<WebFeedItem>>{};
    for (final item in items) {
      (buckets[kindOf(item)] ??= []).add(item);
    }
    return [
      for (final kind in _order)
        if (buckets[kind] case final rows? when rows.isNotEmpty)
          SearchGroup(kind, rows),
    ];
  }
}
