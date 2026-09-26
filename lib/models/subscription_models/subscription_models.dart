/// A ministry the reader follows, and how loudly it is allowed to speak.
library;

import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';
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

  /// The API keeps four independent switches rather than one level, so the
  /// sheet's four choices are the four combinations that matter.
  Map<String, bool> toFlags() => {
    'notifyOnUpload': this == all || this == personalized,
    'notifyOnPost': this == all,
    'notifyOnEvent': this == all,
    'notifyOnLive': this != none,
  };

  /// Reads the flags back. Anything that is not one of the four shapes above
  /// is closest to `personalized`, which is also the server's default.
  static NotifyLevel fromFlags({
    required bool upload,
    required bool post,
    required bool event,
    required bool live,
  }) {
    if (!live && !upload && !post && !event) return none;
    if (upload && post && event && live) return all;
    if (live && !upload && !post && !event) return NotifyLevel.live;
    return personalized;
  }
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
    this.avatarUrl,
  });

  /// One row of `GET /v1/discovery/following-creators`.
  ///
  /// `isLive` is **not** in this payload and is not guessed from it — the
  /// screen fills it in from the live feed. A hardcoded `true` is exactly
  /// what made ministries look like they were broadcasting when they were
  /// not.
  factory FollowedMinistry.fromJson(
    Map<String, dynamic> json, {
    bool isLive = false,
  }) {
    final handle = json['handle'] as String? ?? '';
    return FollowedMinistry(
      id: json['creatorId'] as String? ?? '',
      name: json['displayName'] as String? ?? '',
      handle: handle.startsWith('@') ? handle : '@$handle',
      lastActivity: describeActivity(
        DateTime.tryParse(json['latestContentAt'] as String? ?? ''),
        isLive: isLive,
      ),
      verified: json['isVerified'] as bool? ?? json['verifiedAt'] != null,
      isLive: isLive,
      avatarUrl: AssetUrlResolver.resolve(json['avatarKey'] as String?),
      notify: NotifyLevel.fromFlags(
        upload: json['notifyOnUpload'] as bool? ?? false,
        post: json['notifyOnPost'] as bool? ?? false,
        event: json['notifyOnEvent'] as bool? ?? false,
        live: json['notifyOnLive'] as bool? ?? false,
      ),
    );
  }

  /// "Live now" while broadcasting, otherwise when they last published.
  static String describeActivity(DateTime? at, {bool isLive = false}) {
    if (isLive) return AppStrings.followingLiveNow;
    if (at == null) return AppStrings.followingNoPostsYet;
    final delta = DateTime.now().difference(at);
    final ago = switch (delta) {
      _ when delta.inHours < 1 => '${delta.inMinutes.clamp(1, 59)}m',
      _ when delta.inDays < 1 => '${delta.inHours}h',
      _ when delta.inDays < 7 => '${delta.inDays}d',
      _ when delta.inDays < 365 => '${(delta.inDays / 7).floor()}w',
      _ => '${(delta.inDays / 365).floor()}y',
    };
    return AppStrings.followingPostedAgo(ago);
  }

  final String id;
  final String name;

  /// "@cynthiamorgan".
  final String handle;

  /// "Live now", "1 hour ago" — the design prints one or the other after the
  /// handle.
  final String lastActivity;

  final bool verified;
  final bool isLive;

  final String? avatarUrl;

  final NotifyLevel notify;

  FollowedMinistry withNotify(NotifyLevel level) => copyWith(notify: level);

  FollowedMinistry copyWith({NotifyLevel? notify, bool? isLive}) =>
      FollowedMinistry(
        id: id,
        name: name,
        handle: handle,
        lastActivity: isLive == null
            ? lastActivity
            : (isLive ? AppStrings.followingLiveNow : lastActivity),
        verified: verified,
        isLive: isLive ?? this.isLive,
        avatarUrl: avatarUrl,
        notify: notify ?? this.notify,
      );
}

/// A ministry the reader does not follow yet, offered on the empty feed.
class SuggestedMinistry {
  const SuggestedMinistry({
    required this.id,
    required this.name,
    required this.handle,
    this.verified = false,
    this.avatarUrl,
  });

  /// From `GET /v1/discovery/recommended-creators`, which is what the home
  /// feed's Following empty state already offers.
  factory SuggestedMinistry.fromRecommended(RecommendedCreator c) =>
      SuggestedMinistry(
        id: c.creatorId,
        name: c.displayName,
        handle: c.handle.startsWith('@') ? c.handle : '@${c.handle}',
        verified: c.isVerified,
        avatarUrl: AssetUrlResolver.resolve(c.avatarKey),
      );

  final String? avatarUrl;

  final String id;
  final String name;
  final String handle;
  final bool verified;
}
