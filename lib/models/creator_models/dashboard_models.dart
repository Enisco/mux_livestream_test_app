/// What the studio dashboard is built from.
///
/// Shaped against what staging actually returns — the dashboard routes publish
/// no response schemas, so every field here was read off a live call.
library;

/// Who the reader is in this studio, and what they may do in it.
///
/// What a creator has used of their plan, from
/// `GET /v1/creator/{creatorId}/settings/plan`.
///
/// **The upload window is a rolling 30 days, not a calendar month**, because
/// that is the window the upload guard itself uses — if the screen and the
/// guard disagreed, a creator would be blocked at a moment the screen could
/// not explain. So there is no reset instant: the oldest upload simply ages
/// out. `limit: null` is **unlimited**, not zero.
class PlanUsage {
  const PlanUsage({
    this.uploadsUsed = 0,
    this.uploadLimit,
    this.windowDays = 30,
    this.storageUsedBytes = 0,
    this.storageLimitBytes,
  });

  final int uploadsUsed;

  /// Null means unlimited.
  final int? uploadLimit;

  final int windowDays;
  final int storageUsedBytes;
  final int? storageLimitBytes;

  bool get hasUploadLimit => uploadLimit != null;

  int get uploadsLeft {
    final limit = uploadLimit;
    if (limit == null) return 0;
    final left = limit - uploadsUsed;
    return left < 0 ? 0 : left;
  }

  bool get uploadsExhausted => hasUploadLimit && uploadsLeft == 0;

  factory PlanUsage.fromJson(Map<String, dynamic> json) {
    final usage = (json['usage'] as Map<String, dynamic>?) ?? const {};
    final uploads = (usage['uploads'] as Map<String, dynamic>?) ?? const {};
    final storage = (usage['storage'] as Map<String, dynamic>?) ?? const {};
    return PlanUsage(
      uploadsUsed: (uploads['usedInWindow'] as num?)?.toInt() ?? 0,
      uploadLimit: (uploads['limit'] as num?)?.toInt(),
      windowDays: (uploads['windowDays'] as num?)?.toInt() ?? 30,
      storageUsedBytes: (storage['usedBytes'] as num?)?.toInt() ?? 0,
      storageLimitBytes: (storage['limitBytes'] as num?)?.toInt(),
    );
  }
}

/// A studio the reader can work in, from `GET /v1/creator/me/memberships`.
///
/// Answers both ways access happens: the creator they **own**, and the
/// organisations they were **added to**. Owned studios come first, and a user
/// who both owns a studio and holds a member row in it is listed once —
/// ownership is the stronger claim.
class StudioMembership {
  const StudioMembership({
    required this.creatorId,
    required this.displayName,
    required this.handle,
    required this.role,
    this.avatarKey,
    this.type = '',
    this.isVerified = false,
    this.isPrincipalOwner = false,
  });

  final String creatorId;
  final String displayName;
  final String handle;

  /// `owner`, `admin`, `editor` or `viewer`.
  final String role;

  final String? avatarKey;
  final String type;
  final bool isVerified;
  final bool isPrincipalOwner;

  factory StudioMembership.fromJson(Map<String, dynamic> json) =>
      StudioMembership(
        creatorId: json['creatorId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        handle: json['handle'] as String? ?? '',
        role: json['role'] as String? ?? '',
        avatarKey: json['avatarKey'] as String?,
        type: json['type'] as String? ?? '',
        isVerified: json['isVerified'] as bool? ?? false,
        isPrincipalOwner: json['isPrincipalOwner'] as bool? ?? false,
      );
}

/// Who the reader is in this studio, and what they may do in it.
///
/// The capabilities gate the Create sheet: a member who cannot create a
/// livestream should not be offered one.
class DashboardContext {
  const DashboardContext({
    required this.creatorId,
    required this.displayName,
    required this.handle,
    required this.role,
    required this.capabilities,
    this.avatarKey,
    this.isPrincipalOwner = false,
    this.analyticsWindowDays = 7,
  });

  factory DashboardContext.fromJson(Map<String, dynamic> json) {
    final creator = (json['creator'] as Map<String, dynamic>?) ?? const {};
    final membership =
        (json['membership'] as Map<String, dynamic>?) ?? const {};
    final limits = (json['limits'] as Map<String, dynamic>?) ?? const {};
    final caps = (json['capabilities'] as Map<String, dynamic>?) ?? const {};
    return DashboardContext(
      creatorId: creator['id'] as String? ?? '',
      displayName: creator['displayName'] as String? ?? '',
      handle: creator['handle'] as String? ?? '',
      avatarKey: creator['avatarKey'] as String?,
      role: membership['role'] as String? ?? '',
      isPrincipalOwner: membership['isPrincipalOwner'] as bool? ?? false,
      capabilities: {
        for (final entry in caps.entries)
          if (entry.value is bool) entry.key: entry.value as bool,
      },
      analyticsWindowDays: limits['analyticsWindowDays'] as int? ?? 7,
    );
  }

