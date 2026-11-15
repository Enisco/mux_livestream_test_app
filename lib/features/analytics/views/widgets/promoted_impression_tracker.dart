import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/shared/services/analytics_service.dart';

/// Watches a feed card and reports it as seen.
class PromotedImpressionTracker extends StatefulWidget {
  const PromotedImpressionTracker({
    super.key,
    required this.promotion,
    required this.mediaId,
    required this.creatorId,
    required this.source,
    required this.child,
    this.contentType,
    this.mediaType,
    this.enabled = true,
    this.minVisibleFraction = 0.5,
    this.dwell = const Duration(milliseconds: 1500),
  });

  final PromotionAttribution? promotion;
  final String mediaId;
  final String creatorId;

  /// Set for non-media rows, which are targeted by `contentType` + `contentId`
  /// rather than `mediaId`.
  final String? contentType;
  final String? mediaType;
  final String source;

  final bool enabled;

  final double minVisibleFraction;
  final Duration dwell;
  final Widget child;

  @override
  State<PromotedImpressionTracker> createState() =>
      _PromotedImpressionTrackerState();
}

class _PromotedImpressionTrackerState extends State<PromotedImpressionTracker> {
  Timer? _dwell;
  DateTime? _visibleSince;
  bool _qualified = false;
  bool _seen = false;

  bool get _wantsAnything =>
      widget.enabled && (!_seen || (widget.promotion != null && !_qualified));

  @override
  void didUpdateWidget(PromotedImpressionTracker old) {
    super.didUpdateWidget(old);
    // List rows are recycled: a new target means a fresh chance to be seen.
    if (widget.mediaId != old.mediaId) {
      _seen = false;
      _qualified = false;
      _cancel();
    } else if (widget.promotion?.deliveryKey != old.promotion?.deliveryKey) {
      _qualified = false;
    }
    if (!widget.enabled) _cancel();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    _dwell?.cancel();
    _dwell = null;
    _visibleSince = null;
  }

  void _onVisibility(VisibilityInfo info) {
    if (!mounted) return;

    final visible = info.visibleFraction >= widget.minVisibleFraction;
    if (!visible || !_wantsAnything) {
      _cancel();
      return;
    }
    // Already counting down for this stretch of visibility.
    if (_dwell != null) return;

    _visibleSince = DateTime.now();
    _dwell = Timer(widget.dwell, _report);
  }

  void _report() {
    _dwell = null;
    if (!mounted || !_wantsAnything) return;
    // A card that was on screen while the app was backgrounded was not
    // actually seen by anyone.
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      _visibleSince = null;
      return;
    }

    final since = _visibleSince;
    final visibleMs = since == null
        ? widget.dwell.inMilliseconds
        : DateTime.now().difference(since).inMilliseconds;

    final analytics = GetIt.instance<AnalyticsService>();

    if (!_seen) {
      _seen = true;
      analytics.trackImpression(
        mediaId: widget.mediaId,
        creatorId: widget.creatorId,
        contentType: widget.contentType,
        mediaType: widget.mediaType,
        source: widget.source,
      );
    }

    // A promoted card is billed separately, and only when the server issued
    // attribution for it.
    final promotion = widget.promotion;
    if (promotion != null && !_qualified) {
      _qualified = true;
      analytics.trackPromotedQualifiedImpression(
        mediaId: widget.mediaId,
        creatorId: widget.creatorId,
        mediaType: widget.mediaType,
        source: widget.source,
        promotion: promotion,
        visibleDurationMs: visibleMs,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return VisibilityDetector(
      key: Key('impression-${widget.mediaId}'),
      onVisibilityChanged: _onVisibility,
      child: widget.child,
    );
  }
}
