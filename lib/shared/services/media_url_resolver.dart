import 'package:test_app/core/logger.dart';
import 'package:test_app/models/discovery_models/media_detail.dart';
import 'package:test_app/shared/services/playback_info_cache.dart';

/// Turns a media id into a playable URL, cache first.
///
/// Feed cards only carry an id — the signed stream URL comes from the playback
/// endpoint. Those URLs expire, which is why the cache holds them briefly and
/// the API is asked again once it does.
class MediaUrlResolver {
  MediaUrlResolver({required this.cache, required this.fetch});

  final PlaybackInfoCache cache;
  final Future<PlaybackInfo?> Function(String mediaId) fetch;

  Future<String?> call(String mediaId) async {
    if (mediaId.isEmpty) return null;

    final cached = cache.get(mediaId);
    if (cached != null && cached.playbackUrl.isNotEmpty) {
      return cached.playbackUrl;
    }

    final PlaybackInfo? info;
    try {
      info = await fetch(mediaId);
    } catch (e) {
      // A failed lookup must not take the caller down with it; the surface
      // just falls back to its idle state.
      logger.w('Playback lookup failed for $mediaId', error: e);
      return null;
    }

    if (info == null || info.playbackUrl.isEmpty) return null;
    cache.put(mediaId, info);
    return info.playbackUrl;
  }
}
