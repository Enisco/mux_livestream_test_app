import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/repo/event_repo.dart';
import 'package:test_app/features/creator/views/new_event_screen.dart';
import 'package:test_app/models/creator_models/event_draft_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'helpers/load_app_fonts.dart';

/// A 1×1 PNG, enough to have bytes and a name.
final _swatch = PickedImage(
  bytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  ),
  filename: 'cover.png',
  mimeType: 'image/png',
);

EventDraft _draft({
  String title = 'Encounter Conference 2026',
  String description = 'Three evenings of worship and teaching.',
  EventVenueType venueType = EventVenueType.physical,
  EventLocation location = const EventLocation(
    label: 'Lekki Conference Centre',
    addressLine: '1 Admiralty Way',
    city: 'Lagos',
  ),
  DateTime? endAt,
  bool rsvp = true,
  int? capacity = 500,
  String? coverImageFileId,
}) => EventDraft(
  title: title,
  description: description,
  venueType: venueType,
  startAt: DateTime.utc(2026, 10, 10, 9),
  endAt: endAt,
  timezone: 'Africa/Lagos',
  location: location,
  rsvpRequired: rsvp,
  capacity: capacity,
  coverImageFileId: coverImageFileId,
);

class _FakeApi implements ApiService {
  _FakeApi({this.body, this.error});

  Map<String, dynamic>? body;
  DioException? error;

