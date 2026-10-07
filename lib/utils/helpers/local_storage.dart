import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static late SharedPreferences _prefs;

  static const cachedUserKey = 'gtube_cached_user';
  static const creatorIdKey = 'gtube_creator_id';
  static const muxLiveStreamIdKey = 'gtube_mux_live_stream_id';
  static const muxLivePlaybackIdKey = 'gtube_mux_live_playback_id';
  static const streamKeyRefKey = 'gtube_stream_key_ref';
  static const streamRtmpUrlKey = 'gtube_rtmp_ingest_url';
  static const liveMediaIdKey = 'gtube_live_media_id';

  static const onboardingIntentKey = 'gtube_onboarding_intent';

  static const creatorTypeKey = 'gtube_creator_type';

  /// The channel name as typed, so the screens after checkout can greet the
  /// reader and title the bio step without another round trip.
  static const creatorNameKey = 'gtube_creator_name';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  static String? getString(String key) => _prefs.getString(key);

  static Future<bool> remove(String key) => _prefs.remove(key);

  static String? get creatorId => getString(creatorIdKey);

  static String? get cachedFirstName {
    final raw = getString(cachedUserKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)['firstName'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String? get cachedFullName {
    final raw = getString(cachedUserKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final first = (map['firstName'] as String?) ?? '';
      final last = (map['lastName'] as String?) ?? '';
      final full = '$first $last'.trim();
      return full.isNotEmpty ? full : null;
    } catch (_) {
      return null;
    }
  }

  /// The ISO-2 country the account was registered with, used to pick a
  /// billing currency now that the currency-hint route is unavailable.
  static String? get cachedCountryCode {
    final raw = getString(cachedUserKey);
    if (raw == null) return null;
    try {
      final code =
          (jsonDecode(raw) as Map<String, dynamic>)['countryCode'] as String?;
      return code == null || code.isEmpty ? null : code.toUpperCase();
    } catch (_) {
      return null;
    }
  }

  /// The account's own id, which `PATCH /v1/user/{id}` is addressed by.
  static String? get cachedUserId {
    final raw = getString(cachedUserKey);
    if (raw == null) return null;
    try {
      final id = (jsonDecode(raw) as Map<String, dynamic>)['id'] as String?;
      return id == null || id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  /// Where the account's photo lives, once one has been confirmed. The key is
  /// resolved to a URL the same way every other asset key is.
  static String? get cachedAvatarKey {
    final raw = getString(cachedUserKey);
    if (raw == null) return null;
    try {
      final key =
          (jsonDecode(raw) as Map<String, dynamic>)['avatarKey'] as String?;
      return key == null || key.isEmpty ? null : key;
    } catch (_) {
      return null;
    }
  }

  static String? get cachedPhone {
    final raw = getString(cachedUserKey);
    if (raw == null) return null;
    try {
      final phone =
          (jsonDecode(raw) as Map<String, dynamic>)['phone'] as String?;
      return phone == null || phone.isEmpty ? null : phone;
    } catch (_) {
      return null;
    }
  }

  /// The topics the reader picked during onboarding.
  static List<String> get cachedTopicSlugs {
    final raw = getString(cachedUserKey);
    if (raw == null) return const [];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return [
        for (final s
            in map['viewerPreferenceCategorySlugs'] as List? ?? const [])
          if (s is String) s,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Replace the cached account wholesale.
  ///
  /// Every `cached…` getter above reads one blob, so the way to keep them in
  /// step after a write is to store the `User` the route answered with rather
  /// than patching fields in.
  static Future<bool> cacheUser(Map<String, dynamic> user) =>
      setString(cachedUserKey, jsonEncode(user));

  static String? get cachedEmail {
    final raw = getString(cachedUserKey);
    if (raw == null) return null;
    try {
      final email =
          (jsonDecode(raw) as Map<String, dynamic>)['email'] as String?;
      return email == null || email.isEmpty ? null : email;
    } catch (_) {
      return null;
    }
  }

  static String? get cachedHandle {
    final raw = getString(cachedUserKey);
    if (raw == null) return null;
    try {
      final email =
          (jsonDecode(raw) as Map<String, dynamic>)['email'] as String?;
      if (email == null) return null;
      final prefix = email.split('@').first;
      final clean = prefix
          .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
          .toLowerCase();
      return clean.isNotEmpty ? '@$clean' : null;
    } catch (_) {
      return null;
    }
  }

  static String? get muxLiveStreamId => getString(muxLiveStreamIdKey);
  static String? get muxLivePlaybackId => getString(muxLivePlaybackIdKey);
  static String? get streamKeyRef => getString(streamKeyRefKey);
  static String? get streamRtmpUrl => getString(streamRtmpUrlKey);
  static String? get liveMediaId => getString(liveMediaIdKey);

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
    remove(liveMediaIdKey),
  ]).then((_) {});
}
