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

  Future<void> startLivestream(String creatorId) async {
    try {
      await _api.post(ApiEndpoints.startLivestream(creatorId));
    } on DioException catch (e) {
      // 409 means the stream is already in a started/active state — that's fine.
      if (e.response?.statusCode == 409) {
        logger.d('startLivestream: already started (409), proceeding');
        return;
      }
      logger.e('startLivestream failed', error: e);
      rethrow;
    }
  }
}
