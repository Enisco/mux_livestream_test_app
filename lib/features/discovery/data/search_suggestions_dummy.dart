/// Autocomplete suggestions for the search field.
///
/// TEMPORARY. The discovery API has no suggest route — and no free-text search
/// route at all (see `docs/OPEN_ISSUES.md`), so there is nothing to ask. These
/// stand in so the typing state of the design has something to show.
///
/// To retire it: delete this file and point [SearchSuggestions.forQuery] at the
/// real endpoint. It is the only place the screen invents a row; every other
/// result on the screen is a live feed row.
abstract final class SearchSuggestions {
  /// A small vocabulary of things a reader plausibly searches this app for.
  static const _phrases = <String>[
    'worship songs',
    'word for today',
    'sunday service',
    'prayer for healing',
    'bible study john',
    'youth conference',
    'gospel music',
    'daily devotional',
    'testimony',
    'sermon on faith',
    'praise and worship',
    'morning prayer',
  ];

  /// Up to [limit] phrases containing what has been typed so far.
  ///
  /// Prefix matches come first — someone typing "wor" means "worship" far more
  /// often than "word for today", even though both contain it.
  static List<String> forQuery(String query, {int limit = 4}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final starts = <String>[];
    final contains = <String>[];
    for (final phrase in _phrases) {
      if (phrase.startsWith(q)) {
        starts.add(phrase);
      } else if (phrase.contains(q)) {
        contains.add(phrase);
      }
    }
    return [...starts, ...contains].take(limit).toList(growable: false);
  }
}
