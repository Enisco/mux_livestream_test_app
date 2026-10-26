import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/settings/repo/account_repo.dart';
import 'package:test_app/features/settings/views/account_forms.dart';
import 'package:test_app/features/settings/views/language_screen.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// Changing an email address, a password and a language.
///
/// All three routes arrived on 2026-10-26
/// (`docs/mobile-api-gap-responses.md` §3.1, §3.2, §3.3). Three contract
/// details are pinned here because getting any of them wrong is invisible
/// until it strands a reader:
///
/// - the password change sends **`refreshToken`**, which is the only way the
///   backend can tell this session from the others and spare it;
/// - **`currentSessionRetained: false` means sign in again**, and must be
///   read rather than assumed;
/// - a language of **null is not English** — it clears the choice, and the
///   key has to be sent explicitly to do it.
class _FakeApi implements ApiService {
  _FakeApi({this.retainSession = true, this.failWith});

  final bool retainSession;
  final Response<dynamic>? failWith;

  final List<({String path, Object? body})> posted = [];
  final List<({String path, Object? body})> patched = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posted.add((path: path, body: data));
    if (failWith case final response?) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: response,
      );
    }
    if (path.endsWith('/password')) {
      return _ok(path, {
        'passwordChangedAt': '2026-10-26T09:00:00.000Z',
        'sessionsRevoked': 2,
        'currentSessionRetained': retainSession,
      });
    }
    if (path.endsWith('email-change')) {
      return _ok(path, {
        'challengeId': 'ch1',
        'expiresAt': '2026-10-26T09:10:00.000Z',
        'delivery': 'email',
        'resendAvailableAt': '2026-10-26T09:00:30.000Z',
        'maskedNewEmail': 'n•••w@example.com',
      });
    }
    return _ok(path, {'id': 'u1', 'email': 'new@example.com'});
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    patched.add((path: path, body: data));
    return _ok(path, {'id': 'u1', 'email': 'old@example.com'});
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

class _FakeTokens implements TokenStorageService {
  @override
  Future<String?> get refreshToken async => 'refresh-abc';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _seed() async {
  SharedPreferences.setMockInitialValues({});
  await LocalStorage.init();
  await LocalStorage.setString(
    LocalStorage.cachedUserKey,
    '{"id":"u1","email":"old@example.com","firstName":"A","lastName":"B"}',
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('the password change', () {
    test('sends the refresh token so this session survives', () async {
      await _seed();
      final api = _FakeApi();
      final result = await AccountRepo(
        api: api,
        tokens: _FakeTokens(),
      ).changePassword(currentPassword: 'old', newPassword: 'newpassword1');

      expect(api.posted.single.path, '/v1/user/me/password');
      expect(api.posted.single.body, {
        'currentPassword': 'old',
        'newPassword': 'newpassword1',
        'refreshToken': 'refresh-abc',
      });
      expect(result.currentSessionRetained, isTrue);
      expect(result.sessionsRevoked, 2);
    });

    test('and reports when it did not', () async {
      await _seed();
      final result = await AccountRepo(
        api: _FakeApi(retainSession: false),
        tokens: _FakeTokens(),
      ).changePassword(currentPassword: 'old', newPassword: 'newpassword1');

      // The next call will 401, so the screen must send them back to sign-in
      // rather than assume it survived.
      expect(result.currentSessionRetained, isFalse);
    });

    test('the new change date lands in the cache the menu reads', () async {
      // The one credential route that does not answer with a `User`. Without
      // folding its `passwordChangedAt` in by hand, the account menu went on
      // reporting the old date — or "never changed" — until the next profile
      // read.
      await _seed();
      expect(LocalStorage.cachedPasswordChangedAt, isNull);

      await AccountRepo(
        api: _FakeApi(),
        tokens: _FakeTokens(),
      ).changePassword(currentPassword: 'old', newPassword: 'newpassword1');

      expect(
        LocalStorage.cachedPasswordChangedAt,
        DateTime.parse('2026-10-26T09:00:00.000Z'),
      );
      // And nothing else about the account was dropped on the way.
      expect(LocalStorage.cachedEmail, 'old@example.com');
    });

    test('a wrong password is rejected, never retried', () async {
      await _seed();
      final api = _FakeApi(
        failWith: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 401,
          data: const {'error': 'Current password is incorrect'},
        ),
      );
      await expectLater(
        AccountRepo(
          api: api,
          tokens: _FakeTokens(),
        ).changePassword(currentPassword: 'wrong', newPassword: 'newpassword1'),
        throwsA(
          isA<AccountException>()
              .having((e) => e.failure, 'failure', AccountFailure.rejected)
              .having(
                (e) => e.message,
                'message',
                'Current password is incorrect',
              ),
        ),
      );
      expect(api.posted, hasLength(1));
    });

    test('a lockout carries when it lifts', () async {
      await _seed();
      final api = _FakeApi(
        failWith: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 409,
          data: const {
            'error': 'Too many attempts',
            'details': {'retryAt': '2026-10-26T09:15:00.000Z'},
          },
        ),
      );
      await expectLater(
        AccountRepo(
          api: api,
          tokens: _FakeTokens(),
        ).changePassword(currentPassword: 'wrong', newPassword: 'newpassword1'),
        throwsA(
          isA<AccountException>()
              .having((e) => e.failure, 'failure', AccountFailure.locked)
              .having((e) => e.retryAt, 'retryAt', isNotNull),
        ),
      );
    });
  });

  group('the email change', () {
    test('proves the password up front and decodes the challenge', () async {
      await _seed();
      final api = _FakeApi();
      final challenge = await AccountRepo(
        api: api,
      ).requestEmailChange(newEmail: '  NEW@Example.com ', password: 'hunter2');

      expect(api.posted.single.path, '/v1/user/me/email-change');
      expect(api.posted.single.body, {
        'newEmail': 'new@example.com',
        'password': 'hunter2',
      });
      // The code goes to the new address, so that is what the OTP screen
      // names — masked, from the server.
      expect(challenge.maskedDestination, 'n•••w@example.com');
      expect(challenge.challengeId, 'ch1');
    });

    test('verifying replaces the cached account', () async {
      await _seed();
      await AccountRepo(
        api: _FakeApi(),
      ).verifyEmailChange(challengeId: 'ch1', code: '123456');

      expect(LocalStorage.cachedEmail, 'new@example.com');
    });

    testWidgets('the form will not send without a password', (tester) async {
      await _seed();
      await _pump(tester, const ChangeEmailScreen());

      await tester.enterText(find.byType(TextField).at(1), 'new@example.com');
      await tester.tap(find.text(AppStrings.settingsUpdate));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.settingsPasswordRequired), findsOneWidget);
    });
  });

  group('language', () {
    test('null clears the choice rather than storing English', () async {
      await _seed();
      final api = _FakeApi();
      await AccountRepo(api: api).updateAccount(clearLanguage: true);

      expect(api.patched.single.body, {'language': null});
    });

    test('a tag is sent as given', () async {
      await _seed();
      final api = _FakeApi();
      await AccountRepo(api: api).updateAccount(language: 'en-NG');

      expect(api.patched.single.body, {'language': 'en-NG'});
    });

    test('the Account row names the state honestly', () {
      expect(languageLabel(null), AppStrings.languageDevice);
      expect(languageLabel('en'), 'English');
      // A tag this build does not name prints as itself rather than being
      // silently shown as English.
      expect(languageLabel('fr-CA'), 'fr-CA');
    });
  });
}
