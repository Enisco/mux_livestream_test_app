/// Putting a calendar event on a creator's channel.
library;

/// `venueType`, which the API restricts to exactly these three.
enum EventVenueType {
  physical,
  virtual,
  hybrid;

  String get slug => name;

  /// A physical address is required before a `physical` or `hybrid` event
  /// can be published: *"Add a street address and city before publishing
  /// this event"*.
  bool get needsAddress => this != EventVenueType.virtual;

  /// A meeting link is required before a `virtual` or `hybrid` event can
  /// be published: *"Add a valid virtual meeting link before publishing
  /// this event"*.
  bool get needsMeetingUrl => this != EventVenueType.physical;
}

/// Where an event happens. Only `label` is free text; the rest is what the
/// publish check looks at.
class EventLocation {
  const EventLocation({
    this.label = '',
    this.addressLine = '',
    this.city = '',
    this.meetingUrl = '',
  });

  /// "Lekki Conference Centre" — the venue's name, which is what the
  /// design's single location field collects.
  final String label;

  final String addressLine;
  final String city;
  final String meetingUrl;

  bool get isEmpty =>
      label.isEmpty &&
      addressLine.isEmpty &&
      city.isEmpty &&
      meetingUrl.isEmpty;

  factory EventLocation.fromJson(Map<String, dynamic>? json) => EventLocation(
    label: json?['label'] as String? ?? '',
    addressLine: json?['addressLine'] as String? ?? '',
    city: json?['city'] as String? ?? '',
    meetingUrl: json?['meetingUrl'] as String? ?? '',
  );

  /// What a write takes. Empty strings are left out on **create**; an edit
  /// uses [toPatchJson], which keeps them so a cleared field clears.
  Map<String, dynamic> toJson() => {
    if (label.isNotEmpty) 'label': label,
    if (addressLine.isNotEmpty) 'addressLine': addressLine,
    if (city.isNotEmpty) 'city': city,
    if (meetingUrl.isNotEmpty) 'meetingUrl': meetingUrl,
  };

  /// What a PATCH takes: empty strings kept, so a cleared field clears.
  Map<String, dynamic> toPatchJson() => {
    'label': label,
    'addressLine': addressLine,
    'city': city,
    if (meetingUrl.isNotEmpty) 'meetingUrl': meetingUrl,
  };

  EventLocation copyWith({
    String? label,
    String? addressLine,
    String? city,
    String? meetingUrl,
  }) => EventLocation(
    label: label ?? this.label,
    addressLine: addressLine ?? this.addressLine,
    city: city ?? this.city,
    meetingUrl: meetingUrl ?? this.meetingUrl,
  );
}

/// What a creator is about to file. Held as one object so the screen can
/// hand the whole thing to the repo and the repo can decide what the API
/// will actually take.
class EventDraft {
  const EventDraft({
    required this.title,
    required this.venueType,
    required this.startAt,
    required this.timezone,
    this.description = '',
    this.categorySlugs = const [],
    this.endAt,
    this.location = const EventLocation(),
    this.rsvpRequired = false,
    this.capacity,
    this.visibility = 'public',
    this.coverImageFileId,
  });

  final String title;

  /// Required before publishing: *"Event description is required before
  /// publishing"*. Creating a draft without one is allowed.
  final String description;

  final List<String> categorySlugs;
  final EventVenueType venueType;

  /// The instant the event starts. The API takes it in UTC; [timezone] is
  /// what it should be *read* in.
  final DateTime startAt;

  /// Optional — the design says "Leave blank if no end date". It must not
  /// fall before [startAt] or the API answers "Invalid schedule".
  final DateTime? endAt;

  /// An IANA zone name such as `Africa/Lagos`. Required, and validated:
  /// an unknown name or an empty string is refused as "Invalid schedule".
  final String timezone;

  final EventLocation location;

  /// "Allow RSVP" — `registration.required`.
  final bool rsvpRequired;

  /// `registration.capacity`, which the API floors at 1.
  final int? capacity;

  /// `public`, `unlisted` or `private`.
  final String visibility;

  final String? coverImageFileId;

  /// An event as `GET /v1/content/calendar/events/{id}` returns it.
  factory EventDraft.fromJson(Map<String, dynamic> json) {
    final schedule = json['schedule'] as Map<String, dynamic>?;
    final registration = json['registration'] as Map<String, dynamic>?;
    DateTime? at(String key) => DateTime.tryParse(
      schedule?[key] as String? ?? json[key] as String? ?? '',
    );
    return EventDraft(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      categorySlugs: [
        for (final slug in json['categorySlugs'] as List? ?? const [])
          if (slug is String) slug,
      ],
      venueType: EventVenueType.values.firstWhere(
        (v) => v.slug == json['venueType'],
        orElse: () => EventVenueType.physical,
      ),
      startAt: at('startAt')?.toLocal() ?? DateTime.now(),
      endAt: at('endAt')?.toLocal(),
      timezone: schedule?['timezone'] as String? ?? 'UTC',
      location: EventLocation.fromJson(
        json['location'] as Map<String, dynamic>?,
      ),
      rsvpRequired: registration?['required'] as bool? ?? false,
      capacity: (registration?['capacity'] as num?)?.toInt(),
      visibility: json['visibility'] as String? ?? 'public',
      coverImageFileId: json['coverImageFileId'] as String?,
    );
  }

  /// What `PATCH /v1/content/calendar/events/{id}` takes.
  Map<String, dynamic> toPatchJson() => {
    'title': title,
    'description': description,
    'categorySlugs': categorySlugs,
    'venueType': venueType.slug,
    'visibility': visibility,
    'schedule': {
      'startAt': startAt.toUtc().toIso8601String(),
      if (endAt != null) 'endAt': endAt!.toUtc().toIso8601String(),
      'timezone': timezone,
    },
    'location': location.toPatchJson(),
    'registration': {
      'required': rsvpRequired,
      if (rsvpRequired && capacity != null) 'capacity': capacity,
    },
    'coverImageFileId': ?coverImageFileId,
  };

  /// What `POST /v1/content/calendar/events` takes.
  Map<String, dynamic> toJson(String creatorId) => {
    'creatorId': creatorId,
    'title': title,
    if (description.isNotEmpty) 'description': description,
    if (categorySlugs.isNotEmpty) 'categorySlugs': categorySlugs,
    'venueType': venueType.slug,
    'visibility': visibility,
    'schedule': {
      'startAt': startAt.toUtc().toIso8601String(),
      if (endAt != null) 'endAt': endAt!.toUtc().toIso8601String(),
      'timezone': timezone,
    },
    if (!location.isEmpty) 'location': location.toJson(),
    if (rsvpRequired)
      'registration': {
        'required': true,
        if (capacity != null) 'capacity': capacity,
      },
    'coverImageFileId': ?coverImageFileId,
  };

  /// Whether the API will let this be published, rather than only saved.
  /// Checking here spares the creator a refusal after the fact.
  EventPublishBlock? get publishBlock {
    if (description.trim().isEmpty) return EventPublishBlock.description;
    if (venueType.needsAddress &&
        (location.addressLine.trim().isEmpty || location.city.trim().isEmpty)) {
      return EventPublishBlock.address;
    }
    if (venueType.needsMeetingUrl && location.meetingUrl.trim().isEmpty) {
      return EventPublishBlock.meetingUrl;
    }
    return null;
  }
}

/// What the publish check would refuse this draft for.
enum EventPublishBlock { description, address, meetingUrl }
