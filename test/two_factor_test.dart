import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/settings/repo/account_repo.dart';
import 'package:test_app/features/settings/views/two_factor_screens.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// Two-factor, as the backend shipped it on 2026-10-26.
///
/// **This replaced a TOTP flow.** The four screens it used to test described a
/// QR code, a secret and recovery codes; none of that exists and none of it
/// ever will — the second factor is a code emailed to the address on the
/// account. See `docs/mobile-api-gap-responses.md` §3.5.
///
/// The asymmetry is the thing worth pinning: enabling takes **no password**
/// (the emailed code is the proof, and proves codes arrive), disabling takes
/// **the current password** (it is the direction an attacker wants).
class _FakeApi implements ApiService {
  _FakeApi({this.failDisable = false});

  final bool failDisable;
  final List<({String path, Object? body})> posted = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posted.add((path: path, body: data));
    if (path.contains('disable') && failDisable) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 401,
          data: const {'error': 'Current password is incorrect'},
        ),
      );
    }
    if (path.contains('enable') && !path.contains('verify')) {
      return _ok(path, {
        'challengeId': 'ch1',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
        'delivery': 'email',
        'resendAvailableAt': DateTime.now()
            .add(const Duration(seconds: 30))
            .toIso8601String(),
        'maskedEmail': 'g•••e@example.com',
      });
    }
    return _ok(path, {
      'id': 'u1',
      'email': 'g@example.com',
      'twoFactorEnabled': !path.contains('disable'),
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

Future<_FakeApi> _pump(
  WidgetTester tester, {
  bool enabled = false,
  bool failDisable = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  await LocalStorage.init();
  await LocalStorage.setString(
    LocalStorage.cachedUserKey,
    '{"id":"u1","email":"g@example.com","twoFactorEnabled":$enabled}',
  );

  final api = _FakeApi(failDisable: failDisable);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: TwoFactorScreen(repo: AccountRepo(api: api)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('nothing on it mentions an authenticator app', (tester) async {
    // The TOTP wording went with the TOTP screens. If any of this comes back,
    // the screen is describing a feature the platform does not have.
    await _pump(tester);

    for (final word in ['QR', 'authenticator', 'Authy', 'recovery', 'secret']) {
      expect(
        find.textContaining(word, findRichText: true),
        findsNothing,
        reason: word,
      );
    }
  });

  testWidgets('reads the switch off the account, not a constant', (
    tester,
  ) async {
    await _pump(tester, enabled: true);
    expect(
      tester
          .widget<Switch>(find.byKey(const ValueKey('two-factor-switch')))
          .value,
      isTrue,
    );
  });

  testWidgets('an account that never chose still reads on', (tester) async {
    // The second factor used to be platform-wide, so existing accounts
    // default to on rather than silently getting weaker on deploy.
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await LocalStorage.setString(
      LocalStorage.cachedUserKey,
      '{"id":"u1","email":"g@example.com"}',
    );
    expect(LocalStorage.cachedTwoFactorEnabled, isTrue);
  });

  testWidgets('turning it on asks for no password', (tester) async {
    final api = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('two-factor-switch')));
    await tester.pumpAndSettle();

    final call = api.posted.single;
    expect(call.path, '/v1/user/me/two-factor/enable');
    expect(call.body, isEmpty);
    // It goes straight to the OTP screen, which names the masked address.
    expect(
      find.textContaining('g•••e@example.com', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('turning it off asks for one', (tester) async {
    final api = await _pump(tester, enabled: true);

    await tester.tap(find.byKey(const ValueKey('two-factor-switch')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.twoFactorTurnOffTitle), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('two-factor-password')),
      'hunter2',
    );
    await tester.tap(find.text(AppStrings.twoFactorTurnOff));
    await tester.pumpAndSettle();

    expect(api.posted.single.path, '/v1/user/me/two-factor/disable');
    expect(api.posted.single.body, {'password': 'hunter2'});
  });

  testWidgets('a wrong password leaves it on, in the server\'s words', (
    tester,
  ) async {
    await _pump(tester, enabled: true, failDisable: true);

    await tester.tap(find.byKey(const ValueKey('two-factor-switch')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('two-factor-password')),
      'wrong',
    );
    await tester.tap(find.text(AppStrings.twoFactorTurnOff));
    await tester.pumpAndSettle();

    expect(find.text('Current password is incorrect'), findsOneWidget);
    expect(
      tester
          .widget<Switch>(find.byKey(const ValueKey('two-factor-switch')))
          .value,
      isTrue,
    );
  });

  testWidgets('backing out of the prompt changes nothing', (tester) async {
    final api = await _pump(tester, enabled: true);

    await tester.tap(find.byKey(const ValueKey('two-factor-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.notNow));
    await tester.pumpAndSettle();

    expect(api.posted, isEmpty);
    expect(
      tester
          .widget<Switch>(find.byKey(const ValueKey('two-factor-switch')))
          .value,
      isTrue,
    );
  });
}
