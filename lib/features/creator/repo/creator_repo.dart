import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

class CreatorRepo {
  static String deriveHandle(String source) {
    final clean = source.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (clean.isEmpty) return 'creator${_uuid.v4().substring(0, 8)}';
    return clean.length > 20 ? clean.substring(0, 20) : clean;
  }

  static const _uuid = Uuid();

  /// Creates or updates the channel.
  ///
  /// Throws on failure rather than swallowing: the screens that call this go
  /// on to the plan step, and advancing past a channel that was never created
  /// leaves the reader paying for nothing. Organisation onboarding currently
  /// always fails this way — see OPEN_ISSUES.
  Future<String> saveCreatorProfile({
    required String handle,
    required String displayName,
    required String type,
    List<String>? categorySlugs,
    String? orgEmail,
    String? orgPhone,
    String? about,
    String? country,
    String? stateOrProvince,
    String? city,
    String? postalCode,
    String? website,
  }) async {
    final existingId = LocalStorage.creatorId;
    if (existingId == null) {
      final channel = await _onboardWithFreeHandle(
        handle: handle,
        displayName: displayName,
        type: type,
        categorySlugs: categorySlugs,
        orgEmail: orgEmail,
        orgPhone: orgPhone,
        about: about,
        country: country,
        stateOrProvince: stateOrProvince,
        city: city,
        postalCode: postalCode,
        website: website,
      );
      unawaited(_provisionQuietly(channel.id));
      return channel.id;
    }
    await updateCreatorProfile(
      creatorId: existingId,
      handle: handle,
      displayName: displayName,
      categorySlugs: categorySlugs,
    );
    return existingId;
  }

  /// Onboards, working around a handle that is already taken.
  ///
  /// A reader who leaves the handle blank gets one derived from their channel
  /// name, and two ministries with the same name derive the same handle. The
  /// server answers 409, and retrying changes nothing — so the second attempt
  /// suffixes the handle rather than handing back a dead end.
  Future<CreatorChannel> _onboardWithFreeHandle({
    required String handle,
    required String displayName,
    required String type,
    List<String>? categorySlugs,
    String? orgEmail,
    String? orgPhone,
    String? about,
    String? country,
    String? stateOrProvince,
    String? city,
    String? postalCode,
    String? website,
  }) async {
    try {
      return await onboardCreator(
        handle: handle,
        displayName: displayName,
        type: type,
        categorySlugs: categorySlugs,
        orgEmail: orgEmail,
        orgPhone: orgPhone,
        about: about,
        country: country,
        stateOrProvince: stateOrProvince,
        city: city,
        postalCode: postalCode,
        website: website,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 409) rethrow;
      final suffix = _uuid.v4().substring(0, 6);
      final trimmed = handle.length > 20 ? handle.substring(0, 20) : handle;
      logger.w('Handle "$handle" taken; retrying as "$trimmed$suffix"');
      return onboardCreator(
        handle: '$trimmed$suffix',
        displayName: displayName,
        type: type,
        categorySlugs: categorySlugs,
        orgEmail: orgEmail,
        orgPhone: orgPhone,
        about: about,
        country: country,
        stateOrProvince: stateOrProvince,
        city: city,
        postalCode: postalCode,
        website: website,
      );
    }
  }

  Future<void> _provisionQuietly(String creatorId) async {
    try {
      await provisionLivestream(creatorId);
    } catch (e) {
      logger.w('Livestream provisioning failed (non-fatal)', error: e);
    }
  }

  Future<void> updateCreatorProfile({
    required String creatorId,
    String? handle,
    String? displayName,
    String? bio,
    List<String>? categorySlugs,
    String? avatarFileId,
    String? bannerFileId,
  }) async {
    final body = <String, dynamic>{
      if (handle != null && handle.isNotEmpty) 'handle': handle.toLowerCase(),
      if (displayName != null && displayName.isNotEmpty)
        'displayName': displayName,
      if (bio != null && bio.isNotEmpty) 'bio': bio,
      if (categorySlugs != null && categorySlugs.isNotEmpty)
        'categorySlugs': categorySlugs,
      // Saving the id is what promotes the object out of `quarantine/`; there
      // is no separate confirm call for creator assets.
      'avatarFileId': ?avatarFileId,
      'bannerFileId': ?bannerFileId,
    };
    if (body.isEmpty) return;
    await _api.patch(ApiEndpoints.creatorById(creatorId), data: body);
  }

