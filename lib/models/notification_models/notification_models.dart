/// What the notification service sends, and what the bell reads.
library;

/// One notification, as `POST /v1/notification/search` returns it.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.actionUrl,
    this.readAt,
  });

  final String id;

  /// `CREATOR_ONBOARDED`, `FILE_UPLOAD_COMPLETE`, `WELCOME`, … — screaming
  /// snake case, and the same value as `templateKey`. It picks the row's
  /// glyph; an unknown type gets a neutral one rather than being dropped.
  final String type;

  final String title;
  final String body;

  /// Where tapping the row should land. Null on every row staging sends
  /// today, so a row without one simply marks itself read.
  final String? actionUrl;

  /// Null until the row is read. The server has no unread filter and no
  /// count, so this is what the bell's dot is computed from.
  final DateTime? readAt;

  final DateTime createdAt;

  bool get isUnread => readAt == null;

  AppNotification markedRead(DateTime at) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    actionUrl: actionUrl,
    readAt: readAt ?? at,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? json['templateKey'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        actionUrl: (json['actionUrl'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['actionUrl'] as String,
        readAt: DateTime.tryParse(json['readAt'] as String? ?? ''),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// One page of the bell's list.
class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.total,
    this.nextPage,
  });

  final List<AppNotification> items;

  /// What the server says there are in all, across every page.
  final int total;

  final int? nextPage;

  bool get isEmpty => items.isEmpty;
}

/// The notification preferences, as `GET /v1/notification/preferences`
/// returns them.
class NotificationPrefs {
  const NotificationPrefs({
    this.email = true,
    this.push = true,
    this.inApp = true,
    this.eventReminders = true,
    this.eventReminderMinutes,
  });

  final bool email;
  final bool push;
  final bool inApp;

  final bool eventReminders;

  /// One of [reminderOffsets], or null for the organiser's own schedule.
  final int? eventReminderMinutes;

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) =>
      NotificationPrefs(
        email: json['emailEnabled'] as bool? ?? true,
        push: json['pushEnabled'] as bool? ?? true,
        inApp: json['inAppEnabled'] as bool? ?? true,
        eventReminders: json['eventRemindersEnabled'] as bool? ?? true,
        eventReminderMinutes: (json['eventReminderMinutes'] as num?)?.toInt(),
      );
}

/// The lead times the platform accepts — **five values, not four**.
const reminderOffsets = <int>[15, 30, 60, 120, 1440];

/// "15 minutes before", "2 hours before", "1 day before".
String reminderOffsetLabel(int minutes) {
  if (minutes < 60) return '$minutes minutes before';
  if (minutes == 60) return '1 hour before';
  if (minutes < 1440) return '${minutes ~/ 60} hours before';
  final days = minutes ~/ 1440;
  return days == 1 ? '1 day before' : '$days days before';
}
