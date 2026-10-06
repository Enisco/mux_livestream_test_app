/// What the You tab's CONTINUE WATCHING card draws.
///
/// Built from the first part-watched row of the reader's history, which
/// already carries how far in they got and how long the thing runs.
library;

import 'package:test_app/models/history_models/history_models.dart';

class ProfileWatchProgress {
  const ProfileWatchProgress({
    required this.mediaId,
    required this.title,
    required this.creatorName,
    required this.fraction,
    required this.remainingLabel,
    this.creatorVerified = false,
    this.thumbnailAsset,
    this.thumbnailUrl,
  });

  final String mediaId;
  final String title;
  final String creatorName;
  final bool creatorVerified;

  /// How far through, 0-1 — the bar across the bottom of the still.
  final double fraction;

  /// "24m", "1h 05m" — printed before "remaining".
  final String remainingLabel;

  final String? thumbnailAsset;
  final String? thumbnailUrl;
}

/// "24m remaining" — what is left of a part-watched row.
///
/// Derived from the runtime on the still and how far in the reader got; a row
/// with no runtime has nothing to subtract from and says nothing.
String remainingOf(HistoryEntry row) {
  final clock = row.duration;
  final fraction = row.progress;
  if (clock == null || fraction == null) return '';
  final parts = clock.split(':').map(int.tryParse).toList();
  if (parts.any((p) => p == null)) return '';
  final total = parts.length == 3
      ? Duration(hours: parts[0]!, minutes: parts[1]!, seconds: parts[2]!)
      : Duration(minutes: parts[0]!, seconds: parts[1]!);
  final left = total * (1 - fraction);
  if (left.inMinutes < 1) return '';
  if (left.inMinutes < 60) return '${left.inMinutes}m';
  return '${left.inHours}h ${(left.inMinutes % 60).toString().padLeft(2, '0')}m';
}
