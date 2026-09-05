/// What the reminder and topic screens read out.
///
/// TEMPORARY, and unevenly so:
///
///  * **Topics** could be real. `GET /v1/user/categories` lists them and
///    `PATCH /v1/user/me/viewer-preferences` stores a choice. Neither
///    publishes a schema, so the shapes below stand in until one does.
///  * **Reminders** have no route at all. Nothing in the spec stores a lead
///    time, or says whether reminders are on.
///
/// To retire this: delete the file and fix the import errors in
/// `event_reminders_screen.dart` and `topics_sheet.dart`.
abstract final class PreferencesDummyData {
  static const remindersOn = true;

  /// The lead times the design offers, in minutes.
  static const leadTimes = <int>[15, 30, 60, 1440];

  /// Which one an account starts on — the design marks it "Default".
  static const defaultLeadMinutes = 60;
  static const selectedLeadMinutes = 60;

  /// Topics in the order they are shown, with whether each is followed.
  /// Order matters: the design lets the reader drag them.
  static const topics = <(String, bool)>[
    ('Worship', true),
    ('Preaching', true),
    ('Bible study', true),
    ('Youth', true),
    ('Gospel Music & Worship', false),
    ('Marriage & Family', false),
    ('Faith & Finances', false),
    ('Healing & Deliverance', false),
    ('Prayer & Spiritual Growth', false),
  ];
}

/// How a lead time reads on the row: "15 minutes before", "1 hour before".
String leadTimeLabel(int minutes) {
  if (minutes < 60) return '$minutes minutes before';
  if (minutes == 60) return '1 hour before';
  if (minutes < 1440) return '${minutes ~/ 60} hours before';
  final days = minutes ~/ 1440;
  return days == 1 ? '1 day before' : '$days days before';
}
