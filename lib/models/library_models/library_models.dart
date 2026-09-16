/// The reader's own records: events they said they would attend, prayers they
/// asked for, and testimonies they submitted.
///
/// Shaped for the screens rather than for any payload — none of these has a
/// route yet.
library;

/// Whether an event is still to come, and whether the reader said they are
/// going.
class MyEvent {
  const MyEvent({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.day,
    required this.month,
    required this.venue,
    required this.time,
    required this.past,
    this.creatorVerified = false,
    this.going = false,
  });

  final String id;
  final String title;
  final String creatorName;
  final bool creatorVerified;

  /// Printed verbatim on the date tile.
  final String day;
  final String month;

  final String venue;

  /// "Sat 9:00am".
  final String time;

  /// Past events are listed but offer no actions — there is nothing left to
  /// RSVP to.
  final bool past;

  final bool going;
}

/// Where a prayer request stands with the ministry it went to.
enum PrayerStatus { open, prayedFor, closed }

/// What the request was raised against — a piece of content, or the ministry
/// itself. Doubles as the filter the list offers.
enum PrayerAbout { general, audio, video, blog }

class PrayerRequest {
  const PrayerRequest({
    required this.id,
    required this.author,
    required this.about,
    required this.aboutKind,
    required this.body,
    required this.sharedAgo,
    required this.status,
    this.authorVerified = false,
  });

  final String id;
  final String author;
  final bool authorVerified;

  /// What it was asked about. Empty when [aboutKind] is
  /// [PrayerAbout.general] — there is no one thing to name.
  final String about;
  final PrayerAbout aboutKind;

  bool get aboutIsGeneral => aboutKind == PrayerAbout.general;

  final String body;

  /// "2 days ago", "5 hours ago".
  final String sharedAgo;

  final PrayerStatus status;
}

/// Whether a testimony has made it onto a ministry's wall.
enum TestimonyStatus { pending, approved, rejected }

class Testimony {
  const Testimony({
    required this.id,
    required this.author,
    required this.submittedAgo,
    required this.tags,
    required this.body,
    required this.status,
    this.authorVerified = false,
    this.wall = '',
  });

  final String id;
  final String author;
  final bool authorVerified;

  /// "3 days ago", "2 weeks ago".
  final String submittedAgo;

  /// "Healing", "Answered prayer" — the themes the reader tagged it with.
  final List<String> tags;

  final String body;
  final TestimonyStatus status;

  /// The ministry whose wall it is live on. Only meaningful once approved.
  final String wall;
}