  final String creatorId;
  final String displayName;
  final String handle;
  final String? avatarKey;

  /// "owner", "streamer", …
  final String role;
  final bool isPrincipalOwner;

  /// `canCreateMedia`, `canCreateLivestream`, `canManageGiving`, …
  final Map<String, bool> capabilities;

  /// How far back the plan lets analytics reach.
  final int analyticsWindowDays;

  /// Stand in for a context the dashboard refused.
  ///
  /// `dashboard/context` answers **403 Insufficient dashboard permissions**
  /// for a `streamer`, who is nevertheless a member of that studio and sees
  /// it in `me/memberships`. Without this the studio pill has nothing to
  /// name, so the switcher cannot be opened — and the reader stuck in a
  /// studio they cannot use is exactly the one who needs it.
  ///
  /// **No capabilities**, deliberately: they are unknown, and an empty map
  /// offers nothing rather than offering something the routes will refuse.
  factory DashboardContext.fromMembership(StudioMembership studio) =>
      DashboardContext(
        creatorId: studio.creatorId,
        displayName: studio.displayName,
        handle: studio.handle,
        role: studio.role,
        avatarKey: studio.avatarKey,
        isPrincipalOwner: studio.isPrincipalOwner,
        capabilities: const {},
      );

  bool can(String capability) => capabilities[capability] ?? false;

  /// The first name, for the greeting.
  String get firstName {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.last;
  }
}

/// One line of the "here's how to start" card.
///
/// The server sends keys and completion only — no copy — so the words live in
/// `AppStrings` and a key it does not know is skipped rather than shown raw.
class GettingStartedStep {
  const GettingStartedStep({
    required this.key,
    required this.complete,
    required this.applicable,
    this.blocking = false,
  });

  factory GettingStartedStep.fromJson(Map<String, dynamic> json) =>
      GettingStartedStep(
        key: json['key'] as String? ?? '',
        complete: json['complete'] as bool? ?? false,
        applicable: json['applicable'] as bool? ?? true,
        blocking: json['blocking'] as bool? ?? false,
      );

  final String key;
  final bool complete;

  /// A step that does not apply to this studio — inviting a team into a
  /// personal channel, say — is not shown at all.
  final bool applicable;

  final bool blocking;
}

/// Something waiting on the reader: prayer requests, testimonies to review.
class AttentionItem {
  const AttentionItem({
    required this.key,
    required this.count,
    this.label = '',
  });

  factory AttentionItem.fromJson(Map<String, dynamic> json) => AttentionItem(
    key: json['key'] as String? ?? json['type'] as String? ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
    label: json['label'] as String? ?? '',
  );

  final String key;
  final int count;

  /// Only some responses carry their own wording; otherwise the client names
  /// the row from [key].
  final String label;
}

/// One number on the TODAY card, with how it moved.
class Metric {
  const Metric({required this.value, this.previousValue, this.changePercent});

  factory Metric.fromJson(Map<String, dynamic>? json) => Metric(
    value: (json?['value'] as num?)?.toDouble() ?? 0,
    previousValue: (json?['previousValue'] as num?)?.toDouble(),
    changePercent: (json?['changePercent'] as num?)?.toDouble(),
  );

  final double value;
  final double? previousValue;

  /// Null when there is nothing to compare against — a new studio, or a
  /// previous window of zero.
  final double? changePercent;

  /// How much it moved in absolute terms, for the metrics the design shows as
  /// "+9" rather than as a percentage.
  double? get delta => previousValue == null ? null : value - previousValue!;
}

class DashboardPerformance {
  const DashboardPerformance({
    required this.views,
    required this.subscribersGained,
    required this.uniqueViewers,
    this.dataThrough,
  });

  factory DashboardPerformance.fromJson(Map<String, dynamic> json) {
    final metrics = (json['metrics'] as Map<String, dynamic>?) ?? const {};
    Metric read(String key) =>
        Metric.fromJson(metrics[key] as Map<String, dynamic>?);
    return DashboardPerformance(
      views: read('totalViews'),
      subscribersGained: read('subscribersGained'),
      uniqueViewers: read('uniqueViewers'),
      dataThrough: DateTime.tryParse(json['dataThrough'] as String? ?? ''),
    );
  }

  static const empty = DashboardPerformance(
    views: Metric(value: 0),
    subscribersGained: Metric(value: 0),
    uniqueViewers: Metric(value: 0),
  );

  final Metric views;
  final Metric subscribersGained;
  final Metric uniqueViewers;
  final DateTime? dataThrough;
}
