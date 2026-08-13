class CreatorChannel {
  final String id;
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

class CreatorLiveStatus {
  final bool isLive;
  final String? mediaId;

  const CreatorLiveStatus({required this.isLive, this.mediaId});

  factory CreatorLiveStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return CreatorLiveStatus(
      isLive: data['isLive'] as bool,
      mediaId: data['mediaId'] as String?,
    );
  }
}

class PlaybackToken {
  final String playbackId;
  final String token;
  final DateTime expiresAt;

  const PlaybackToken({
    required this.playbackId,
    required this.token,
    required this.expiresAt,
  });

  factory PlaybackToken.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return PlaybackToken(
      playbackId: data['playbackId'] as String,
      token: data['token'] as String,
      expiresAt: DateTime.parse(data['expiresAt'] as String),
    );
  }

  String get hlsUrl => 'https://stream.mux.com/$playbackId.m3u8?token=$token';
}

class HandleAvailability {
  const HandleAvailability({
    required this.handle,
    required this.normalizedHandle,
    required this.available,
    required this.valid,
  });

  final String handle;
  final String normalizedHandle;
  final bool available;
  final bool valid;

  factory HandleAvailability.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return HandleAvailability(
      handle: data['handle'] as String? ?? '',
      normalizedHandle: data['normalizedHandle'] as String? ?? '',
      available: data['available'] as bool? ?? false,
      valid: data['valid'] as bool? ?? false,
    );
  }
}

class ContentCategory {
  const ContentCategory({required this.slug, required this.name});

  final String slug;
  final String name;

  factory ContentCategory.fromJson(Map<String, dynamic> json) =>
      ContentCategory(
        slug: json['slug'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

enum BillingSubject {
  individual('individual'),
  organisation('organisation');

  const BillingSubject(this.value);

  final String value;

  static BillingSubject fromCreatorType(String? creatorType) =>
      creatorType == 'organization'
      ? BillingSubject.organisation
      : BillingSubject.individual;
}

class SaasPlan {
  const SaasPlan({
    required this.id,
    required this.planTier,
    required this.billingSubject,
    required this.billingInterval,
    required this.currency,
    required this.amountMinor,
  });

  final String id;
  final String planTier;
  final String billingSubject;

  final String billingInterval;
  final String currency;
  final int amountMinor;

  int get amountMajor => amountMinor ~/ 100;

  factory SaasPlan.fromJson(Map<String, dynamic> json) => SaasPlan(
    id: json['id'] as String? ?? '',
    planTier: json['planTier'] as String? ?? '',
    billingSubject: json['billingSubject'] as String? ?? '',
    billingInterval: json['billingInterval'] as String? ?? '',
    currency: json['currency'] as String? ?? '',
    amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
  );
}

class CurrencyHint {
  const CurrencyHint({
    required this.recommendedCurrency,
    required this.recommendedProvider,
  });

  final String recommendedCurrency;
  final String recommendedProvider;

  factory CurrencyHint.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return CurrencyHint(
      recommendedCurrency: data['recommendedCurrency'] as String? ?? 'USD',
      recommendedProvider: data['recommendedProvider'] as String? ?? '',
    );
  }
}

class SaasCheckout {
  const SaasCheckout({this.checkoutUrl, this.reference, this.provider});

  final String? checkoutUrl;
  final String? reference;
  final String? provider;

  factory SaasCheckout.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return SaasCheckout(
      checkoutUrl:
          (map['checkoutUrl'] ?? map['authorizationUrl'] ?? map['url'])
              as String?,
      reference: (map['reference'] ?? map['id']) as String?,
      provider: map['provider'] as String?,
    );
  }
}
