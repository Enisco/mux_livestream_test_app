/// What the reader has watched and read, and where they left off.
///
/// Shaped for the screen rather than for any one payload: History, Liked and
/// Saved return the same enriched search hit under different envelopes, so one
/// model feeds all three and `ViewerLibraryRepo` does the mapping.
library;

/// The kinds of thing history remembers. Each names itself on its own row.
enum HistoryKind {
  video('Video', 'views'),
  audio('Audio', 'plays'),
  devotional('Devotional', 'views'),
  blog('Blog', 'opens'),
  event('Event', ''),
  library('Video', 'views');

  const HistoryKind(this.label, this.countNoun);

  /// What the meta line leads with.
  final String label;

  /// "12k **views**", "10 **plays**", "12 **opens**" — the design counts each
  /// kind in its own words.
  final String countNoun;
}

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.creatorName,
    required this.age,
    this.creatorVerified = false,
    this.thumbnailAsset,
    this.thumbnailUrl,
    this.count = 0,
    this.duration,
    this.progress,
    this.eventDate,
    this.eventVenue,
    this.eventTime,
    this.targetType = '',
  });

  final String id;
  final HistoryKind kind;
  final String title;
  final String creatorName;
  final bool creatorVerified;

  /// Already formatted — "6d", "6d ago".
  final String age;

  final String? thumbnailAsset;
  final String? thumbnailUrl;

  /// Views, plays or opens, depending on [kind].
  final int count;

  /// "00:25" on the still.
  final String? duration;

  /// How far the reader got, 0-1. Only part-watched rows carry one.
  final double? progress;

  final String? eventDate;
  final String? eventVenue;
  final String? eventTime;

  /// What to pass to an engagement call for this row.
  ///
  /// The list gives it as `engagementTargetType` (or `historyTargetType`),
  /// and that is the value to use — mapping it from [kind] would guess, and
  /// a devotional entry is not a devotional series.
  final String targetType;

  bool get isEvent => kind == HistoryKind.event;
}

/// A day's worth of entries, under the heading the design gives it.
class HistoryDay {
  const HistoryDay({required this.label, required this.entries});

  /// "Today", "Yesterday", "12 June".
  final String label;

  final List<HistoryEntry> entries;
}

/// A part-watched item on the rail across the top.
class HistoryResumeItem {
  const HistoryResumeItem({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.progress,
    this.creatorVerified = false,
    this.thumbnailAsset,
    this.thumbnailUrl,
    this.isAudio = false,
  });

  final String id;
  final String title;
  final String creatorName;
  final bool creatorVerified;

  /// 0-1.
  final double progress;

  final String? thumbnailAsset;
  final String? thumbnailUrl;

  /// Audio resumes show a music note where video shows nothing.
  final bool isAudio;
}
