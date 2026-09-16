import 'package:test_app/models/history_models/history_models.dart';

/// Placeholder rows for the Liked and Saved libraries.
///
/// TEMPORARY. Both lists reuse [HistoryEntry] because the design draws the
/// same row on all three screens, so when the routes arrive one mapper feeds
/// all of them.
///
/// Nothing backs these yet. `POST /v1/engagement/interactions` records a like
/// or a favourite — that is how the feed's heart and bookmark already work —
/// but the spec has no route that lists a reader's own interactions back, so
/// neither library can be filled. That listing route is the one to ask for.
///
/// To retire this: delete the file and fix the import errors in
/// `liked_screen.dart` and `saved_screen.dart`.
abstract final class LibraryDummyData {
  static const _art = 'assets/images/explore_dummy';

  static const _today = <HistoryEntry>[
    HistoryEntry(
      id: 'l1',
      kind: HistoryKind.library,
      title: 'Romans, chapter',
      creatorName: 'Grace Community',
      creatorVerified: true,
      thumbnailAsset: '$_art/live_thumb.png',
      count: 12000,
      age: '6d',
      progress: 0.28,
    ),
    HistoryEntry(
      id: 'l2',
      kind: HistoryKind.audio,
      title: 'Romans, chapter by chapter',
      creatorName: 'Grace Community',
      creatorVerified: true,
      thumbnailAsset: '$_art/trending_thumb.png',
      count: 10,
      age: '6d',
      duration: '00:25',
    ),
  ];

  static const _yesterday = <HistoryEntry>[
    HistoryEntry(
      id: 'l3',
      kind: HistoryKind.video,
      title: 'Romans, chapter',
      creatorName: 'Grace Community',
      creatorVerified: true,
      thumbnailAsset: '$_art/continue_thumb.png',
      count: 12000,
      age: '6d',
    ),
    HistoryEntry(
      id: 'l4',
      kind: HistoryKind.event,
      title: 'Youth Conference',
      creatorName: 'Grace Community',
      creatorVerified: true,
      thumbnailAsset: '$_art/hero_backdrop.png',
      age: '6d',
      eventDate: '12 June 2026',
      eventVenue: 'River Worship',
      eventTime: '9am',
    ),
    HistoryEntry(
      id: 'l5',
      kind: HistoryKind.devotional,
      title: '14 Days Of Worship',
      creatorName: 'Grace Community',
      creatorVerified: true,
      thumbnailAsset: '$_art/poster_thumb.png',
      count: 12,
      age: '6d',
    ),
    HistoryEntry(
      id: 'l6',
      kind: HistoryKind.blog,
      title: 'Why we still gather: the case for the local church',
      creatorName: 'Grace Community',
      creatorVerified: true,
      thumbnailAsset: '$_art/poster_thumb.png',
      count: 12,
      age: '6d',
    ),
    HistoryEntry(
      id: 'l7',
      kind: HistoryKind.video,
      title: 'Sunday Worship',
      creatorName: 'Grace Community',
      creatorVerified: true,
      thumbnailAsset: '$_art/continue_thumb.png',
      count: 12000,
      age: '6d ago',
      duration: '00:25',
    ),
  ];

  static const _thisWeek = <HistoryEntry>[
    HistoryEntry(
      id: 'l8',
      kind: HistoryKind.video,
      title: 'Romans, chapter',
      creatorName: 'Grace Community',
      creatorVerified: true,
      thumbnailAsset: '$_art/live_thumb.png',
      count: 12000,
      age: '6d',
    ),
    HistoryEntry(
      id: 'l9',
      kind: HistoryKind.event,
      title: 'Youth Conference',
      creatorName: 'Grace Community',
      creatorVerified: true,
      thumbnailAsset: '$_art/hero_backdrop.png',
      age: '6d',
      eventDate: '12 June 2026',
      eventVenue: 'River Worship',
      eventTime: '9am',
    ),
    HistoryEntry(
      id: 'l10',
      kind: HistoryKind.devotional,
      title: '14 Days Of Worship',
      creatorName: 'Grace Community',
      creatorVerified: true,
      thumbnailAsset: '$_art/poster_thumb.png',
      count: 12,
      age: '6d',
    ),
  ];

  static const liked = <HistoryDay>[
    HistoryDay(label: 'Today', entries: _today),
    HistoryDay(label: 'Yesterday', entries: _yesterday),
    HistoryDay(label: 'This Week', entries: _thisWeek),
  ];

  /// The count the design prints above the list, which is the whole library
  /// rather than the handful of rows shown.
  static const likedTotal = 173;

  static const saved = <HistoryDay>[
    HistoryDay(label: 'Today', entries: _today),
    HistoryDay(label: 'Yesterday', entries: _yesterday),
    HistoryDay(label: 'This Week', entries: _thisWeek),
  ];

  static const savedTotal = 12;
}
