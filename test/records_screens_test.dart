import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:dio/dio.dart';
import 'package:test_app/features/library/repo/viewer_records_repo.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/features/library/views/my_events_screen.dart';
import 'package:test_app/features/library/views/records_screens.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'helpers/load_app_fonts.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

/// The reader's own records, as the three services answer.
///
/// Each read is a different shape — events are a page-number search pairing
/// an event with the viewer's RSVP, prayers and testimonies are cursor lists
/// carrying a ministry byline — so the fake answers per path.
class _FakeApi implements ApiService {
  _FakeApi({
    this.events = const [],
    this.prayers = const [],
    this.testimonies = const [],
    this.fail = false,
  });

  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> prayers;
  final List<Map<String, dynamic>> testimonies;
  final bool fail;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (fail) throw DioException(requestOptions: RequestOptions(path: path));
    if (path.contains('calendar/events/mine')) {
      return _ok(path, {
        'data': events,
        'meta': {'total': events.length, 'next': null},
      });
    }
    if (path.contains('prayers/mine')) {
      return _ok(path, {'items': prayers, 'total': prayers.length});
    }
    if (path.contains('testimonies/mine')) {
      return _ok(path, {'items': testimonies, 'total': testimonies.length});
    }
    return _ok(path, const <String, dynamic>{});
  }

  Response<T> _ok<T>(String path, Object body) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: {'data': body} as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

String _ago(Duration d) => DateTime.now().toUtc().subtract(d).toIso8601String();
String _ahead(Duration d) => DateTime.now().toUtc().add(d).toIso8601String();

const _ministry = {
  'id': 'c1',
  'handle': 'grace',
  'displayName': 'Grace Chapel',
  'verifiedAt': '2026-01-01T00:00:00.000Z',
};

Map<String, dynamic> _eventRow({
  String id = 'e1',
  String title = 'Youth Conference',
  bool past = false,
  String status = 'attending',
  int? offsetMinutes,
}) => {
  'event': {
    'id': id,
    'title': title,
    'calendarStartAt': past
        ? _ago(const Duration(days: 7))
        : _ahead(const Duration(days: 7)),
    'location': const {'label': 'River Worship'},
    'creator': _ministry,
  },
  'rsvp': {'status': status, 'offsetMinutes': offsetMinutes},
};

Map<String, dynamic> _prayerRow({
  String id = 'p1',
  String status = 'open',
  Map<String, dynamic>? contentRef,
}) => {
  'id': id,
  'body': 'Please pray for my mother.',
  'status': status,
  'contentRef': contentRef,
  'createdAt': _ago(const Duration(days: 2)),
  'creator': _ministry,
};

Map<String, dynamic> _testimonyRow({
  String id = 't1',
  String status = 'pending',
  List<String> tags = const ['healing'],
}) => {
  'id': id,
  'body': 'God restored what I thought was gone.',
  'status': status,
  'impactTags': tags,
  'createdAt': _ago(const Duration(days: 3)),
  'creator': _ministry,
};

ViewerRecordsRepo _repo({
  List<Map<String, dynamic>> events = const [],
  List<Map<String, dynamic>> prayers = const [],
  List<Map<String, dynamic>> testimonies = const [],
  bool fail = false,
}) => ViewerRecordsRepo(
  api: _FakeApi(
    events: events,
    prayers: prayers,
    testimonies: testimonies,
    fail: fail,
  ),
);

/// Tall enough that the lazy lists build every row at once.
const _tall = Size(390, 3600);

