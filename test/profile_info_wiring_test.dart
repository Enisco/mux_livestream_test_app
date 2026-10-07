import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/settings/repo/account_repo.dart';
import 'package:test_app/features/settings/views/account_forms.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// Changing your own name and photo.
///
/// The auth guide lists `PATCH /v1/user/{id}` and the avatar pair as "not yet
/// client-integrated — treat as unverified", so the shapes below are what
/// staging answered on 2026-10-07, not what the guide says. The route takes
/// `firstName`, `lastName` and `phone` and **refuses** `email`, `password`
/// and `displayName`, which is why this screen writes only a name.
class _FakeApi implements ApiService {
  _FakeApi({this.failPatch = false});

  final bool failPatch;
  final List<({String path, Object? body})> patched = [];
  final List<({String path, Object? body})> posted = [];

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (failPatch) {
      throw DioException(requestOptions: RequestOptions(path: path));
    }
    patched.add((path: path, body: data));
    final body = data as Map<String, dynamic>;
    return _ok(path, {
      'id': 'u1',
      'email': 'ayomide.john@mail.com',
      'firstName': body['firstName'],
      'lastName': body['lastName'],
    });
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posted.add((path: path, body: data));
    if (path.contains('upload-url')) {
      return _ok(path, {
        'fileId': 'f1',
        'uploadUrl': 'https://s3.example/',
        'fields': {'key': 'quarantine/avatar/u1/a.png'},
        'constraints': {'maxSizeBytes': 2097152},
      });
    }
    return _ok(path, {'id': 'u1', 'avatarKey': 'public/avatar/u1/a.png'});
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

Future<_FakeApi> _pump(WidgetTester tester, {bool failPatch = false}) async {
  SharedPreferences.setMockInitialValues({});
  await LocalStorage.init();
  await LocalStorage.setString(
    LocalStorage.cachedUserKey,
    '{"id":"u1","firstName":"Ayomide","lastName":"John",'
    '"email":"ayomide.john@mail.com"}',
  );

  final api = _FakeApi(failPatch: failPatch);
  GetIt.instance
    ..allowReassignment = true
    ..registerSingleton<ApiService>(api);
  addTearDown(GetIt.instance.reset);

  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: const ProfileInfoScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Update writes the name to the account route', (tester) async {
    final api = await _pump(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Ayo');
    await tester.enterText(find.byType(TextField).at(1), 'Johnson');
    await tester.tap(find.text(AppStrings.settingsUpdate));
    await tester.pumpAndSettle();

    expect(api.patched.single.path, '/v1/user/u1');
    expect(api.patched.single.body, {
      'firstName': 'Ayo',
      'lastName': 'Johnson',
    });
    // Not a snackbar saying it was not wired.
    expect(find.textContaining('not wired'), findsNothing);
  });

  testWidgets('and caches what the route answered', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Ayo');
    await tester.enterText(find.byType(TextField).at(1), 'Johnson');
    await tester.tap(find.text(AppStrings.settingsUpdate));
    await tester.pumpAndSettle();

    // The account menu behind this reads the cache, so a write that does not
    // replace it leaves the old name on screen until the next login.
    expect(LocalStorage.cachedFullName, 'Ayo Johnson');
  });

  testWidgets('a refused write says so and stays put', (tester) async {
    await _pump(tester, failPatch: true);

    await tester.enterText(find.byType(TextField).at(0), 'Ayo');
    await tester.enterText(find.byType(TextField).at(1), 'Johnson');
    await tester.tap(find.text(AppStrings.settingsUpdate));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.settingsSaveFailed), findsOneWidget);
    expect(LocalStorage.cachedFullName, 'Ayomide John');
  });

  testWidgets('an invalid name is never sent', (tester) async {
    final api = await _pump(tester);

    await tester.enterText(find.byType(TextField).at(0), '');
    await tester.tap(find.text(AppStrings.settingsUpdate));
    await tester.pumpAndSettle();

    expect(api.patched, isEmpty);
  });

  group('the avatar pair', () {
    test('tickets, uploads and then confirms', () async {
      // Confirming is what moves the key out of `quarantine/` — an upload
      // that is not confirmed leaves the account with no photo at all.
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      final api = _FakeApi();
      var sentTo = '';
      final result = await AccountRepo(
        api: api,
        send:
            ({
              required uploadUrl,
              required fields,
              required bytes,
              required filename,
            }) async => sentTo = uploadUrl,
      ).uploadAvatar(_png(4));

      expect(sentTo, 'https://s3.example/');

      expect(result.fileId, 'f1');
      expect(api.posted.map((p) => p.path), [
        '/v1/user/avatar/upload-url',
        '/v1/user/avatar/confirm',
      ]);
      expect(api.posted.first.body, {
        'filename': 'a.png',
        'mimeType': 'image/png',
        'size': 4,
      });
      expect(api.posted.last.body, {'fileId': 'f1'});
      expect(LocalStorage.cachedAvatarKey, 'public/avatar/u1/a.png');
    });

    test('an oversized photo never leaves the device', () async {
      // The ticket route answers 500, not 400, when `size` is over the
      // ceiling, so an oversized file cannot be told from an outage by status.
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      final api = _FakeApi();
      final result = await AccountRepo(
        api: api,
        send:
            ({
              required uploadUrl,
              required fields,
              required bytes,
              required filename,
            }) async => fail('nothing should reach S3'),
      ).uploadAvatar(_png(AccountRepo.avatarMaxBytes + 1));

      expect(result.fileId, isNull);
      expect(api.posted, isEmpty);
    });
  });
}

/// A stand-in of a given size; nothing reads the bytes, only their length —
/// the presigned policy carries `content-length-range: N,N`.
PickedImage _png(int bytes) => PickedImage(
  bytes: Uint8List(bytes),
  filename: 'a.png',
  mimeType: 'image/png',
);
