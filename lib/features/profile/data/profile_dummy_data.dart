/// Placeholder content for the You tab.
///
/// TEMPORARY, and deliberately small. Most of this screen runs on real data —
/// the reader's name and handle come from the cached account, the studio row
/// from their creator profile. Only two things have no endpoint behind them:
///
///  * what they were last watching, and how much of it is left. There is no
///    resume-position route, and nothing records one.
///  * how many of their own events are coming up. `fetchUpcomingEvents` exists
///    but returns the whole platform's events, not the ones this reader is
///    going to, so counting it here would put a wrong number on the row.
///
/// To retire it: delete this file and fix the two import errors in
/// `profile_screen.dart`. They are the only places it is read.
abstract final class ProfileDummyData {
  /// The card under CONTINUE WATCHING. Null would hide the section entirely,
  /// which is what a reader with no history should see.
  static const lastWatched = ProfileWatchProgress(
    mediaId: 'dummy-prodigal',
    title: 'The Prodigal Returns',
    creatorName: 'Grace Community',
    creatorVerified: true,
    thumbnailAsset: 'assets/images/explore_dummy/continue_thumb.png',
    fraction: 0.67,
    remainingLabel: '24m',
  );

  /// Drives the pill on "My events".
  static const upcomingEventCount = 2;

  /// Lights the dot on the bell. There is no notifications route either, so
  /// this is the third and last invented value on the screen.
  static const hasUnreadNotifications = true;
}

class ProfileWatchProgress {
  const ProfileWatchProgress({
    required this.mediaId,
    required this.title,
    required this.creatorName,
    required this.fraction,
    required this.remainingLabel,
    this.creatorVerified = false,
    this.thumbnailAsset,
    this.thumbnailUrl,
  });

  final String mediaId;
  final String title;
  final String creatorName;
  final bool creatorVerified;

  /// How far through, 0-1 — the bar across the bottom of the still.
  final double fraction;

  /// "24m", "1h 05m" — printed before "remaining".
  final String remainingLabel;

  final String? thumbnailAsset;
  final String? thumbnailUrl;
}
