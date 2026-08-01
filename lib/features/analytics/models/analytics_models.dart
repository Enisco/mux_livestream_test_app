/// Shared analytics contract types.
///
/// Every surface that emits media beacons goes through these constants and
/// value objects so event names, `source` labels, and promotion attribution
/// can never drift between screens. See `client-media-integration.md`
/// § Analytics Beacons.
library;

abstract final class AnalyticsEventType {
  static const viewStarted = 'view_started';
  static const play = 'play';
  static const pause = 'pause';
  static const seek = 'seek';
  static const progress = 'progress';
  static const viewEnded = 'view_ended';
  static const completion = 'completion';
  static const impression = 'impression';
  static const click = 'click';
  static const promotionClick = 'promotion_click';
  static const promotedQualifiedImpression = 'promoted_qualified_impression';

  /// Events that must reach the server as soon as they happen rather than
  /// waiting for the periodic flush.
  static const immediate = {
    click,
    promotionClick,
    promotedQualifiedImpression,
    viewEnded,
    completion,
  };

  /// Billable events. The client never fabricates these from route state and
  /// never replays them across surfaces.
  static const paid = {promotionClick, promotedQualifiedImpression};
}

/// `source` values accepted by the gateway. Not an open enum on the client —
/// anything else is reported as [unknown] so the funnel stays clean.
abstract final class AnalyticsSource {
  static const creatorChannel = 'creator_channel';
  static const homeFeed = 'home_feed';
  static const suggestedContent = 'suggested_content';
  static const search = 'search';
  static const shareLink = 'share_link';
  static const notification = 'notification';
  static const external = 'external';
  static const unknown = 'unknown';

  static const all = {
    creatorChannel,
    homeFeed,
    suggestedContent,
    search,
    shareLink,
    notification,
    external,
    unknown,
  };

  static String normalize(String? raw) =>
      raw != null && all.contains(raw) ? raw : unknown;
}

abstract final class MediaTypes {
  static const video = 'video';
  static const music = 'music';
  static const livestream = 'livestream';

  static const all = {video, music, livestream};

  /// Returns null rather than guessing — the contract says include `mediaType`
  /// *whenever the client knows it*, and a wrong value is worse than none.
  static String? normalize(String? raw) =>
      raw != null && all.contains(raw) ? raw : null;
}

abstract final class PromotionPlacement {
  static const catalogue = 'catalogue';
  static const verticalFeed = 'vertical_feed';

  static const all = {catalogue, verticalFeed};
}

/// Server-issued promotion attribution for a single served placement.
///
/// Constructed only from a feed/suggestion payload. The client never mints,
/// decodes, or edits [deliveryId], never copies attribution onto an organic
/// item, and never carries it into a destination route.
class PromotionAttribution {
  final String campaignId;
  final String placement;
  final String deliveryId;

  const PromotionAttribution({
    required this.campaignId,
    required this.placement,
    required this.deliveryId,
  });

  /// Parses attribution from a feed item (`meta` for web feed items, the item
  /// itself for vertical feed items).
  ///
  /// Returns null unless the item is flagged promoted *and* carries all three
  /// server-issued fields with a recognised placement. A partially-populated
  /// payload is treated as organic: render it, emit no paid event.
  static PromotionAttribution? tryParse(Map<String, dynamic>? json) {
    if (json == null) return null;
    if (json['isPromoted'] != true) return null;
    final campaignId = (json['promotionCampaignId'] as String?)?.trim() ?? '';
    final placement = (json['promotionPlacement'] as String?)?.trim() ?? '';
    final deliveryId = (json['promotionDeliveryId'] as String?)?.trim() ?? '';
    if (campaignId.isEmpty || deliveryId.isEmpty) return null;
    if (!PromotionPlacement.all.contains(placement)) return null;
    return PromotionAttribution(
      campaignId: campaignId,
      placement: placement,
      deliveryId: deliveryId,
    );
  }

  Map<String, dynamic> toBeaconFields() => {
    'promotionCampaignId': campaignId,
    'promotionPlacement': placement,
    'promotionDeliveryId': deliveryId,
  };

  /// Identity of one paid delivery, used for client-side de-duplication and for
  /// deriving a stable `eventId` so retries stay idempotent.
  String get deliveryKey => '$campaignId|$placement|$deliveryId';

  @override
  String toString() =>
      'PromotionAttribution($campaignId, $placement, ${deliveryId.length} chars)';
}

/// Wall-clock accumulator for `watchDurationSeconds`.
///
/// Counts only time the media was actually playing, so it stays honest across
/// pauses, buffering stalls, and app backgrounding.
class WatchClock {
  Duration _accumulated = Duration.zero;
  DateTime? _startedAt;

  void start() => _startedAt ??= DateTime.now();

  void stop() {
    final startedAt = _startedAt;
    if (startedAt == null) return;
    _accumulated += DateTime.now().difference(startedAt);
    _startedAt = null;
  }

  double get seconds {
    final startedAt = _startedAt;
    final running = startedAt == null
        ? Duration.zero
        : DateTime.now().difference(startedAt);
    return (_accumulated + running).inMilliseconds / 1000.0;
  }

  void reset() {
    _accumulated = Duration.zero;
    _startedAt = null;
  }
}
