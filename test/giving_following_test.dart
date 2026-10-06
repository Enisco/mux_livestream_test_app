import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/features/library/repo/viewer_records_repo.dart';
import 'package:dio/dio.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/library/views/giving_screen.dart';
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
  await tester.pump();
}

/// Tall enough that the lazy lists build every row at once.
const _tall = Size(390, 4000);

/// The donor-giving routes as staging answers them today: not at all.
class _MissingApi implements ApiService {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async => throw DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 404,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// What the guide says they will answer once they exist.
class _GivingApi implements ApiService {
  _GivingApi({this.empty = false});

  final bool empty;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path.contains('summary')) {
      return _ok(path, {
        'availableYears': [2026],
        'giftCount': empty ? 0 : 2,
        'ministryCount': empty ? 0 : 1,
        'totalUsdCents': empty ? 0 : 14500,
        'totalsByCurrency': empty
            ? []
            : [
                {'currency': 'NGN', 'amount': 225000},
              ],
      });
    }
    return _ok(path, {
      'items': empty
          ? []
          : [
              {
                'id': 'g1',
                'recipientName': 'Grace Chapel',
                'fundName': 'General Fund',
                'createdAt': '2026-06-06T10:00:00.000Z',
                'charge': {'currency': 'NGN', 'amount': 225000},
                'amountUsdCents': 14500,
              },
            ],
      'nextCursor': null,
    });
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

void main() {
  setUpAll(loadAppFonts);

  group('giving', () {
    testWidgets('says plainly that the routes are not there', (tester) async {
      // `GET /v1/payment/giving/me/summary` and `…/me/gifts` are both
      // documented and both answer `Cannot GET` on staging. The screen is
      // wired, not stubbed — it loads, fails, and offers a retry rather than
      // showing gifts nobody gave.
      await _pump(
        tester,
        GivingScreen(repo: ViewerRecordsRepo(api: _MissingApi())),
        size: _tall,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a year the reader did give in reads from the summary', (
      tester,
    ) async {
      await _pump(
        tester,
        GivingScreen(repo: ViewerRecordsRepo(api: _GivingApi())),
        size: _tall,
      );

      expect(find.textContaining('2 gifts'), findsOneWidget);
      expect(find.text('JUNE 2026'), findsOneWidget);
    });

    testWidgets('one currency is the headline, the dollar value beneath', (
      tester,
    ) async {
      // Gifts are not charged in USD; both figures are shown.
      await _pump(
        tester,
        GivingScreen(repo: ViewerRecordsRepo(api: _GivingApi())),
        size: _tall,
      );
      expect(find.textContaining('NGN'), findsWidgets);
    });

    testWidgets('a year with nothing in it says so', (tester) async {
      await _pump(
        tester,
        GivingScreen(repo: ViewerRecordsRepo(api: _GivingApi(empty: true))),
        size: _tall,
      );
      expect(find.text('No givings yet'), findsOneWidget);
    });

    testWidgets('nothing overflows on a narrow phone', (tester) async {
      await _pump(
        tester,
        GivingScreen(repo: ViewerRecordsRepo(api: _GivingApi())),
        size: const Size(320, 4000),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
