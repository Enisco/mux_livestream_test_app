/// What the studio dashboard is built from.
///
/// Shaped against what staging actually returns — the dashboard routes publish
/// no response schemas, so every field here was read off a live call.
library;

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
