/// Shared analytics contract types, so event names, `source` labels and
/// promotion attribution can't drift between surfaces.
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

  static const immediate = {
    click,
    promotionClick,
    promotedQualifiedImpression,
    viewEnded,
    completion,
  };

  /// Billable events — never fabricated from route state, never replayed.
  static const paid = {promotionClick, promotedQualifiedImpression};
}

/// `source` values the gateway accepts; anything else becomes [unknown].
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

  /// Null rather than a guess — a wrong `mediaType` is worse than none.
  static String? normalize(String? raw) =>
      raw != null && all.contains(raw) ? raw : null;
}

abstract final class PromotionPlacement {
  static const catalogue = 'catalogue';
  static const verticalFeed = 'vertical_feed';

  static const all = {catalogue, verticalFeed};
}

/// Server-issued attribution for one served placement. Built only from a
/// feed/suggestion payload — never minted, edited, or carried into a
/// destination route.
class PromotionAttribution {
  final String campaignId;
  final String placement;
  final String deliveryId;

  const PromotionAttribution({
    required this.campaignId,
    required this.placement,
    required this.deliveryId,
  });

  /// Null unless the item is flagged promoted *and* carries all three
  /// server-issued fields. A partial payload is treated as organic.
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

  /// Identity of one paid delivery — de-duplication key and `eventId` seed.
  String get deliveryKey => '$campaignId|$placement|$deliveryId';

  @override
  String toString() =>
      'PromotionAttribution($campaignId, $placement, ${deliveryId.length} chars)';
}

/// Accumulates `watchDurationSeconds`, counting only time actually playing.
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
