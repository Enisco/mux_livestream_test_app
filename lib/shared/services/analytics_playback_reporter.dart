import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/shared/services/analytics_service.dart';
import 'package:test_app/shared/services/playback_controller.dart';

/// Turns the shared player's session into analytics beacons.
///
/// Every surface plays through one controller, so wiring the beacons here means
/// feed autoplay, the detail hero and the fullscreen view all report correctly
/// without each screen remembering to.
class AnalyticsPlaybackReporter implements PlaybackReporter {
  AnalyticsPlaybackReporter(this._analytics);

  final AnalyticsService _analytics;

  static double _secs(Duration d) => d.inMilliseconds / 1000;

  @override
  void viewStarted(PlaybackTarget target, Duration at) =>
      _analytics.trackViewStarted(
        mediaId: target.mediaId,
        creatorId: target.creatorId,
        mediaType: target.mediaType,
        source: target.source,
        positionSeconds: _secs(at),
      );

  @override
  void progress(PlaybackTarget target, Duration at, Duration delta) =>
      _analytics.trackProgress(
        mediaId: target.mediaId,
        creatorId: target.creatorId,
        mediaType: target.mediaType,
        source: target.source,
        positionSeconds: _secs(at),
        watchDurationSeconds: _secs(delta),
      );

  @override
  void played(PlaybackTarget target, Duration at) => _analytics.trackPlay(
    mediaId: target.mediaId,
    creatorId: target.creatorId,
    mediaType: target.mediaType,
    source: target.source,
    positionSeconds: _secs(at),
  );

  @override
  void paused(PlaybackTarget target, Duration at, Duration delta) =>
      _analytics.trackPause(
        mediaId: target.mediaId,
        creatorId: target.creatorId,
        mediaType: target.mediaType,
        source: target.source,
        positionSeconds: _secs(at),
        watchDurationSeconds: _secs(delta),
      );

  @override
  void sought(PlaybackTarget target, Duration to) => _analytics.trackSeek(
    mediaId: target.mediaId,
    creatorId: target.creatorId,
    mediaType: target.mediaType,
    source: target.source,
    positionSeconds: _secs(to),
  );

  @override
  void completed(PlaybackTarget target, Duration at, Duration delta) {
    // Livestreams never "complete" — leaving one is a view end, and concurrent
    // viewers are sampled by the live socket instead.
    if (target.mediaType == MediaTypes.livestream) {
      viewEnded(target, at, delta);
      return;
    }
    _analytics.trackCompletion(
      mediaId: target.mediaId,
      creatorId: target.creatorId,
      mediaType: target.mediaType,
      source: target.source,
      positionSeconds: _secs(at),
      watchDurationSeconds: _secs(delta),
    );
  }

  @override
  void viewEnded(PlaybackTarget target, Duration at, Duration delta) =>
      _analytics.trackViewEnded(
        mediaId: target.mediaId,
        creatorId: target.creatorId,
        mediaType: target.mediaType,
        source: target.source,
        positionSeconds: _secs(at),
        watchDurationSeconds: _secs(delta),
      );
}
