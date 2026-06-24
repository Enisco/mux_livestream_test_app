import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../../core/logger.dart';
import '../../../services/api_service.dart';
import '../../../utils/api_endpoints.dart';
import '../../../utils/local_storage.dart';
import '../models/creator_models.dart';

class CreatorRepo {
  final ApiService _api = GetIt.instance<ApiService>();

  String? get cachedCreatorId => LocalStorage.creatorId;

  /// Fetches the authenticated user's creator profile and caches the creatorId.
  /// Returns null if the user has no creator channel yet.
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
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'handle': handle.toLowerCase(),
      'displayName': displayName,
    };
    if (bio != null) body['bio'] = bio;
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
        // Backend may include the existing stream object in the 409 body.
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
