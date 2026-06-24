import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static late SharedPreferences _prefs;

  // Storage keys
  static const cachedUserKey = 'gtube_cached_user';
  static const creatorIdKey = 'gtube_creator_id';
  static const muxLiveStreamIdKey = 'gtube_mux_live_stream_id';
  static const muxLivePlaybackIdKey = 'gtube_mux_live_playback_id';
  static const streamKeyRefKey = 'gtube_stream_key_ref';
  static const streamRtmpUrlKey = 'gtube_rtmp_ingest_url';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Generic
  static Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  static String? getString(String key) => _prefs.getString(key);

  static Future<bool> remove(String key) => _prefs.remove(key);

  // Typed getters
  static String? get creatorId => getString(creatorIdKey);

  /// Returns the cached user's first name without importing GtubeUser.
  static String? get cachedFirstName {
    final raw = getString(cachedUserKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map['firstName'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String? get muxLiveStreamId => getString(muxLiveStreamIdKey);
  static String? get muxLivePlaybackId => getString(muxLivePlaybackIdKey);
  static String? get streamKeyRef => getString(streamKeyRefKey);
  static String? get streamRtmpUrl => getString(streamRtmpUrlKey);

  // Batch save for stream credentials returned by provision endpoint
  static Future<void> saveStreamCredentials({
    required String creatorId,
    required String muxLiveStreamId,
    required String muxLivePlaybackId,
    required String streamKeyRef,
    required String rtmpIngestUrl,
  }) => Future.wait<bool>([
    setString(creatorIdKey, creatorId),
    setString(muxLiveStreamIdKey, muxLiveStreamId),
    setString(muxLivePlaybackIdKey, muxLivePlaybackId),
    setString(streamKeyRefKey, streamKeyRef),
    setString(streamRtmpUrlKey, rtmpIngestUrl),
  ]).then((_) {});

  static Future<void> clearCreatorData() => Future.wait<bool>([
    remove(creatorIdKey),
    remove(muxLiveStreamIdKey),
    remove(muxLivePlaybackIdKey),
    remove(streamKeyRefKey),
    remove(streamRtmpUrlKey),
  ]).then((_) {});
}
