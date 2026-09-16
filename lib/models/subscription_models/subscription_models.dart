/// A ministry the reader follows, and how loudly it is allowed to speak.
library;

import 'package:test_app/utils/app_constants/app_strings.dart';

/// How much a followed ministry may notify about.
enum NotifyLevel {
  all(AppStrings.notifyAll, AppStrings.notifyAllBody),
  personalized(
    AppStrings.notifyPersonalized,
    AppStrings.notifyPersonalizedBody,
  ),
  live(AppStrings.notifyLive, AppStrings.notifyLiveBody),
  none(AppStrings.notifyNone, AppStrings.notifyNoneBody);

  const NotifyLevel(this.label, this.body);

  final String label;

  /// The line under the label in the sheet, saying what it actually means.
  final String body;
}

class FollowedMinistry {
  const FollowedMinistry({
    required this.id,
    required this.name,
    required this.handle,
    required this.lastActivity,
    this.verified = false,
    this.isLive = false,
    this.notify = NotifyLevel.personalized,
  });

  final String id;
  final String name;

  /// "@cynthiamorgan".
  final String handle;

  /// "Live now", "1 hour ago" — the design prints one or the other after the
  /// handle.
  final String lastActivity;

  final bool verified;
  final bool isLive;

  final NotifyLevel notify;

  FollowedMinistry withNotify(NotifyLevel level) => FollowedMinistry(
    id: id,
    name: name,
    handle: handle,
    lastActivity: lastActivity,
    verified: verified,
    isLive: isLive,
    notify: level,
  );
}

/// A ministry the reader does not follow yet, offered on the empty feed.
class SuggestedMinistry {
  const SuggestedMinistry({
    required this.id,
    required this.name,
    required this.handle,
    this.verified = false,
  });

  final String id;
  final String name;
  final String handle;
  final bool verified;
}
