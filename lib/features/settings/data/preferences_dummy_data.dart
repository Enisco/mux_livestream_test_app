/// What the topics screen reads out.
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
