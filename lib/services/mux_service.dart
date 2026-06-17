import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/mux_config.dart';

class MuxLiveStream {
  final String id;
  final String streamKey;
  final String rtmpIngestUrl;
  final String hlsUrl;
  String status;

  MuxLiveStream({
    required this.id,
    required this.streamKey,
    required this.rtmpIngestUrl,
    required this.hlsUrl,
    required this.status,
  });
}

class MuxApiException implements Exception {
  final int statusCode;
  final String message;
  MuxApiException(this.statusCode, this.message);

  @override
  String toString() => 'MuxApiException($statusCode): $message';
}

class MuxService {
  static final _authHeader =
      'Basic ${base64Encode(utf8.encode('${MuxConfig.tokenId}:${MuxConfig.tokenSecret}'))}';

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        'Authorization': _authHeader,
      };

  Future<MuxLiveStream> createLiveStream() async {
    final response = await http.post(
      Uri.parse('${MuxConfig.apiBase}/video/v1/live-streams'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'playback_policy': ['public'],
        'new_asset_settings': {
          'playback_policy': ['public'],
        },
      }),
    );
    if (response.statusCode != 201) {
      throw MuxApiException(response.statusCode, response.body);
    }
    final data = jsonDecode(response.body)['data'] as Map<String, dynamic>;
    final streamKey = data['stream_key'] as String;
    final playbackIds = data['playback_ids'] as List<dynamic>;
    final playbackId = playbackIds.first['id'] as String;
    return MuxLiveStream(
      id: data['id'] as String,
      streamKey: streamKey,
      rtmpIngestUrl: MuxConfig.rtmpUrl(streamKey),
      hlsUrl: MuxConfig.hlsUrl(playbackId),
      status: data['status'] as String? ?? 'idle',
    );
  }

  Future<String> getStreamStatus(String streamId) async {
    final response = await http.get(
      Uri.parse('${MuxConfig.apiBase}/video/v1/live-streams/$streamId'),
      headers: _jsonHeaders,
    );
    if (response.statusCode != 200) {
      throw MuxApiException(response.statusCode, response.body);
    }
    final data = jsonDecode(response.body)['data'] as Map<String, dynamic>;
    return data['status'] as String? ?? 'idle';
  }

  Future<void> disableLiveStream(String streamId) async {
    final response = await http.put(
      Uri.parse('${MuxConfig.apiBase}/video/v1/live-streams/$streamId/disable'),
      headers: _jsonHeaders,
    );
    if (response.statusCode != 200) {
      throw MuxApiException(response.statusCode, response.body);
    }
  }

  Future<String> whipHandshake(String streamKey, String offerSdp) async {
    final response = await http.post(
      Uri.parse(MuxConfig.whipUrl(streamKey)),
      headers: {'Content-Type': 'application/sdp'},
      body: offerSdp,
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw MuxApiException(response.statusCode, response.body);
    }
    return response.body;
  }
}
