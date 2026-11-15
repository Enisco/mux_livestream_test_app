/// A timestamp [ago] before now, kept inside the day group it names.
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
