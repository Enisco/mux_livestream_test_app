class CreatorChannel {
  final String id; // saved locally as creatorId
  final String type;
  final String handle;
  final String displayName;
  final String? bio;
  final String? avatarFileId;
  final String? avatarKey;
  final String? bannerFileId;
  final String? bannerKey;
  final String ownerUserId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreatorChannel({
    required this.id,
    required this.type,
    required this.handle,
    required this.displayName,
    this.bio,
    this.avatarFileId,
    this.avatarKey,
    this.bannerFileId,
    this.bannerKey,
    required this.ownerUserId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CreatorChannel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return CreatorChannel(
      id: data['id'] as String,
      type: data['type'] as String,
      handle: data['handle'] as String,
      displayName: data['displayName'] as String,
      bio: data['bio'] as String?,
      avatarFileId: data['avatarFileId'] as String?,
      avatarKey: data['avatarKey'] as String?,
      bannerFileId: data['bannerFileId'] as String?,
      bannerKey: data['bannerKey'] as String?,
      ownerUserId: data['ownerUserId'] as String,
      status: data['status'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }
}

class LivestreamProvision {
  final String id;
  final String creatorId;
  final String muxLiveStreamId;
  final String muxLivePlaybackId;
  final String streamKeyRef;
  final String rtmpIngestUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LivestreamProvision({
    required this.id,
    required this.creatorId,
    required this.muxLiveStreamId,
    required this.muxLivePlaybackId,
    required this.streamKeyRef,
    required this.rtmpIngestUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LivestreamProvision.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return LivestreamProvision(
      id: data['id'] as String,
      creatorId: data['creatorId'] as String,
      muxLiveStreamId: data['muxLiveStreamId'] as String,
      muxLivePlaybackId: data['muxLivePlaybackId'] as String,
      streamKeyRef: data['streamKeyRef'] as String,
      rtmpIngestUrl: data['rtmpIngestUrl'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }
}
