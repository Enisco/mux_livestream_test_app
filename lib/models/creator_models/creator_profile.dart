/// A creator as a viewer sees them (Figma "Creators Profile - Viewers POV").
///
/// Served by `GET /v1/creator/{id}` and `GET /v1/creator/handle/{handle}`,
/// which both wrap the record in `data.creator`.
class CreatorProfile {
  const CreatorProfile({
    required this.id,
    required this.displayName,
    required this.handle,
    this.bio,
    this.avatarKey,
    this.bannerKey,
    this.type = 'individual',
    this.isVerified = false,
    this.isFollowing = false,
    this.subscriberCount = 0,
    this.totalViews = 0,
    this.categorySlugs = const [],
    this.createdAt,
  });

  final String id;
  final String displayName;
  final String handle;
  final String? bio;
  final String? avatarKey;
  final String? bannerKey;
  final String type;
  final bool isVerified;
  final bool isFollowing;
  final int subscriberCount;
  final int totalViews;
  final List<String> categorySlugs;
  final DateTime? createdAt;

  bool get isOrganization => type == 'organization';

  factory CreatorProfile.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map<String, dynamic>
        ? (data['creator'] is Map<String, dynamic>
              ? data['creator'] as Map<String, dynamic>
              : data)
        : json;
    return CreatorProfile(
      id: map['id'] as String? ?? map['creatorId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      handle: (map['handle'] as String? ?? '').replaceFirst('@', ''),
      bio: map['bio'] as String?,
      avatarKey: map['avatarKey'] as String?,
      bannerKey: map['bannerKey'] as String?,
      type: map['type'] as String? ?? 'individual',
      isVerified: map['isVerified'] as bool? ?? map['verifiedAt'] != null,
      isFollowing: map['isFollowing'] as bool? ?? false,
      subscriberCount: (map['subscriberCount'] as num?)?.toInt() ?? 0,
      totalViews: (map['totalViews'] as num?)?.toInt() ?? 0,
      categorySlugs: (map['categorySlugs'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
    );
  }

  CreatorProfile copyWith({bool? isFollowing, int? subscriberCount}) =>
      CreatorProfile(
        id: id,
        displayName: displayName,
        handle: handle,
        bio: bio,
        avatarKey: avatarKey,
        bannerKey: bannerKey,
        type: type,
        isVerified: isVerified,
        isFollowing: isFollowing ?? this.isFollowing,
        subscriberCount: subscriberCount ?? this.subscriberCount,
        totalViews: totalViews,
        categorySlugs: categorySlugs,
        createdAt: createdAt,
      );
}

/// One approved story on the Testimonies tab.
class CreatorTestimony {
  const CreatorTestimony({
    required this.id,
    required this.body,
    this.anonymous = false,
    this.createdAt,
  });

  final String id;
  final String body;
  final bool anonymous;
  final DateTime? createdAt;

  factory CreatorTestimony.fromJson(Map<String, dynamic> json) =>
      CreatorTestimony(
        id: json['id'] as String? ?? '',
        body: json['body'] as String? ?? '',
        anonymous: json['displayAsAnonymous'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );
}
