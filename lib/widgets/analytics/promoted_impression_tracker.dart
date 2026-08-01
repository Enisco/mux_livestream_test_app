import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../features/analytics/models/analytics_models.dart';
import '../../services/analytics_service.dart';

/// Wraps a promoted placement and emits exactly one
/// `promoted_qualified_impression` once the unit has been meaningfully visible
/// for the dwell window.
///
/// Qualification mirrors the web client: at least [minVisibleFraction] of the
/// unit on screen for a continuous [dwell]. Scrolling the unit away resets the
/// window — a glance is not an impression.
///
/// Dwell only accrues while the app is foregrounded, so a card left on screen
/// under a backgrounded app never qualifies.
///
/// Wrapping an organic item is a no-op: without server-issued attribution there
/// is nothing to bill, and the client never invents any.
class PromotedImpressionTracker extends StatefulWidget {
  const PromotedImpressionTracker({
    super.key,
    required this.promotion,
    required this.mediaId,
    required this.creatorId,
    required this.source,
    required this.child,
    this.mediaType,
    this.enabled = true,
    this.minVisibleFraction = 0.5,
    this.dwell = const Duration(milliseconds: 1500),
  });

  /// Null for organic items — the tracker then does nothing at all.
  final PromotionAttribution? promotion;
  final String mediaId;
  final String creatorId;
  final String? mediaType;
  final String source;

  /// Extra gate from the host surface, e.g. "this is the active page of the
  /// vertical feed". Geometry alone can't express that.
  final bool enabled;

  final double minVisibleFraction;
  final Duration dwell;
  final Widget child;

  @override
  State<PromotedImpressionTracker> createState() =>
      _PromotedImpressionTrackerState();
}

class _PromotedImpressionTrackerState extends State<PromotedImpressionTracker> {
  static const _tick = Duration(milliseconds: 200);

  Timer? _ticker;
  Duration _visibleFor = Duration.zero;
  bool _qualified = false;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(PromotedImpressionTracker old) {
    super.didUpdateWidget(old);
    if (widget.promotion?.deliveryKey != old.promotion?.deliveryKey) {
      _qualified = false;
      _visibleFor = Duration.zero;
    }
    if (!widget.enabled) _visibleFor = Duration.zero;
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    final shouldRun = widget.promotion != null && widget.enabled && !_qualified;
    if (shouldRun) {
      // Cheap by construction: only promoted units ever poll, and each one
      // stops the moment it qualifies.
      _ticker ??= Timer.periodic(_tick, (_) => _onTick());
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _onTick() {
    if (!mounted || _qualified) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      _visibleFor = Duration.zero;
      return;
    }
    if (_visibleFraction() < widget.minVisibleFraction) {
      _visibleFor = Duration.zero;
      return;
    }
    _visibleFor += _tick;
    if (_visibleFor < widget.dwell) return;

    _qualified = true;
    _syncTicker();
    GetIt.instance<AnalyticsService>().trackPromotedQualifiedImpression(
      mediaId: widget.mediaId,
      creatorId: widget.creatorId,
      mediaType: widget.mediaType,
      source: widget.source,
      promotion: widget.promotion!,
      visibleDurationMs: _visibleFor.inMilliseconds,
    );
  }

  /// Fraction of this widget's box that intersects the view, 0 when it is not
  /// laid out, not attached, or fully off-screen.
  double _visibleFraction() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return 0;
    if (!renderObject.attached || !renderObject.hasSize) return 0;

    final size = renderObject.size;
    final area = size.width * size.height;
    if (area <= 0) return 0;

    final Rect bounds;
    try {
      bounds = renderObject.localToGlobal(Offset.zero) & size;
    } catch (_) {
      // Not currently painted (e.g. an offscreen keep-alive page).
      return 0;
    }

    final view = View.of(context);
    final viewport = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    final visible = bounds.intersect(viewport);
    if (visible.width <= 0 || visible.height <= 0) return 0;
    return (visible.width * visible.height) / area;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
