/// A timestamp [ago] before now, kept inside the day group it names.
///
/// The fixtures used to compute this as a plain `now - ago`, which made them
/// depend on the wall clock: run the suite shortly after midnight and "2
/// hours ago" lands in *yesterday*, which moves a row into a different day
/// heading and fails the grouping tests. (It did, at 00:03.)
///
/// So the day part of the offset is applied to the calendar day and the rest
/// is clamped into the part of that day which has already happened. "2 hours
/// ago" is always today, "1 day 2 hours ago" is always yesterday, and
/// "3 days ago" is always three dates back — whatever time the suite runs.
/// The result is never in the future, because a future `viewedAt` would make
/// `shortAge` print a negative age.
String fixtureAgo(Duration d) {
  final now = DateTime.now();
  final day = now.subtract(Duration(days: d.inDays));
  final at = day.subtract(
    Duration(minutes: d.inMinutes % Duration.minutesPerDay),
  );
  final midnight = DateTime(day.year, day.month, day.day);
  final kept = at.isBefore(midnight)
      ? midnight.add(const Duration(minutes: 1))
      : at;
  return kept.toUtc().toIso8601String();
}
