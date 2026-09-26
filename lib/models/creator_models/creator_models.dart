import 'package:test_app/shared/services/asset_url_resolver.dart';

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
  const ContentCategory({
    required this.slug,
    required this.name,
    this.description = '',
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String slug;
  final String name;
  final String description;

  /// The order the taxonomy is meant to be shown in; the API numbers them
  /// from 1 and the onboarding chips follow it rather than payload order.
  final int sortOrder;

  /// A retired category still comes back, so anything drawing chips has to
  /// filter on this rather than assume everything returned is offerable.
  final bool isActive;

  factory ContentCategory.fromJson(Map<String, dynamic> json) =>
      ContentCategory(
        slug: json['slug'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] as bool? ?? true,
      );
}

enum MobileCheckoutStatus {
  created,
  inProgress,
  processing,
  succeeded,
  failed,
  canceled,
  expired,
  unknown;

  static MobileCheckoutStatus fromApi(String? value) => switch (value) {
    'created' => created,
    'in_progress' => inProgress,
    'processing' => processing,
    'succeeded' => succeeded,
    'failed' => failed,
    'canceled' => canceled,
    'expired' => expired,
    _ => unknown,
  };

  /// Nothing more will happen without a new attempt.
  bool get isTerminal => switch (this) {
    succeeded || failed || canceled || expired => true,
    _ => false,
  };
}

/// Whether a storefront may sell a given product. Fail-closed in production.
class CheckoutCapabilities {
  const CheckoutCapabilities({
    required this.subscriptionAvailable,
    this.subscriptionReason,
  });

  final bool subscriptionAvailable;
  final String? subscriptionReason;

  factory CheckoutCapabilities.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final sub = map['platformSubscription'];
    final subMap = sub is Map<String, dynamic>
        ? sub
        : const <String, dynamic>{};
    return CheckoutCapabilities(
      subscriptionAvailable: subMap['available'] as bool? ?? false,
      subscriptionReason: subMap['reason'] as String?,
    );
  }
}

/// A single-use, short-lived ticket into the web checkout. Never log or persist
/// it — the guide treats the ticket as a credential.
class MobileCheckoutLaunch {
  const MobileCheckoutLaunch({required this.launchUrl, this.expiresAt});

  final String launchUrl;
  final DateTime? expiresAt;

  bool get isUsable => launchUrl.isNotEmpty && !_expired;

  bool get _expired {
    final at = expiresAt;
    return at != null && DateTime.now().toUtc().isAfter(at);
  }

  factory MobileCheckoutLaunch.fromMap(Map<String, dynamic> map) =>
      MobileCheckoutLaunch(
        launchUrl: map['launchUrl'] as String? ?? '',
        expiresAt: DateTime.tryParse(
          map['launchExpiresAt'] as String? ?? '',
        )?.toUtc(),
      );

  factory MobileCheckoutLaunch.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return MobileCheckoutLaunch.fromMap(
      data is Map<String, dynamic> ? data : const <String, dynamic>{},
    );
  }
}

/// The entitlements a checkout is granting. Server truth — the client never
/// infers a plan from a PSP result.
class CheckoutEntitlement {
  const CheckoutEntitlement({this.planTier, this.status});

  final String? planTier;
  final String? status;

  factory CheckoutEntitlement.fromJson(Map<String, dynamic> json) =>
      CheckoutEntitlement(
        planTier: json['planTier'] as String?,
        status: json['status'] as String?,
      );
}

/// Canonical state of a mobile→web checkout attempt. The only thing the app
/// trusts; return-link query parameters are navigation, not proof.
class MobileCheckoutSession {
  const MobileCheckoutSession({
    required this.id,
    required this.status,
    this.paymentProvider,
    this.mobileReturnUrl,
    this.targetPlanTier,
    this.entitlementsReady = false,
    this.scheduled = false,
    this.entitlement,
  });

  final String id;
  final MobileCheckoutStatus status;
  final String? paymentProvider;
  final String? mobileReturnUrl;
  final String? targetPlanTier;
  final bool entitlementsReady;
  final bool scheduled;
  final CheckoutEntitlement? entitlement;

  /// Provider confirmation alone is not completion — entitlements must agree.
  bool get isSettled =>
      status == MobileCheckoutStatus.succeeded && entitlementsReady;

  bool get isTerminal => status.isTerminal;

  factory MobileCheckoutSession.fromMap(Map<String, dynamic> map) {
    final sub = map['subscription'];
    final subMap = sub is Map<String, dynamic>
        ? sub
        : const <String, dynamic>{};
    final ent = subMap['entitlement'];
    return MobileCheckoutSession(
      id: map['id'] as String? ?? '',
      status: MobileCheckoutStatus.fromApi(map['status'] as String?),
      paymentProvider: map['paymentProvider'] as String?,
      mobileReturnUrl: map['mobileReturnUrl'] as String?,
      targetPlanTier: subMap['targetPlanTier'] as String?,
      entitlementsReady: subMap['entitlementsReady'] as bool? ?? false,
      scheduled: subMap['scheduled'] as bool? ?? false,
      entitlement: ent is Map<String, dynamic>
          ? CheckoutEntitlement.fromJson(ent)
          : null,
    );
  }

  factory MobileCheckoutSession.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final session = map['session'];
    return MobileCheckoutSession.fromMap(
      session is Map<String, dynamic> ? session : map,
    );
  }
}

/// A freshly created session paired with its first launch ticket.
class MobileCheckoutHandoff {
  const MobileCheckoutHandoff({required this.session, required this.launch});

  final MobileCheckoutSession session;
  final MobileCheckoutLaunch launch;

  factory MobileCheckoutHandoff.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return MobileCheckoutHandoff(
      session: MobileCheckoutSession.fromJson(json),
      launch: MobileCheckoutLaunch.fromMap(map),
    );
  }
}

/// Whether the signed-in reader has a channel.
///
/// Three answers, not two: a reader with no channel should be invited to
/// start one, but a reader whose lookup merely failed should not be — that
/// invitation would walk them into `POST /v1/creator/onboard` and a 409.
class ChannelLookup {
  const ChannelLookup._(this.id, this.state);

  const ChannelLookup.found(String id) : this._(id, ChannelState.found);
  const ChannelLookup.none() : this._(null, ChannelState.none);
  const ChannelLookup.unavailable() : this._(null, ChannelState.unavailable);

  final String? id;
  final ChannelState state;

  bool get hasChannel => state == ChannelState.found;

  /// Only a reader the server says has no channel is offered one.
  bool get canStartOne => state == ChannelState.none;
}

enum ChannelState { found, none, unavailable }

/// The channel a post goes out as.
class CreatorByline {
  const CreatorByline({
    required this.displayName,
    required this.handle,
    this.verified = false,
    this.avatarUrl,
    this.subscriberCount = 0,
  });

  factory CreatorByline.fromJson(Map<String, dynamic> json) {
    final handle = json['handle'] as String? ?? '';
    return CreatorByline(
      displayName: json['displayName'] as String? ?? '',
      handle: handle.startsWith('@') ? handle : '@$handle',
      verified: json['verifiedAt'] != null || json['isVerified'] == true,
      avatarUrl: AssetUrlResolver.resolve(json['avatarKey'] as String?),
      subscriberCount: (json['subscriberCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String displayName;
  final String handle;
  final bool verified;
  final String? avatarUrl;
  final int subscriberCount;
}
