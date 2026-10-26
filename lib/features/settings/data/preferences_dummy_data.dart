/// What the topics screen reads out.
///
/// TEMPORARY. Topics could be real — `GET /v1/user/categories` lists them and
/// `PATCH /v1/user/me/viewer-preferences` stores a choice — but neither
/// publishes a schema, so the shapes below stand in until one does.
///
/// **The reminder half of this file is gone**: `/v1/notification/preferences`
/// gained `eventRemindersEnabled` and `eventReminderMinutes` on 2026-10-26,
/// so the lead times and their label live with the contract now, as
/// `reminderOffsets` and `reminderOffsetLabel` in `notification_models.dart`.
/// Keeping a second copy here meant a screen and a test could agree with each
/// other while both disagreed with the server — and the copy had four offsets
/// where the platform accepts five.
///
/// To retire the rest: delete the file and fix the import errors in
/// `topics_sheet.dart`.
abstract final class PreferencesDummyData {
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