  final List<String> paths = [];
  final Map<String, Map<String, dynamic>> sent = {};

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          const {
                'data': {
                  'data': [
                    {'slug': 'worship', 'name': 'Worship'},
                  ],
                },
              }
              as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    if (data is Map<String, dynamic>) sent[path] = data;
    if (error != null) throw error!;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (body ?? const <String, dynamic>{}) as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

DioException _refusal(List<String> errors) => DioException(
  requestOptions: RequestOptions(path: '/v1/content/calendar/events'),
  response: Response(
    requestOptions: RequestOptions(path: '/v1/content/calendar/events'),
    statusCode: 400,
    data: {'success': false, 'data': null, 'error': errors},
  ),
);

Future<void> _pumpScreen(WidgetTester tester, {Size? size}) async {
  final api = _FakeApi(
    body: const {
      'data': {'id': 'e1'},
    },
  );
  // Tall enough that the whole form builds: a ListView does not build
  // what is off-screen, and the fields at the foot are the point.
  final view = size ?? const Size(390, 2600);
  tester.view.physicalSize = view * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: NewEventScreen(
          creatorId: 'c1',
          events: EventRepo(api),
          creators: CreatorRepo(api: api),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('an event is not media', () {
    test('the venue types are the three the API names', () {
      expect(EventVenueType.values.map((v) => v.slug), [
        'physical',
        'virtual',
        'hybrid',
      ]);
      // The design's first card says "In Person"; `in_person` is refused.
      expect(
        EventVenueType.values.map((v) => v.slug),
        isNot(contains('in_person')),
      );
    });

    test('the body carries no field the API refuses', () {
      final body = _draft().toJson('c1');

      expect(body['venueType'], 'physical');
      expect(body['schedule'], {
        'startAt': '2026-10-10T09:00:00.000Z',
        'timezone': 'Africa/Lagos',
      });
      expect(body['registration'], {'required': true, 'capacity': 500});
      // Every one of these is refused as "property … should not exist".
      for (final field in [
        'seriesId',
        'publishAt',
        'scheduledAt',
        'sourceUploadId',
      ]) {
        expect(body.containsKey(field), isFalse, reason: field);
      }
    });

    test('an end date rides inside the schedule, not beside it', () {
      final body = _draft(endAt: DateTime.utc(2026, 10, 12, 9)).toJson('c1');
      final schedule = body['schedule']! as Map<String, dynamic>;

      expect(schedule['endAt'], '2026-10-12T09:00:00.000Z');
      // Flat `startsAt`/`endsAt` are refused.
      expect(body.containsKey('endAt'), isFalse);
      expect(body.containsKey('startsAt'), isFalse);
    });

    test('RSVP left off sends no registration block at all', () {
      final body = _draft(rsvp: false, capacity: null).toJson('c1');
      expect(body.containsKey('registration'), isFalse);
    });
  });

  group('what publishing needs', () {
    test('a description, always', () {
      expect(
        _draft(description: '  ').publishBlock,
        EventPublishBlock.description,
      );
    });

    test('an address and a city for anything physical', () {
      expect(
        _draft(location: const EventLocation(label: 'Lekki')).publishBlock,
        EventPublishBlock.address,
      );
      expect(
        _draft(
          location: const EventLocation(addressLine: '1 Admiralty Way'),
        ).publishBlock,
        EventPublishBlock.address,
      );
    });

    test('a meeting link for anything virtual', () {
      expect(
        _draft(
          venueType: EventVenueType.virtual,
          location: const EventLocation(),
        ).publishBlock,
        EventPublishBlock.meetingUrl,
      );
      // Hybrid wants both, and says so about the address first.
      expect(
        _draft(
          venueType: EventVenueType.hybrid,
          location: const EventLocation(),
        ).publishBlock,
        EventPublishBlock.address,
      );
      expect(
        _draft(
          venueType: EventVenueType.hybrid,
          location: const EventLocation(
            addressLine: '1 Admiralty Way',
            city: 'Lagos',
          ),
        ).publishBlock,
        EventPublishBlock.meetingUrl,
      );
    });

    test('a complete physical event is ready', () {
      expect(_draft().publishBlock, isNull);
    });
  });

  group('the repo', () {
    test('creating sends the draft and hands back the id', () async {
      final api = _FakeApi(
        body: const {
          'data': {'id': 'e1'},
        },
      );

      final id = await EventRepo(api).create(creatorId: 'c1', draft: _draft());

      expect(id, 'e1');
      expect(api.sent['/v1/content/calendar/events']!['creatorId'], 'c1');
    });

    test('publishing sends nothing, because nothing is read', () async {
      final api = _FakeApi(body: const {'data': {}});
      await EventRepo(api).publish('e1');

      // The route ignores whatever body it is handed — passing a schedule
      // would look like it worked.
      expect(api.sent['/v1/content/calendar/events/e1/publish'], isEmpty);
    });

    test('the cover goes through the content asset ticket', () async {
      final api = _FakeApi(
        body: const {
          'data': {
            'fileId': 'f1',
            'uploadUrl': 'https://s3.example.com/',
            'fields': {'key': 'quarantine/x'},
          },
        },
      );

      // The S3 leg is a real network call, so only the ticket is checked.
      try {
        await EventRepo(api).uploadCover(creatorId: 'c1', image: _swatch);
      } catch (_) {
        // The presigned POST goes nowhere in a test.
      }

      final body = api.sent['/v1/content/assets/upload-url']!;
      expect(body['category'], 'cover');
      expect(body['creatorId'], 'c1');
    });

    test('each publish refusal is named, not lumped together', () async {
      for (final (sentence, failure) in [
        (
          'Event description is required before publishing',
          EventFailure.needsDescription,
        ),
        (
          'Add a street address and city before publishing this event',
          EventFailure.needsAddress,
        ),
        (
          'Add a valid virtual meeting link before publishing this event',
          EventFailure.needsMeetingUrl,
        ),
        ('Invalid schedule', EventFailure.badSchedule),
      ]) {
        final api = _FakeApi(error: _refusal([sentence]));
        await expectLater(
          EventRepo(api).create(creatorId: 'c1', draft: _draft()),
          throwsA(
            isA<EventException>().having((e) => e.failure, sentence, failure),
          ),
        );
      }
    });
  });

  group('the screen', () {
    testWidgets('it asks for an event, not an upload', (tester) async {
      await _pumpScreen(tester);

      expect(find.text(AppStrings.newEventTitle), findsOneWidget);
      expect(find.text(AppStrings.newEventSubtitle), findsOneWidget);
      // Nothing is uploaded, so nothing offers to select a file.
      expect(find.byKey(const ValueKey('media-select')), findsNothing);
      expect(find.text(AppStrings.newEventPhysical), findsOneWidget);
      expect(find.text(AppStrings.newEventVirtual), findsOneWidget);
      expect(find.text(AppStrings.newEventHybrid), findsOneWidget);
    });

    testWidgets('publishing stays shut until the API would take it', (
      tester,
    ) async {
      await _pumpScreen(tester);

      PrimaryButton button() => tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('event-publish')),
      );
      expect(button().enabled, isFalse);

      await tester.enterText(
        find.byKey(const ValueKey('event-title')),
        'Encounter Conference 2026',
      );
      await tester.pump();
      // A title is enough to save a draft but not to publish.
      expect(button().enabled, isFalse);
      expect(find.text(AppStrings.newEventNeedsDescription), findsWidgets);

      await tester.enterText(
        find.byKey(const ValueKey('event-description')),
        'Three evenings of worship.',
      );
      await tester.pump();
      expect(button().enabled, isFalse);
      expect(find.text(AppStrings.newEventNeedsAddress), findsWidgets);

      await tester.enterText(
        find.byKey(const ValueKey('event-address')),
        '1 Admiralty Way',
      );
      await tester.enterText(find.byKey(const ValueKey('event-city')), 'Lagos');
      await tester.pump();
      expect(button().enabled, isTrue);
    });

    testWidgets('choosing Virtual swaps the address for a meeting link', (
      tester,
    ) async {
      await _pumpScreen(tester);

      expect(find.byKey(const ValueKey('event-address')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-meeting-url')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('event-type-virtual')));
      await tester.pump();

      expect(find.byKey(const ValueKey('event-address')), findsNothing);
      expect(find.byKey(const ValueKey('event-meeting-url')), findsOneWidget);
    });

    testWidgets('Hybrid asks for both', (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.byKey(const ValueKey('event-type-hybrid')));
      await tester.pump();

      expect(find.byKey(const ValueKey('event-address')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-meeting-url')), findsOneWidget);
    });

    testWidgets('capacity appears only while RSVP is on', (tester) async {
      await _pumpScreen(tester);

      expect(find.byKey(const ValueKey('event-capacity')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('event-rsvp')));
      await tester.pump();
      expect(find.byKey(const ValueKey('event-capacity')), findsNothing);
    });

    testWidgets('nothing overflows on a narrow phone', (tester) async {
      await _pumpScreen(tester, size: const Size(320, 2600));
      expect(tester.takeException(), isNull);
    });
  });
}
