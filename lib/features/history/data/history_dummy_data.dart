import 'package:test_app/models/history_models/history_models.dart';

/// Placeholder content for the History screen.
///
/// TEMPORARY. Nothing on this screen has an endpoint behind it yet:
///
///  * the day-grouped list has no route at all — the staging spec carries 313
///    paths and none of them is a viewing history.
///  * the resume rail is closer. `GET /v1/analytics/viewer/continue-watching`
///    exists (`creatorId`, `mediaId`, `limit`, `maxAgeDays`), but the spec
///    publishes no response schema for it and it is auth-gated, so its shape
///    could not be read. That route is the one to wire first — it would also
///    replace the invented card on the You tab.
///
/// To retire it: delete this file and fix the import errors in
/// `history_screen.dart`. It is read nowhere else.
abstract final class HistoryDummyData {
  static const _art = 'assets/images/explore_dummy';

  static const resume = <HistoryResumeItem>[
    HistoryResumeItem(
      id: 'r1',
      title: 'The Power of Persistent Prayer',
      creatorName: 'Grace Community',
      creatorVerified: true,
      thumbnailAsset: '$_art/live_thumb.png',
      progress: 0.59,
    ),
    HistoryResumeItem(
      id: 'r2',
      title: 'Songs for the Journey',
      creatorName: 'Grace Community',
      creatorVerified: true,
      thumbnailAsset: '$_art/trending_thumb.png',
      progress: 0.23,
      isAudio: true,
    ),
    HistoryResumeItem(
      id: 'r3',
      title: 'Anchored in Hope',
      creatorName: 'Horizon Fellowship',
      creatorVerified: true,
      thumbnailAsset: '$_art/continue_thumb.png',
      progress: 0.81,
    ),
  ];

  static const days = <HistoryDay>[
    HistoryDay(
      label: 'Today',
      entries: [
        HistoryEntry(
          id: 'h1',
          kind: HistoryKind.library,
          title: 'Romans, chapter',
          creatorName: 'Grace Community',
          creatorVerified: true,
          thumbnailAsset: '$_art/live_thumb.png',
          count: 12000,
          age: '6d',
          progress: 0.32,
        ),
        HistoryEntry(
          id: 'h2',
          kind: HistoryKind.video,
          title: 'Sunday Worship',
          creatorName: 'Grace Community',
          creatorVerified: true,
          thumbnailAsset: '$_art/continue_thumb.png',
          count: 12000,
          age: '6d ago',
          duration: '00:25',
        ),
      ],
    ),
    HistoryDay(
      label: 'Yesterday',
      entries: [
        HistoryEntry(
          id: 'h3',
          kind: HistoryKind.audio,
          title: 'Romans, chapter by chapter',
          creatorName: 'Grace Community',
          creatorVerified: true,
          thumbnailAsset: '$_art/trending_thumb.png',
          count: 10,
          age: '6d',
          duration: '00:25',
        ),
        HistoryEntry(
          id: 'h4',
          kind: HistoryKind.devotional,
          title: '14 Days Of Worship',
          creatorName: 'Grace Community',
          creatorVerified: true,
          thumbnailAsset: '$_art/poster_thumb.png',
          count: 12,
          age: '6d',
        ),
        HistoryEntry(
          id: 'h5',
          kind: HistoryKind.blog,
          title: 'Why we still gather: the case for the local church',
          creatorName: 'Grace Community',
          creatorVerified: true,
          thumbnailAsset: '$_art/poster_thumb.png',
          count: 12,
          age: '6d',
        ),
      ],
    ),
    HistoryDay(
      label: '12 June',
      entries: [
        HistoryEntry(
          id: 'h6',
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
          id: 'h7',
          kind: HistoryKind.video,
          title: 'When Mountains Move',
          creatorName: 'Horizon Fellowship',
          creatorVerified: true,
          thumbnailAsset: '$_art/live_thumb.png',
          count: 8400,
          age: '1w ago',
          duration: '18:42',
        ),
      ],
    ),
  ];

  /// Flipped to true by nothing yet — it is here so the empty state can be
  /// reviewed without deleting the rows above.
  static const isEmpty = false;
}
