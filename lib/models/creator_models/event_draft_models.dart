/// Putting a calendar event on a creator's channel.
///
/// Events are not media: no file is uploaded, nothing is transcoded, and
/// they live in the content service rather than the media one. What they
/// share with an upload is the cover image — the same S3 presigned POST.
///
/// Everything here was read off staging; the route's own refusals are
/// quoted where they settled a question.
library;

/// `venueType`, which the API restricts to exactly these three.
///
/// The design calls the first one "In Person"; the API calls it
/// **`physical`**, and refuses `in_person` outright.
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

  Map<String, dynamic> toJson() => {
    if (label.isNotEmpty) 'label': label,
    if (addressLine.isNotEmpty) 'addressLine': addressLine,
    if (city.isNotEmpty) 'city': city,
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

  /// What `POST /v1/content/calendar/events` takes.
  ///
  /// `recurrence` is left alone: `mode` currently accepts only `none`, so
  /// there is nothing to choose. `seriesId` is not sent because **events
  /// have no series** — the API refuses the property under every name
  /// tried, and the event it returns carries no such field
  /// (OPEN_ISSUES 20).
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
