import 'package:get_it/get_it.dart';

import 'package:test_app/models/library_models/giving_models.dart';
import 'package:test_app/models/library_models/library_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// The reader's own records: events they said they would attend, prayers they
/// asked for, testimonies they submitted, and what they have given.
///
/// Four separate services, so four shapes. Each read is documented on its
/// method; the things they have in common are that every one of them spans
/// every ministry the reader has dealt with — so a byline is never optional —
/// and that none of them is a search, so narrowing happens on the device.
class ViewerRecordsRepo {
  ViewerRecordsRepo({ApiService? api}) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? GetIt.instance<ApiService>();

  // ---- Events -----------------------------------------------------------

  /// `GET /v1/content/calendar/events/mine` — page-number, not a cursor.
  ///
  /// The list spans every creator the reader has RSVP'd to and **includes
  /// past events**, so the screen groups them itself rather than asking for
  /// one half at a time.
  Future<List<MyEvent>> fetchMyEvents({int page = 1, int limit = 50}) async {
    final response = await _api.get(
      ApiEndpoints.myEvents,
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = _data(response.data);
    return _rows(data['data']).map(_event).toList();
  }

  /// `PATCH …/:id/rsvp/reminder`.
  ///
  /// `offsetMinutes` takes **60, 120, 1440 or null** and nothing else, which
  /// is why the UI offers a fixed picker rather than a free-form field. Null
  /// turns the reminder off. The reader must already have an RSVP.
  Future<void> setReminder(String eventId, int? offsetMinutes) => _api.patch(
    ApiEndpoints.eventRsvpReminder(eventId),
    data: {'offsetMinutes': offsetMinutes},
  );

  /// `DELETE …/:id/rsvp`. This also clears the reminder, so nothing should
  /// leave a reminder toggle lit afterwards.
  Future<void> cancelRsvp(String eventId) =>
      _api.delete(ApiEndpoints.eventRsvp(eventId));

  static MyEvent _event(Map<String, dynamic> json) {
    final event = json['event'] as Map<String, dynamic>? ?? const {};
    final rsvp = json['rsvp'] as Map<String, dynamic>? ?? const {};
    final creator = event['creator'] as Map<String, dynamic>?;
    final at = DateTime.tryParse(
      event['calendarStartAt'] as String? ?? event['startAt'] as String? ?? '',
    )?.toLocal();
    final location = event['location'] as Map<String, dynamic>?;
    return MyEvent(
      id: event['id'] as String? ?? '',
      title: event['title'] as String? ?? '',
      creatorName: creator?['displayName'] as String? ?? '',
      creatorVerified:
          creator?['isVerified'] as bool? ?? creator?['verifiedAt'] != null,
      day: at == null ? '' : at.day.toString().padLeft(2, '0'),
      month: at == null ? '' : _shortMonths[at.month - 1],
      venue:
          location?['label'] as String? ??
          location?['addressLine'] as String? ??
          '',
      time: at == null ? '' : _when(at),
      past: at != null && at.isBefore(DateTime.now()),
      going: rsvp['status'] == 'attending',
      reminderMinutes: (rsvp['offsetMinutes'] as num?)?.toInt(),
    );
  }

  // ---- Prayer requests --------------------------------------------------

  /// `GET /v1/engagement/prayers/mine` — the reader's own, across every
  /// ministry, so the byline always shows.
  ///
  /// `assignedToUserId` comes back on these rows and is **internal ministry
  /// routing**: the requester is shown status, never who is handling it.
  Future<List<PrayerRequest>> fetchMyPrayers({String? cursor}) async {
    final response = await _api.get(
      ApiEndpoints.myPrayers,
      queryParameters: {'limit': 50, 'cursor': ?cursor},
    );
    return _rows(_data(response.data)['items']).map(_prayer).toList();
  }

  static PrayerRequest _prayer(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    final ref = json['contentRef'] as Map<String, dynamic>?;
    final title = ref?['title'] as String?;
    return PrayerRequest(
      id: json['id'] as String? ?? '',
      author: creator?['displayName'] as String? ?? '',
      authorVerified:
          creator?['isVerified'] as bool? ?? creator?['verifiedAt'] != null,
      // `contentRef: null` means it went straight to the ministry. A ref
      // whose `title` is null means the content has since been deleted or
      // made private — said plainly, and not linked.
      about: title ?? '',
      aboutKind: ref == null
          ? PrayerAbout.general
          : _about(ref['targetType'] as String?, ref['mediaType'] as String?),
      aboutGone: ref != null && title == null,
      body: json['body'] as String? ?? '',
      sharedAgo: longAge(DateTime.tryParse(json['createdAt'] as String? ?? '')),
      status: switch (json['status']) {
        'prayed_for' => PrayerStatus.prayedFor,
        'closed' => PrayerStatus.closed,
        _ => PrayerStatus.open,
      },
    );
  }

  static PrayerAbout _about(String? targetType, String? mediaType) =>
      switch (targetType) {
        'post' => PrayerAbout.blog,
        'media' => mediaType == 'music' ? PrayerAbout.audio : PrayerAbout.video,
        null => PrayerAbout.general,
        _ => PrayerAbout.video,
      };

  // ---- Testimonies ------------------------------------------------------

  /// `GET /v1/engagement/testimonies/mine`.
  ///
  /// All three states matter and must read differently: a pending testimony
  /// that looks approved has the reader asking why their story is not on the
  /// wall. Submissions cannot be edited, so a rejected one points at sharing
  /// a new one rather than at an edit that does not exist.
  Future<List<Testimony>> fetchMyTestimonies({String? cursor}) async {
    final response = await _api.get(
      ApiEndpoints.myTestimonies,
      queryParameters: {'limit': 50, 'cursor': ?cursor},
    );
    return _rows(_data(response.data)['items']).map(_testimony).toList();
  }

  /// `DELETE /v1/engagement/testimonies/:id` — the reader may withdraw their
  /// own at any status, including one already on a public wall.
  Future<void> withdrawTestimony(String id) =>
      _api.delete(ApiEndpoints.testimony(id));

  static Testimony _testimony(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    final status = switch (json['status']) {
      'approved' => TestimonyStatus.approved,
      'rejected' => TestimonyStatus.rejected,
      _ => TestimonyStatus.pending,
    };
    return Testimony(
      id: json['id'] as String? ?? '',
      author: creator?['displayName'] as String? ?? '',
      authorVerified:
          creator?['isVerified'] as bool? ?? creator?['verifiedAt'] != null,
      submittedAgo: longAge(
        DateTime.tryParse(json['createdAt'] as String? ?? ''),
      ),
      tags: [
        for (final t in json['impactTags'] as List? ?? const [])
          if (t is String) t,
      ],
      body: json['body'] as String? ?? '',
      status: status,
      // Only meaningful once approved — before that it is on no wall.
      wall: status == TestimonyStatus.approved
          ? (creator?['displayName'] as String? ?? '')
          : '',
    );
  }

  // ---- Giving -----------------------------------------------------------

  /// `GET /v1/payment/giving/me/summary?year=`.
  Future<GivingSummary> fetchGivingSummary(int year) async {
    final response = await _api.get(
      ApiEndpoints.myGivingSummary,
      queryParameters: {'year': year},
    );
    final data = _data(response.data);
    final totals = _rows(data['totalsByCurrency']);
    return GivingSummary(
      year: year,
      // With one currency charged that year, show it as the headline; with
      // several, only the dollar total adds up.
      total: totals.length == 1
          ? _money(totals.single)
          : _usd(data['totalUsdCents']),
      converted: totals.length == 1 ? _usd(data['totalUsdCents']) : '',
      gifts: (data['giftCount'] as num?)?.toInt() ?? 0,
      ministries: (data['ministryCount'] as num?)?.toInt() ?? 0,
      availableYears: [
        for (final y in data['availableYears'] as List? ?? const [])
          if (y is num) y.toInt(),
      ],
    );
  }

  /// `GET /v1/payment/giving/me/gifts?year=` — newest first.
  ///
  /// **Only `succeeded` gifts appear**; a checkout that never completed does
  /// not. A fully refunded gift stays in this list but is left out of the
  /// summary's counts, so the two will not add up and should not be made to.
  Future<List<Gift>> fetchGifts(int year, {String? cursor}) async {
    final response = await _api.get(
      ApiEndpoints.myGifts,
      queryParameters: {'year': year, 'limit': 50, 'cursor': ?cursor},
    );
    return _rows(_data(response.data)['items']).map(_gift).toList();
  }

  static Gift _gift(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    final at = DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal();
    final charge = json['charge'] as Map<String, dynamic>?;
    return Gift(
      id: json['id'] as String? ?? '',
      // The byline may be missing when its lookup failed; the legal name on
      // the charge is the fallback the receipt itself uses.
      ministry:
          creator?['displayName'] as String? ??
          json['recipientName'] as String? ??
          '',
      ministryVerified:
          creator?['isVerified'] as bool? ?? creator?['verifiedAt'] != null,
      fund: json['fundName'] as String? ?? '',
      date: at == null ? '' : '${_shortMonths[at.month - 1]} ${at.day}',
      // Gifts are not charged in USD. The charge currency is the figure; the
      // dollar value is what it came to at the rate used then.
      amount: charge == null ? '' : _money(charge),
      converted: _usd(json['amountUsdCents']),
      document: GiftDocument.receipt,
      refunded: json['refundStatus'] != null,
      monthLabel: at == null
          ? ''
          : '${_longMonths[at.month - 1]} ${at.year}'.toUpperCase(),
    );
  }

  /// `{currency, amount}` as the server already computed it. `amountMinor` is
  /// accounting data and is never re-derived here.
  static String _money(Map<String, dynamic> money) {
    final amount = money['amount'];
    final currency = money['currency'] as String? ?? '';
    if (amount == null) return '';
    return '$currency ${_group(amount)}';
  }

  static String _usd(Object? cents) {
    if (cents is! num) return '';
    return '\$${_group(cents / 100)}';
  }

  static String _group(Object amount) {
    final value = amount is num ? amount.toDouble() : 0.0;
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts.first.split('').reversed.toList();
    final out = <String>[];
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 3 == 0) out.add(',');
      out.add(digits[i]);
    }
    return '${out.reversed.join()}.${parts.last}';
  }

  // ---- Shared -----------------------------------------------------------

  static Map<String, dynamic> _data(Object? body) {
    final data = (body as Map<String, dynamic>?)?['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  static List<Map<String, dynamic>> _rows(Object? rows) => [
    for (final row in rows as List? ?? const [])
      if (row is Map<String, dynamic>) row,
  ];
}

/// "Sat 9:00am", as an event tile writes it.
String _when(DateTime at) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  return '${days[at.weekday - 1]} $hour:$minute${at.hour < 12 ? 'am' : 'pm'}';
}

/// "2 days ago" — the long form the records screens use, as against the
/// compact "2d" on a library row.
String longAge(DateTime? at) {
  if (at == null) return '';
  final gap = DateTime.now().difference(at);
  if (gap.inMinutes < 60) return '${gap.inMinutes} minutes ago';
  if (gap.inHours < 24) {
    return '${gap.inHours} ${gap.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  if (gap.inDays < 7) {
    return '${gap.inDays} ${gap.inDays == 1 ? 'day' : 'days'} ago';
  }
  final weeks = (gap.inDays / 7).floor();
  if (weeks < 5) return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
  final months = (gap.inDays / 30).floor();
  return '$months ${months == 1 ? 'month' : 'months'} ago';
}

const _longMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _shortMonths = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];