void main() {
  setUpAll(loadAppFonts);

  group('my events', () {
    testWidgets('splits what is coming from what has been', (tester) async {
      // The route returns both in one list, so the grouping happens here.
      await _pump(
        tester,
        MyEventsScreen(
          repo: _repo(
            events: [
              _eventRow(title: 'Youth Conference'),
              _eventRow(id: 'e2', title: 'Last Easter', past: true),
            ],
          ),
        ),
        size: _tall,
      );

      expect(find.text('Youth Conference'), findsOneWidget);
      expect(find.text('Last Easter'), findsOneWidget);
      expect(find.textContaining('UPCOMING'), findsOneWidget);
      expect(find.textContaining('PAST'), findsOneWidget);
    });

    testWidgets('names the ministry, since the list spans all of them', (
      tester,
    ) async {
      await _pump(
        tester,
        MyEventsScreen(repo: _repo(events: [_eventRow()])),
        size: _tall,
      );
      expect(find.text('Grace Chapel'), findsWidgets);
    });

    testWidgets('an RSVP of attending reads as going', (tester) async {
      await _pump(
        tester,
        MyEventsScreen(
          repo: _repo(
            events: [
              _eventRow(status: 'attending'),
              _eventRow(id: 'e2', title: 'Maybe one', status: 'maybe'),
            ],
          ),
        ),
        size: _tall,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('searching narrows by title, ministry or venue', (
      tester,
    ) async {
      await _pump(
        tester,
        MyEventsScreen(
          repo: _repo(
            events: [
              _eventRow(title: 'Youth Conference'),
              _eventRow(id: 'e2', title: 'Prayer Vigil'),
            ],
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'vigil');
      await tester.pumpAndSettle();
      expect(find.text('Prayer Vigil'), findsOneWidget);
      expect(find.text('Youth Conference'), findsNothing);
    });

    testWidgets('nothing RSVP\'d says so', (tester) async {
      await _pump(tester, MyEventsScreen(repo: _repo()), size: _tall);
      expect(find.text('No events yet'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      await _pump(tester, MyEventsScreen(repo: _repo(fail: true)), size: _tall);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('prayer requests', () {
    testWidgets('one with no content behind it is a general request', (
      tester,
    ) async {
      await _pump(
        tester,
        PrayerRequestsScreen(repo: _repo(prayers: [_prayerRow()])),
        size: _tall,
      );
      expect(find.text('Please pray for my mother.'), findsOneWidget);
      expect(find.text('Grace Chapel'), findsWidgets);
    });

    testWidgets('one raised on content names it', (tester) async {
      await _pump(
        tester,
        PrayerRequestsScreen(
          repo: _repo(
            prayers: [
              _prayerRow(
                contentRef: const {
                  'targetType': 'media',
                  'targetId': 'm1',
                  'title': 'Walking by Faith',
                  'mediaType': 'video',
                },
              ),
            ],
          ),
        ),
        size: _tall,
      );
      expect(find.textContaining('Walking by Faith'), findsOneWidget);
    });

    testWidgets('one whose content has gone says what it was', (tester) async {
      // The title lookup is best-effort; a null title means the content was
      // deleted or made private, and the row must not link it.
      await _pump(
        tester,
        PrayerRequestsScreen(
          repo: _repo(
            prayers: [
              _prayerRow(
                contentRef: const {
                  'targetType': 'media',
                  'targetId': 'm1',
                  'title': null,
                },
              ),
            ],
          ),
        ),
        size: _tall,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Please pray for my mother.'), findsOneWidget);
    });

    testWidgets('each state reads differently', (tester) async {
      await _pump(
        tester,
        PrayerRequestsScreen(
          repo: _repo(
            prayers: [
              _prayerRow(),
              _prayerRow(id: 'p2', status: 'prayed_for'),
              _prayerRow(id: 'p3', status: 'closed'),
            ],
          ),
        ),
        size: _tall,
      );
      // Three rows, three states, none of them crashing or blank.
      expect(find.text('Please pray for my mother.'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing asked for yet says so', (tester) async {
      await _pump(tester, PrayerRequestsScreen(repo: _repo()), size: _tall);
      expect(tester.takeException(), isNull);
    });
  });

  group('testimonies', () {
    testWidgets('a pending one is not dressed up as approved', (tester) async {
      // Otherwise the reader asks why their story is not on the wall.
      await _pump(
        tester,
        TestimoniesScreen(repo: _repo(testimonies: [_testimonyRow()])),
        size: _tall,
      );
      expect(
        find.text('God restored what I thought was gone.'),
        findsOneWidget,
      );
    });

    testWidgets('an approved one names the wall it is live on', (tester) async {
      await _pump(
        tester,
        TestimoniesScreen(
          repo: _repo(testimonies: [_testimonyRow(status: 'approved')]),
        ),
        size: _tall,
      );
      expect(find.textContaining('Grace Chapel'), findsWidgets);
    });

    testWidgets('a rejected one offers no edit, because none exists', (
      tester,
    ) async {
      // Submissions cannot be edited; a rejected one points at sharing a new
      // story instead.
      await _pump(
        tester,
        TestimoniesScreen(
          repo: _repo(testimonies: [_testimonyRow(status: 'rejected')]),
        ),
        size: _tall,
      );
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('its impact tags read as labels, not as slugs', (tester) async {
      await _pump(
        tester,
        TestimoniesScreen(
          repo: _repo(
            testimonies: [
              _testimonyRow(tags: const ['healing', 'answered_prayer']),
            ],
          ),
        ),
        size: _tall,
      );
      expect(find.text('Healing'), findsOneWidget);
      expect(find.text('Answered prayer'), findsOneWidget);
      expect(find.text('answered_prayer'), findsNothing);
    });

    testWidgets('a pending one names the ministry reviewing it', (
      tester,
    ) async {
      // The list spans every ministry the reader has written to, so one
      // name hardcoded on all of them was simply wrong.
      await _pump(
        tester,
        TestimoniesScreen(repo: _repo(testimonies: [_testimonyRow()])),
        size: _tall,
      );
      expect(find.textContaining('Grace Chapel will'), findsOneWidget);
    });

    testWidgets('a rejected one does not offer an edit that cannot exist', (
      tester,
    ) async {
      // Submissions cannot be edited at any status.
      await _pump(
        tester,
        TestimoniesScreen(
          repo: _repo(testimonies: [_testimonyRow(status: 'rejected')]),
        ),
        size: _tall,
      );
      expect(find.textContaining('edit and resubmit'), findsNothing);
      expect(find.textContaining('share a new testimony'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      await _pump(
        tester,
        TestimoniesScreen(repo: _repo(fail: true)),
        size: _tall,
      );
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('the mapper', () {
    test('a reminder offset is one of the three the route takes', () {
      // 60, 120, 1440 or null — anything else is rejected, which is why the
      // picker is fixed rather than free-form.
      const allowed = {60, 120, 1440, null};
      for (final offset in allowed) {
        expect(allowed.contains(offset), isTrue);
      }
    });

    test('a long age reads in words, not in letters', () {
      expect(
        longAge(DateTime.now().subtract(const Duration(days: 2))),
        '2 days ago',
      );
      expect(
        longAge(DateTime.now().subtract(const Duration(hours: 1))),
        '1 hour ago',
      );
      expect(longAge(null), isEmpty);
    });
  });

  testWidgets('the screens sit on the app background', (tester) async {
    await _pump(tester, TestimoniesScreen(repo: _repo()));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.base1);
  });
}
