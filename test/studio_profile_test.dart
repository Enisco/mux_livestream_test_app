import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/creator_asset_repo.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/creator/views/studio_profile_screen.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// The studio's own settings.
///
/// Reported from a device on 2026-11-03: *"I've filled all these Channel
/// Logo, Cover and About before already. Why is the settings asking me to
/// fill it again?"* — the switcher opened the **onboarding** chain, four
/// screens in sequence with every field empty. These tests pin the two
/// claims that made the difference: what the channel already has comes
/// back on screen, and nothing is written until Save.
class _FakeApi implements ApiService {
  _FakeApi({this.channel, this.failRead = false, this.failWrite = false});

  final Map<String, dynamic>? channel;
  final bool failRead;
  final bool failWrite;

  final List<(String, Object?)> patched = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (failRead) throw _boom(path);
    return _ok(path, {'data': channel ?? const <String, dynamic>{}});
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    patched.add((path, data));
    if (failWrite) throw _boom(path);
    return _ok(path, {'data': <String, dynamic>{}});
  }

  DioException _boom(String path) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 500,
    ),
  );

  Response<T> _ok<T>(String path, Object body) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: body as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Uploads without a network, and records that it was asked to.
class _FakeAssets implements CreatorAssetRepo {
  _FakeAssets({this.failure});

  static const fileId = 'file-new';
  final AssetUploadFailure? failure;
  final List<CreatorAssetKind> uploaded = [];

