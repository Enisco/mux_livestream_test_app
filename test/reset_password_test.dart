import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/features/auth/views/reset_password_screen.dart';
import 'package:test_app/shared/components/gtube_text_field.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// Finishing a password reset.
///
/// The flow used to stop at "check your inbox": the email carries a token and
/// `POST /v1/auth/password/reset` takes `{token, newPassword}`, but nothing in
/// the app could spend it, so anyone who forgot their password was simply
/// stuck. The contract here was read off staging — an 8–128 character bound
/// on the password, and one message, "Invalid or expired reset token.", for a
/// token that is spent, lapsed or never existed.
class _FakeApi implements ApiService {
  _FakeApi({this.error});

  final DioException? error;
  final List<Map<String, dynamic>> posted = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (error != null) throw error!;
    posted.add(data! as Map<String, dynamic>);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

DioException _refusal(Object body) => DioException(
  requestOptions: RequestOptions(path: '/v1/auth/password/reset'),
  response: Response(
    requestOptions: RequestOptions(path: '/v1/auth/password/reset'),
    statusCode: 400,
    data: {'success': false, 'data': null, 'error': body},
  ),
);

Future<_FakeApi> _pump(
  WidgetTester tester, {
  String? token,
  DioException? error,
}) async {
  final api = _FakeApi(error: error);
  await GetIt.instance.reset();
  GetIt.instance.registerSingleton<ApiService>(api);
  GetIt.instance.registerSingleton<TokenStorageService>(TokenStorageService());
  GetIt.instance.registerLazySingleton<AuthRepo>(AuthRepo.new);
  addTearDown(GetIt.instance.reset);

  tester.view.physicalSize = const Size(390 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (context) => MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: token == null
              ? AppRouter.resetPassword
              : AppRouter.resetPasswordWithToken(token),
          routes: [
            GoRoute(
              path: AppRouter.resetPassword,
              builder: (_, state) => ResetPasswordScreen(
                token: state.uri.queryParameters['token'],
              ),
            ),
            GoRoute(
              path: AppRouter.signIn,
              builder: (_, _) => const Text('SIGN IN'),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Future<void> _fill(
  WidgetTester tester, {
  String? code,
  required String password,
  String? confirm,
}) async {
  if (code != null) {
    await tester.enterText(find.byKey(const ValueKey('reset-token')), code);
  }
  await tester.enterText(
    find.byKey(const ValueKey('reset-password')),
    password,
  );
  await tester.enterText(
    find.byKey(const ValueKey('reset-confirm')),
    confirm ?? password,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a pasted code and a new password finish the reset', (
    tester,
  ) async {
    final api = await _pump(tester);
    await _fill(tester, code: 'tok_123', password: 'NewProbePass123!');

    await tester.tap(find.text(AppStrings.saveNewPassword));
    await tester.pumpAndSettle();

    expect(api.posted.single, {
      'token': 'tok_123',
      'newPassword': 'NewProbePass123!',
    });
    expect(find.text(AppStrings.passwordResetDone), findsOneWidget);
  });

  testWidgets('and then leads back to signing in', (tester) async {
    await _pump(tester);
    await _fill(tester, code: 'tok_123', password: 'NewProbePass123!');
    await tester.tap(find.text(AppStrings.saveNewPassword));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.backToSignIn));
    await tester.pumpAndSettle();
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets('a deep link fills the code in, and locks it', (tester) async {
    await _pump(tester, token: 'tok_from_link');

    final field = tester.widget<GTubeTextField>(
      find.byKey(const ValueKey('reset-token')),
    );
    expect(field.controller.text, 'tok_from_link');
    // Shown rather than hidden, so a refusal can be explained — but not
    // something anyone should be editing.
    expect(field.readOnly, isTrue);
  });

  testWidgets('a code the server refuses says what to do next', (tester) async {
    await _pump(
      tester,
      error: _refusal(const ['Invalid or expired reset token.']),
    );
    await _fill(tester, code: 'spent', password: 'NewProbePass123!');
    await tester.tap(find.text(AppStrings.saveNewPassword));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.resetTokenRejected), findsOneWidget);
    // And the form is still there to try again with.
    expect(find.text(AppStrings.saveNewPassword), findsOneWidget);
  });

  testWidgets('a validation refusal is shown as the server worded it', (
    tester,
  ) async {
    await _pump(
      tester,
      error: _refusal(const [
        'newPassword must be shorter than or equal to 128 characters',
      ]),
    );
    await _fill(tester, code: 'tok', password: 'NewProbePass123!');
    await tester.tap(find.text(AppStrings.saveNewPassword));
    await tester.pumpAndSettle();

    expect(find.textContaining('shorter than or equal to 128'), findsOneWidget);
  });

  group('the form refuses what the API would', () {
    testWidgets('a password under eight characters', (tester) async {
      final api = await _pump(tester);
      await _fill(tester, code: 'tok', password: 'short1');
      await tester.tap(find.text(AppStrings.saveNewPassword));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.passwordTooShort), findsOneWidget);
      expect(api.posted, isEmpty);
    });

    testWidgets('a password over 128', (tester) async {
      final api = await _pump(tester);
      await _fill(tester, code: 'tok', password: 'a' * 129);
      await tester.tap(find.text(AppStrings.saveNewPassword));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.passwordTooLong), findsOneWidget);
      expect(api.posted, isEmpty);
    });

    testWidgets('two passwords that disagree', (tester) async {
      final api = await _pump(tester);
      await _fill(
        tester,
        code: 'tok',
        password: 'NewProbePass123!',
        confirm: 'NewProbePass124!',
      );
      await tester.tap(find.text(AppStrings.saveNewPassword));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.passwordsDoNotMatch), findsOneWidget);
      expect(api.posted, isEmpty);
    });

    testWidgets('no code at all', (tester) async {
      final api = await _pump(tester);
      await _fill(tester, password: 'NewProbePass123!');
      await tester.tap(find.text(AppStrings.saveNewPassword));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.resetCodeRequired), findsOneWidget);
      expect(api.posted, isEmpty);
    });
  });
}
