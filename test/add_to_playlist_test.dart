import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/library/repo/playlist_repo.dart';
import 'package:test_app/features/library/views/add_to_playlist_sheet.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// `POST .../playlists/search` and `POST .../playlists/:id/items`.
class _FakeApi implements ApiService {
  _FakeApi({
    this.playlists = const ['Sunday mornings', 'For the drive'],
    this.duplicate = false,
    this.addFails = false,
    this.listFails = false,
    this.counts,
    this.ids,
  });

  final List<String> playlists;

  /// `itemCount` per row, defaulting to its index + 1.
  final List<int>? counts;

  /// Ids per row, for the malformed case.
  final List<String>? ids;

  /// The playlist already holds it — `CONFLICT`, per the media guide.
  final bool duplicate;
  final bool addFails;
  final bool listFails;

  final List<({String path, Object? body})> posted = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posted.add((path: path, body: data));

    if (path.contains('/items')) {
      if (duplicate) throw _refusal(path, 409);
      if (addFails) throw _refusal(path, 500);
      return _ok(path, const <String, dynamic>{});
    }
    if (path.contains('search')) {
      if (listFails) throw _refusal(path, 500);
      return _ok(path, {
        'data': [
          for (var i = 0; i < playlists.length; i++)
            {
              'id': ids == null ? 'p${i + 1}' : ids![i],
              'title': playlists[i],
              'itemCount': counts == null ? i + 1 : counts![i],
              'visibility': 'private',
            },
        ],
      });
    }
    // The create.
    return _ok(path, {
      'id': 'new1',
      'title': (data as Map)['title'],
      'itemCount': 0,
      'visibility': 'private',
      'items': const [],
    });
  }

  DioException _refusal(String path, int code) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response(
      requestOptions: RequestOptions(path: path),
      statusCode: code,
    ),
  );

  Response<T> _ok<T>(String path, Object body) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: {'data': body} as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AddToPlaylistResult? _result;