  /// The plan catalogue for a billing subject and currency.
  ///
  /// Paged the way the web client pages it. Both query parameters are
  /// required — the route answers 400 naming the missing one, and
  /// `billingSubject` is spelled the British way (`organisation`).
  Future<List<SaasPlan>> fetchPlans({
    required BillingSubject billingSubject,
    required String currency,
    int page = 1,
    int limit = 12,
  }) async {
    final response = await _api.get(
      ApiEndpoints.saasPlans,
      queryParameters: {
        'page': page,
        'limit': limit,
        'billingSubject': billingSubject.value,
        'currency': currency,
      },
    );
    final payload = (response.data as Map<String, dynamic>)['data'];
    final rows = (payload as Map<String, dynamic>)['data'] as List<dynamic>;
    return rows
        .map((e) => SaasPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Which currency to price the plans in.
  ///
  /// `GET /v1/payment/saas/currency-hint` would answer this, but it returns
  /// 500 on staging for every caller, so the currency is derived from the
  /// country the account registered with and falls back to USD — which is
  /// what the web client sends outright.
  static String currencyForCountry(String? isoCode) =>
      _currencyByCountry[isoCode?.toUpperCase()] ?? 'USD';

  /// Only the markets the platform actually prices in; everywhere else bills
  /// in USD rather than in a currency the catalogue may not carry.
  static const _currencyByCountry = <String, String>{
    'NG': 'NGN',
    'GH': 'GHS',
    'KE': 'KES',
    'ZA': 'ZAR',
    'GB': 'GBP',
    'US': 'USD',
    'CA': 'CAD',
  };

  Future<HandleAvailability> checkHandleAvailability(String handle) async {
    final response = await _api.get(
      ApiEndpoints.creatorHandleAvailability(handle),
    );
    return HandleAvailability.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ContentCategory>> fetchCategories() async {
    final response = await _api.get(ApiEndpoints.userCategories);
    final payload = (response.data as Map<String, dynamic>)['data'];
    final rows = (payload as Map<String, dynamic>)['data'] as List<dynamic>;
    return rows
        .map((e) => ContentCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  CreatorRepo({ApiService? api}) : _injected = api;

  final ApiService? _injected;

  /// Resolved when first used rather than when constructed, so a subclass
  /// that overrides every call it makes needs no locator at all.
  ApiService get _api => _injected ?? GetIt.instance<ApiService>();

  String? get cachedCreatorId => LocalStorage.creatorId;

  Future<String?> fetchAndCacheCreatorId() async {
    try {
      final response = await _api.get(ApiEndpoints.creatorProfile);
      final data = response.data as Map<String, dynamic>;
      final creator =
          (data['data'] as Map<String, dynamic>)['creator']
              as Map<String, dynamic>?;
      final id = creator?['id'] as String?;
      if (id != null) {
        await LocalStorage.setString(LocalStorage.creatorIdKey, id);
      }
      return id;
    } catch (e) {
      logger.w('fetchAndCacheCreatorId failed', error: e);
      return null;
    }
  }

  /// Re-reads the profile after checkout. Entitlements land from the PSP
  /// webhook, so this is the only trustworthy confirmation — never the client.
  /// Returns the plan tier once it matches [expectedTier], retrying while the
  /// webhook settles.
  Future<String?> awaitPlanTier(String expectedTier) async {
    const delays = [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 3),
      Duration(seconds: 5),
    ];
    String? tier;
    for (final delay in delays) {
      await Future<void>.delayed(delay);
      tier = await fetchPlanTier();
      if (tier != null && tier.toLowerCase() == expectedTier.toLowerCase()) {
        return tier;
      }
    }
    return tier;
  }

  /// Current SaaS tier, or null when the response does not carry one.
  Future<String?> fetchPlanTier() async {
    try {
      final response = await _api.get(ApiEndpoints.creatorProfile);
      final data = response.data as Map<String, dynamic>;
      final creator =
          (data['data'] as Map<String, dynamic>)['creator']
              as Map<String, dynamic>?;
      if (creator == null) return null;
      final saas = creator['platformSaas'];
      if (saas is Map<String, dynamic>) {
        final tier = (saas['planTier'] ?? saas['tier']) as String?;
        if (tier != null) return tier;
      }
      return creator['planTier'] as String?;
    } catch (e) {
      logger.w('fetchPlanTier failed', error: e);
      return null;
    }
  }

  Future<CreatorChannel> onboardCreator({
    required String handle,
    required String displayName,
    String type = 'individual',
    String? bio,
    List<String>? categorySlugs,
    String? orgEmail,
    String? orgPhone,
    String? about,
    String? country,
    String? stateOrProvince,
    String? city,
    String? postalCode,
    String? website,
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'handle': handle.toLowerCase(),
      'displayName': displayName,
    };
    if (bio != null) body['bio'] = bio;
    if (categorySlugs != null && categorySlugs.isNotEmpty) {
      // The server caps the list at 8 and rejects the whole request over it.
      body['categorySlugs'] = categorySlugs
          .take(AppStrings.creatorCategoryMax)
          .toList();
    }
    // An organisation is refused without these six; the two after them are
    // optional, so they go only when filled.
    for (final entry in {
      'orgEmail': orgEmail,
      'orgPhone': orgPhone,
      'about': about,
      'country': country,
      'stateOrProvince': stateOrProvince,
      'city': city,
      'postalCode': postalCode,
      'website': website,
    }.entries) {
      final value = entry.value?.trim();
      if (value != null && value.isNotEmpty) body[entry.key] = value;
    }
    final response = await _api.post(ApiEndpoints.onboardCreator, data: body);
    final channel = CreatorChannel.fromJson(
      response.data as Map<String, dynamic>,
    );
    await LocalStorage.setString(LocalStorage.creatorIdKey, channel.id);
    return channel;
  }

  /// The channel as the server holds it. Used to check that what a screen
  /// collected actually landed.
  Future<Map<String, dynamic>?> fetchChannel(String creatorId) async {
    final response = await _api.get(ApiEndpoints.creatorById(creatorId));
    final data = response.data['data'];
    if (data is Map<String, dynamic>) {
      final creator = data['creator'];
      return creator is Map<String, dynamic> ? creator : data;
    }
    return null;
  }

  Future<LivestreamProvision> provisionLivestream(String creatorId) async {
    final response = await _api.post(
      ApiEndpoints.provisionLivestream(creatorId),
    );
    final provision = LivestreamProvision.fromJson(
      response.data as Map<String, dynamic>,
    );
    await LocalStorage.saveStreamCredentials(
      creatorId: provision.creatorId,
      muxLiveStreamId: provision.muxLiveStreamId,
      muxLivePlaybackId: provision.muxLivePlaybackId,
      streamKeyRef: provision.streamKeyRef,
      rtmpIngestUrl: provision.rtmpIngestUrl,
    );
    return provision;
  }

  Future<String?> startLivestream(String creatorId) async {
    try {
      final response = await _api.post(ApiEndpoints.startLivestream(creatorId));
      final data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      return data['id'] as String?;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final errorMsg = (body is Map ? body['error']?.toString() : null) ?? '';
      if (status == 409 || errorMsg.toLowerCase().contains('already live')) {
        final existingId = (body is Map && body['data'] is Map)
            ? (body['data'] as Map<String, dynamic>)['id'] as String?
            : null;
        logger.d(
          'startLivestream: already live ($status), existingMediaId=$existingId',
        );
        return existingId;
      }
      logger.e('startLivestream failed', error: e);
      rethrow;
    }
  }

  Future<void> endLivestream(String mediaId) async {
    try {
      await _api.post(ApiEndpoints.endLivestream(mediaId));
      logger.d('endLivestream: stream ended (mediaId: $mediaId)');
    } catch (e) {
      logger.e('endLivestream failed', error: e);
      rethrow;
    }
  }

  Future<CreatorLiveStatus> getCreatorLiveStatus(String creatorId) async {
    final response = await _api.get(ApiEndpoints.creatorLiveStatus(creatorId));
    return CreatorLiveStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PlaybackToken> getPlaybackToken(
    String mediaId,
    String clientSessionId,
  ) async {
    final response = await _api.get(
      ApiEndpoints.livestreamPlaybackToken(mediaId),
      queryParameters: {'clientSessionId': clientSessionId},
    );
    return PlaybackToken.fromJson(response.data as Map<String, dynamic>);
  }
}
