import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/settings/repo/account_repo.dart';
import 'package:test_app/features/settings/views/language_screen.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// What the app should speak.
///
/// **Null is not English.** It means the viewer has not chosen, which is the
/// only state from which falling back to the device's own language is honest.
/// So "Match my device" is a real option that sends an explicit `null`, and
/// omitting the key — which is what a `?language` would do — would leave
/// whatever was there.
class _FakeApi implements ApiService {
  _FakeApi({this.fails = false});

  final bool fails;
  final List<({String path, Object? body})> patched = [];

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    patched.add((path: path, body: data));
    if (fails) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 500,
        ),
      );
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data:
          {
                'data': {'id': 'u1', 'language': (data as Map)['language']},
              }
              as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<_FakeApi> _pump(
  WidgetTester tester, {
  String? language,
  bool fails = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  await LocalStorage.init();
  await LocalStorage.cacheUser({
    'id': 'u1',
    'email': 'g@example.com',
    'language': ?language,
  });

  final api = _FakeApi(fails: fails);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: LanguageScreen(repo: AccountRepo(api: api)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  setUpAll(loadAppFonts);

  test('a stored tag reads as itself, and no choice reads as the device', () {
    expect(languageLabel(null), AppStrings.languageDevice);
    expect(languageLabel('  '), AppStrings.languageDevice);
    expect(languageLabel('en'), 'English');
    // One chosen on another client, or a region this build does not name.
    expect(languageLabel('en-NG'), 'en-NG');
  });

  testWidgets('no choice yet opens on "match my device"', (tester) async {
    await _pump(tester);

    expect(find.text(AppStrings.languageDevice), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('choosing English sends the tag', (tester) async {
    final api = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('language-English')));
    await tester.pumpAndSettle();

    expect(api.patched.single.path, '/v1/user/u1');
    expect(api.patched.single.body, {'language': 'en'});
    expect(LocalStorage.cachedLanguage, 'en');
  });

  testWidgets('going back to the device sends an explicit null', (
    tester,
  ) async {
    final api = await _pump(tester, language: 'en');

    await tester.tap(
      find.byKey(ValueKey('language-${AppStrings.languageDevice}')),
    );
    await tester.pumpAndSettle();

    expect(api.patched.single.body, containsPair('language', isNull));
    expect(LocalStorage.cachedLanguage, isNull);
  });

  testWidgets('a refused save springs back rather than lying', (tester) async {
    await _pump(tester, fails: true);

    await tester.tap(find.byKey(const ValueKey('language-English')));
    await tester.pumpAndSettle();

    // The row that was selected is still the selected one.
    expect(LocalStorage.cachedLanguage, isNull);
    expect(find.text(AppStrings.settingsSaveFailed), findsOneWidget);
  });

  testWidgets('choosing what is already chosen sends nothing', (tester) async {
    final api = await _pump(tester, language: 'en');

    await tester.tap(find.byKey(const ValueKey('language-English')));
    await tester.pumpAndSettle();

    expect(api.patched, isEmpty);
  });
}