Future<_FakeApi> _open(WidgetTester tester, {_FakeApi? api}) async {
  final fake = api ?? _FakeApi();
  _result = null;
  tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                _result = await showAddToPlaylistSheet(
                  context,
                  mediaId: 'm1',
                  repo: PlaylistRepo(api: fake),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  setUpAll(loadAppFonts);

  group('choosing where it goes', () {
    testWidgets('the sheet lists the reader own playlists', (tester) async {
      await _open(tester);
      expect(find.text('Sunday mornings'), findsOneWidget);
      expect(find.text('For the drive'), findsOneWidget);
      expect(find.text(AppStrings.playlistPickNew), findsOneWidget);
    });

    testWidgets('and says how many are in each', (tester) async {
      await _open(tester);
      expect(find.text('1 item'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
    });

    /// The whole point of the change. "Add to playlist" pushed the
    /// playlists *browse* screen, which has no idea what is being added,
    /// so a reader could tap a playlist, or make one, and nothing was
    /// ever put in it.
    testWidgets('tapping one actually adds the media to it', (tester) async {
      final api = await _open(tester);

      await tester.tap(find.byKey(const ValueKey('add-to-p1')));
      await tester.pumpAndSettle();

      final add = api.posted.where((c) => c.path.contains('/items')).single;
      expect(add.path, '/v1/media/playlists/p1/items');
      expect(add.body, {'mediaId': 'm1'});
      expect(_result?.playlistName, 'Sunday mornings');
      expect(_result?.alreadyIn, isFalse);
    });

    testWidgets('and closes with something to tell the reader', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('add-to-p2')));
      await tester.pumpAndSettle();

      expect(_result?.message, AppStrings.playlistPickAdded('For the drive'));
      expect(find.text('For the drive'), findsNothing);
    });
  });

  group('making one on the spot', () {
    testWidgets('creates it and drops the media straight in', (tester) async {
      final api = await _open(tester);

      await tester.tap(find.byKey(const ValueKey('add-to-new-playlist')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Night shift');
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.playlistCreate));
      await tester.pumpAndSettle();

      // There is no reason to make a playlist from here and then have to
      // go and find it again.
      expect(
        api.posted.map((c) => c.path),
        containsAllInOrder(<String>[
          '/v1/media/playlists',
          '/v1/media/playlists/new1/items',
        ]),
      );
      expect(_result?.playlistName, 'Night shift');
    });

    testWidgets('a playlist that was made but not filled says the truth', (
      tester,
    ) async {
      // The create worked; only the add failed. "That did not save" would
      // be a lie, and the reader would make the playlist a second time.
      await _open(tester, api: _FakeApi(addFails: true));

      await tester.tap(find.byKey(const ValueKey('add-to-new-playlist')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Night shift');
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.playlistCreate));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.playlistAddFailed), findsOneWidget);
      expect(find.text(AppStrings.playlistSaveFailed), findsNothing);
      expect(_result, isNull);
    });

    testWidgets('and backing out of the form adds nothing', (tester) async {
      final api = await _open(tester);

      await tester.tap(find.byKey(const ValueKey('add-to-new-playlist')));
      await tester.pumpAndSettle();
      // The form's own back arrow — it draws `GTubeBackButton`, not a
      // material one, so `pageBack()` finds nothing to tap.
      await tester.tap(find.byType(GTubeBackButton));
      await tester.pumpAndSettle();

      expect(api.posted.where((c) => c.path.contains('/items')), isEmpty);
      expect(find.text(AppStrings.playlistPickNew), findsOneWidget);
    });
  });

  group('what goes wrong', () {
    testWidgets('a duplicate is not an error', (tester) async {
      // `CONFLICT` — "Media is already in this playlist". The reader
      // wanted it in there and it is in there.
      await _open(tester, api: _FakeApi(duplicate: true));

      await tester.tap(find.byKey(const ValueKey('add-to-p1')));
      await tester.pumpAndSettle();

      expect(_result?.alreadyIn, isTrue);
      expect(
        _result?.message,
        AppStrings.playlistPickAlreadyIn('Sunday mornings'),
      );
    });

    testWidgets('a real refusal keeps the sheet open and says so', (
      tester,
    ) async {
      await _open(tester, api: _FakeApi(addFails: true));

      await tester.tap(find.byKey(const ValueKey('add-to-p1')));
      await tester.pumpAndSettle();

      // Closing on a failure would look exactly like success.
      expect(find.text('Sunday mornings'), findsOneWidget);
      expect(find.text(AppStrings.playlistAddFailed), findsOneWidget);
    });

    testWidgets('a list that will not load offers a retry', (tester) async {
      await _open(tester, api: _FakeApi(listFails: true));
      expect(find.text(AppStrings.playlistPickFailed), findsOneWidget);
      expect(find.text(AppStrings.tryAgain), findsOneWidget);
    });

    testWidgets('and no playlists at all still offers to make one', (
      tester,
    ) async {
      await _open(tester, api: _FakeApi(playlists: const []));
      expect(find.text(AppStrings.playlistPickEmpty), findsOneWidget);
      expect(find.text(AppStrings.playlistPickNew), findsOneWidget);
    });

    testWidgets('a full playlist says so before the tap, not after', (
      tester,
    ) async {
      // The guide: "surface the limit in the add sheet rather than
      // failing on submit". `PlaylistRepo.maxItems` had been declared and
      // read nowhere.
      final api = await _open(
        tester,
        api: _FakeApi(
          playlists: const ['Everything'],
          counts: const [PlaylistRepo.maxItems],
        ),
      );

      expect(find.text(AppStrings.playlistPickFull), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('add-to-p1')));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.playlistPickFullNote(PlaylistRepo.maxItems)),
        findsOneWidget,
      );
      expect(api.posted.where((c) => c.path.contains('/items')), isEmpty);
      expect(_result, isNull);
    });

    testWidgets('and a row with no id is not offered as a destination', (
      tester,
    ) async {
      // It would post to a malformed path, and an empty id is also the
      // New playlist row's busy marker.
      await _open(
        tester,
        api: _FakeApi(playlists: const ['Broken'], ids: const ['']),
      );
      expect(find.text('Broken'), findsNothing);
      expect(find.text(AppStrings.playlistPickEmpty), findsOneWidget);
    });
  });
}
