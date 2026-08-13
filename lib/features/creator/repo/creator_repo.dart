import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

class CreatorRepo {
  static String deriveHandle(String source) {
    final clean = source.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (clean.isEmpty) return 'creator${_uuid.v4().substring(0, 8)}';
    return clean.length > 20 ? clean.substring(0, 20) : clean;
  }

  static const _uuid = Uuid();

  Future<String?> saveCreatorProfile({
    required String handle,
    required String displayName,
    required String type,
    List<String>? categorySlugs,
  }) async {
    final existingId = LocalStorage.creatorId;
    try {
      if (existingId == null) {
        final channel = await onboardCreator(
          handle: handle,
          displayName: displayName,
          type: type,
          categorySlugs: categorySlugs,
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
    } catch (e) {
      logger.e('Could not save creator profile', error: e);
      return existingId;
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
  }) async {
    final body = <String, dynamic>{
      if (handle != null && handle.isNotEmpty) 'handle': handle.toLowerCase(),
      if (displayName != null && displayName.isNotEmpty)
        'displayName': displayName,
      if (bio != null && bio.isNotEmpty) 'bio': bio,
      if (categorySlugs != null && categorySlugs.isNotEmpty)
        'categorySlugs': categorySlugs,
    };
    if (body.isEmpty) return;
    await _api.patch(ApiEndpoints.creatorById(creatorId), data: body);
  }

  Future<SaasCheckout> createCheckout({
    required String creatorId,
    required String planTier,
    required bool yearly,
    required String provider,
    required String currency,
  }) async {
    final response = await _api.post(
      ApiEndpoints.saasCheckout,
      data: {
        'creatorId': creatorId,
        'planTier': planTier,
        'billingInterval': yearly ? 'year' : 'month',
        'preferredProvider': provider,
        'billingCurrency': currency,
        'checkoutFlow': 'hosted_checkout',
        'checkoutSurface': Platform.isIOS ? 'ios' : 'android',
      },
    );
    return SaasCheckout.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<SaasPlan>> fetchPlans({
    required BillingSubject billingSubject,
    required String currency,
  }) async {
    final response = await _api.get(
      ApiEndpoints.saasPlans,
      queryParameters: {
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

  Future<CurrencyHint> fetchCurrencyHint() async {
    final response = await _api.get(ApiEndpoints.saasCurrencyHint);
    return CurrencyHint.fromJson(response.data as Map<String, dynamic>);
  }

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

  final ApiService _api = GetIt.instance<ApiService>();

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

  Future<CreatorChannel> onboardCreator({
    required String handle,
    required String displayName,
    String type = 'individual',
    String? bio,
    List<String>? categorySlugs,
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'handle': handle.toLowerCase(),
      'displayName': displayName,
    };
    if (bio != null) body['bio'] = bio;
    if (categorySlugs != null && categorySlugs.isNotEmpty) {
      body['categorySlugs'] = categorySlugs;
    }
    final response = await _api.post(ApiEndpoints.onboardCreator, data: body);
    final channel = CreatorChannel.fromJson(
      response.data as Map<String, dynamic>,
    );
    await LocalStorage.setString(LocalStorage.creatorIdKey, channel.id);
    return channel;
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