  @override
  Future<AssetUploadResult> upload({
    required String creatorId,
    required CreatorAssetKind kind,
    required PickedImage image,
  }) async {
    uploaded.add(kind);
    if (failure case final why?) return AssetUploadResult.failed(why);
    return AssetUploadResult.uploaded(fileId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const _channel = {
  'id': 'c1',
  'displayName': 'Food for Thought',
  'handle': 'food',
  'bio': 'A family church in Lagos.',
  'avatarKey': 'public/avatar/c1/logo.jpg',
  'bannerKey': 'public/banner/c1/cover.jpg',
};

Future<_FakeApi> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? channel = _channel,
  bool failRead = false,
  bool failWrite = false,
  _FakeAssets? assets,
  Future<PickResult> Function({required int maxBytes})? picker,
}) async {
  SharedPreferences.setMockInitialValues({});
  await LocalStorage.init();
  await LocalStorage.setString(LocalStorage.creatorIdKey, 'c1');

  tester.view.physicalSize = const Size(390 * 3, 1000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final api = _FakeApi(
    channel: channel,
    failRead: failRead,
    failWrite: failWrite,
  );
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: StudioProfileScreen(
          repo: CreatorRepo(api: api),
          assets: assets ?? _FakeAssets(),
          picker: picker,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

/// Stands in for the photo library.
Future<PickResult> Function({required int maxBytes}) _picker(
  PickedImage? image, {
  PickFailure? failure,
}) =>
    ({required int maxBytes}) async => failure != null
    ? PickResult.failed(failure)
    : image == null
    ? const PickResult.cancelled()
    : PickResult.picked(image);

/// A real 1x1 PNG: the preview decodes it, so junk bytes throw.
final _image = PickedImage(
  bytes: Uint8List.fromList(const [
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, //
    0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, //
    0, 0, 0, 13, 73, 68, 65, 84, 120, 218, 99, 252, 207, 192, 80, 15, //
    0, 4, 133, 1, 128, 132, 169, 140, 33, 0, 0, 0, 0, 73, 69, 78, 68, //
    174, 66, 96, 130,
  ]),
  filename: 'logo.png',
  mimeType: 'image/png',
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('what the channel already has comes back on screen', (
    tester,
  ) async {
    await _pump(tester);

    // The whole complaint: an About that was filled in months ago used to
    // open as an empty field on an onboarding screen.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('studio-profile-about')))
          .controller
          ?.text,
      'A family church in Lagos.',
    );
    expect(find.text('Food for Thought · @food'), findsOneWidget);
  });

  testWidgets('all three sit on one screen, not four in a row', (tester) async {
    await _pump(tester);

    expect(find.byKey(const ValueKey('studio-profile-cover')), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-profile-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-profile-about')), findsOneWidget);
  });

  testWidgets('an untouched form has nothing to save', (tester) async {
    final api = await _pump(tester);

    expect(
      tester
          .widget<PrimaryButton>(
            find.byKey(const ValueKey('studio-profile-save')),
          )
          .enabled,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('studio-profile-save')));
    await tester.pumpAndSettle();
    expect(api.patched, isEmpty);
  });

  testWidgets('editing the about text is what arms Save', (tester) async {
    await _pump(tester);

    await tester.enterText(
      find.byKey(const ValueKey('studio-profile-about')),
      'A family church in Lagos, since 1998.',
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<PrimaryButton>(
            find.byKey(const ValueKey('studio-profile-save')),
          )
          .enabled,
      isTrue,
    );
  });

  testWidgets('only what changed is sent', (tester) async {
    final api = await _pump(tester);

    await tester.enterText(
      find.byKey(const ValueKey('studio-profile-about')),
      'Now with a Thursday service.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-profile-save')));
    await tester.pumpAndSettle();

    final body = api.patched.single.$2 as Map<String, dynamic>;
    expect(body['bio'], 'Now with a Thursday service.');
    // The images were not touched, so no file id goes out claiming they
    // were — a resent id would re-promote a file for no reason.
    expect(body.containsKey('avatarFileId'), isFalse);
    expect(body.containsKey('bannerFileId'), isFalse);
  });

  testWidgets('an emptied about is cleared, not quietly ignored', (
    tester,
  ) async {
    // `updateCreatorProfile` used to drop an empty bio, so a creator could
    // never take their about text back down.
    final api = await _pump(tester);

    await tester.enterText(
      find.byKey(const ValueKey('studio-profile-about')),
      '',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-profile-save')));
    await tester.pumpAndSettle();

    expect((api.patched.single.$2 as Map<String, dynamic>)['bio'], '');
  });

  testWidgets('a picked image is uploaded but not saved until Save', (
    tester,
  ) async {
    // The point of a settings screen with a Save button: picking a photo
    // and backing out must leave the channel as it was. The object stays
    // in quarantine until a save references its id.
    final assets = _FakeAssets();
    final api = await _pump(tester, assets: assets, picker: _picker(_image));

    await tester.tap(find.byKey(const ValueKey('studio-profile-logo')));
    await tester.pumpAndSettle();

    expect(assets.uploaded, [CreatorAssetKind.avatar]);
    expect(api.patched, isEmpty);

    await tester.tap(find.byKey(const ValueKey('studio-profile-save')));
    await tester.pumpAndSettle();

    final body = api.patched.first.$2 as Map<String, dynamic>;
    expect(body['avatarFileId'], 'file-new');
    // And the about text, which nobody touched, does not ride along as an
    // edit of itself.
    expect(body.containsKey('bio'), isFalse);
  });

  testWidgets('an upload that failed arms nothing and says why', (
    tester,
  ) async {
    final api = await _pump(
      tester,
      assets: _FakeAssets(failure: AssetUploadFailure.network),
      picker: _picker(_image),
    );

    await tester.tap(find.byKey(const ValueKey('studio-profile-logo')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('studio-profile-problem')))
          .data,
      AppStrings.creatorImageOffline,
    );
    expect(
      tester
          .widget<PrimaryButton>(
            find.byKey(const ValueKey('studio-profile-save')),
          )
          .enabled,
      isFalse,
    );
    expect(api.patched, isEmpty);
  });

  testWidgets('a channel that could not be read offers a retry', (
    tester,
  ) async {
    await _pump(tester, failRead: true);

    expect(find.text(AppStrings.studioProfileFailed), findsOneWidget);
  });

  testWidgets('a save that failed says so and keeps the edit', (tester) async {
    await _pump(tester, failWrite: true);

    await tester.enterText(
      find.byKey(const ValueKey('studio-profile-about')),
      'Changed.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-profile-save')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('studio-profile-problem')))
          .data,
      AppStrings.studioProfileSaveFailed,
    );
    // The text is still there to try again with.
    expect(find.text('Changed.'), findsOneWidget);
  });

  testWidgets('a channel with nothing filled in invites all three', (
    tester,
  ) async {
    await _pump(
      tester,
      channel: const {'id': 'c1', 'displayName': 'New Studio', 'handle': 'new'},
    );

    expect(find.text(AppStrings.studioProfileNoCover), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('studio-profile-about')))
          .controller
          ?.text,
      isEmpty,
    );
  });
}
