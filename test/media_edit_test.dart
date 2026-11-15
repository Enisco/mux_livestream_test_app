// Editing a video or a piece of audio that is already filed.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/repo/media_upload_repo.dart';
import 'package:test_app/features/creator/views/new_media_screen.dart';
import 'package:test_app/features/creator/views/widgets/new_media_parts.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// A filed row, the way `GET /v1/media/{id}` answers one.
Map<String, dynamic> _row({
  String id = 'm1',
  String type = 'video',
  String status = 'ready',
  String title = 'Walking by Faith',
  String description = 'A message on trusting God.',
  List<String> categorySlugs = const ['sermons'],
  String visibility = 'public',
  String? thumbnailKey = 'media/thumbs/m1.jpg',
  String? scheduledAt,
  String? publishedAt,
  String updatedAt = '2026-11-14T09:12:44.120Z',
}) => {
  'data': {
    'id': id,
    'type': type,
    'status': status,
    'title': title,
    'description': description,
    'categorySlugs': categorySlugs,
    'visibility': visibility,
    'thumbnailKey': ?thumbnailKey,
    'scheduledAt': ?scheduledAt,
    'publishedAt': ?publishedAt,
    'updatedAt': updatedAt,
  },
};

class _FakeApi implements ApiService {
  _FakeApi({
    Map<String, Map<String, dynamic>>? bodies,
    this.getError = const [],
  }) : bodies = bodies ?? {};

  final Map<String, Map<String, dynamic>> bodies;

  /// Refusals for the read, taken one per call, so a retry can succeed.
  final List<DioException> getError;

  final List<String> paths = [];
  final Map<String, Map<String, dynamic>> sent = {};

  int get patches => paths.where((p) => p == '/v1/media/m1').length - reads;
  int reads = 0;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    if (path == '/v1/media/m1') {
      reads++;
      if (getError.isNotEmpty) throw getError.removeAt(0);
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          (bodies[path] ??
                  const {
                    'data': {
                      'data': [
                        {
                          'slug': 'sermons',
                          'name': 'Sermons',
                          'contentTypes': ['media'],
                        },
                        {
                          'slug': 'worship',
                          'name': 'Worship',
                          'contentTypes': ['media'],
                        },
                      ],
                    },
                  })
              as T,
    );
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    if (data is Map<String, dynamic>) sent[path] = data;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (bodies['PATCH $path'] ?? bodies[path] ?? _row()) as T,
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
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (bodies[path] ?? const <String, dynamic>{}) as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

DioException _fails({int status = 500}) => DioException(
  requestOptions: RequestOptions(path: '/v1/media/m1'),
  response: Response(
    requestOptions: RequestOptions(path: '/v1/media/m1'),
    statusCode: status,
    data: const {'success': false, 'error': 'nope'},
  ),
);

Future<_FakeApi> _openEditor(
  WidgetTester tester, {
  Map<String, dynamic>? row,
  MediaUploadKind kind = MediaUploadKind.video,
  List<DioException> getError = const [],
  Map<String, Map<String, dynamic>> bodies = const {},
  Size size = const Size(390, 1400),
  bool use24h = false,
}) async {
  final api = _FakeApi(
    bodies: {'/v1/media/m1': row ?? _row(), ...bodies},
    getError: getError,
  );
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        // The time wheel reads this.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
          child: child!,
        ),
        home: NewMediaScreen(
          kind: kind,
          creatorId: 'c1',
          editMediaId: 'm1',
          uploads: MediaUploadRepo(api),
          creators: CreatorRepo(api: api),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

/// The key sits on the `CreatorTextField`; the `TextField` holding the
/// controller is inside it.
String _text(WidgetTester tester, Key key) => tester
    .widget<TextField>(
      find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
    )
    .controller!
    .text;

void main() {
  setUpAll(loadAppFonts);

  group('a row as the creator filed it', () {
    test('every editable field is read back', () {
      final filed = FiledMedia.fromJson(
        _row(
              scheduledAt: '2026-12-01T09:00:00.000Z',
              publishedAt: '2026-11-10T09:00:00.000Z',
            )['data']!
            as Map<String, dynamic>,
      );

      expect(filed.id, 'm1');
      expect(filed.title, 'Walking by Faith');
      expect(filed.description, 'A message on trusting God.');
      expect(filed.categorySlugs, ['sermons']);
      expect(filed.visibility, MediaVisibility.public);
      expect(filed.thumbnailKey, 'media/thumbs/m1.jpg');
      expect(filed.kind, MediaUploadKind.video);
      expect(filed.status, MediaStatus.ready);
      // Both instants arrive UTC and are read locally, because that is what
      // the form shows and the picker edits.
      expect(filed.scheduledAt!.isUtc, isFalse);
      expect(filed.publishedAt!.isUtc, isFalse);
      // The upload's half of the row survives the widening.
      expect(filed.updatedAt, DateTime.utc(2026, 11, 14, 9, 12, 44, 120));
    });

    test('a visibility this client cannot read is null, not private', () {
      final filed = FiledMedia.fromJson(
        _row(visibility: 'embargoed')['data']! as Map<String, dynamic>,
      );

      expect(filed.visibility, isNull);
    });

    test('a status this client has not heard of costs nothing', () {
      final filed = FiledMedia.fromJson({'id': 'm1', 'status': 'quarantined'});

      expect(filed.status, MediaStatus.unknown);
      expect(filed.isUsable, isTrue);
      // Unknown is not a reason to refuse an edit.
      expect(filed.isEditable, isTrue);
    });

    test('only draft means no file is in yet', () {
      // What the form says about the file turns on this, and `draft` is the
      // one status that means there is none: *"No source yet, or the source
      // was removed."*
      expect(MediaStatus.of('draft'), MediaStatus.draft);
      for (final raw in ['processing', 'ready', 'scheduled', 'published']) {
        expect(MediaStatus.of(raw), isNot(MediaStatus.draft), reason: raw);
      }
    });

    test('the three states nobody may edit are refused', () {
      for (final status in [
        MediaStatus.archived,
        MediaStatus.blocked,
        MediaStatus.underReview,
      ]) {
        final filed = FiledMedia.fromJson({'id': 'm1', 'status': status.slug});
        expect(filed.isEditable, isFalse, reason: status.slug);
      }
    });

    test('having been published once closes scheduling for good', () {
      // The route refuses `scheduledAt` for media that has ever been
      // published, *even if it was unpublished since* — so `status` alone
      // cannot answer this and `publishedAt` has to.
      final unpublished = FiledMedia.fromJson(
        _row(status: 'ready', publishedAt: '2026-11-10T09:00:00.000Z')['data']!
            as Map<String, dynamic>,
      );
      expect(unpublished.status, MediaStatus.ready);
      expect(unpublished.canBeScheduled, isFalse);

      final neverPublished = FiledMedia.fromJson(
        _row(status: 'ready')['data']! as Map<String, dynamic>,
      );
      expect(neverPublished.canBeScheduled, isTrue);

      final live = FiledMedia.fromJson(
        _row(status: 'published')['data']! as Map<String, dynamic>,
      );
      expect(live.canBeScheduled, isFalse);
    });
  });

  group('what the thumbnail well is given', () {
    // Both sources need an environment to resolve against, or every answer
    // here is null and the guard under test cannot be seen at all.
    setUp(
      () => dotenv.testLoad(
        fileInput: 'CDN_BASE_URL=https://cdn.test\nBASE_URL=https://api.test',
      ),
    );

    FiledMedia filed({
      String status = 'ready',
      String visibility = 'public',
      String? thumbnailKey,
    }) => FiledMedia.fromJson(
      _row(
            status: status,
            visibility: visibility,
            thumbnailKey: thumbnailKey,
          )['data']!
          as Map<String, dynamic>,
    );

    test('an uploaded thumbnail wins, whatever state the row is in', () {
      expect(
        filed(
          status: 'draft',
          thumbnailKey: 'media/thumbs/m1.jpg',
        ).thumbnailUrl,
        'https://cdn.test/media/thumbs/m1.jpg',
      );
    });

    test('a published, public row falls back to the Mux still', () {
      expect(
        filed(status: 'published').thumbnailUrl,
        'https://api.test/v1/public/media/m1/assets/thumbnail',
      );
    });

    test('an unpublished row is given nothing at all', () {
      // The public asset proxy is only generated for public, published
      // media.
      for (final status in ['draft', 'processing', 'ready', 'scheduled']) {
        expect(filed(status: status).thumbnailUrl, isNull, reason: status);
      }
    });

    test('nor is a published row that is not public', () {
      expect(
        filed(status: 'published', visibility: 'unlisted').thumbnailUrl,
        isNull,
      );
    });
  });

  group('opening the editor', () {
    testWidgets('it fills the form from what is filed', (tester) async {
      await _openEditor(tester);

      expect(_text(tester, const ValueKey('media-title')), 'Walking by Faith');
      expect(
        _text(tester, const ValueKey('media-description')),
        'A message on trusting God.',
      );
      // Categories come back as names, not slugs.
      expect(find.text('Sermons'), findsOneWidget);
      expect(find.text(AppStrings.visibilityPublic), findsOneWidget);
    });

    testWidgets('it says it is editing, not uploading', (tester) async {
      await _openEditor(tester);

      expect(find.text(AppStrings.editVideoTitle), findsOneWidget);
      expect(find.text(AppStrings.newVideoTitle), findsNothing);
      expect(find.byKey(const ValueKey('media-save-edit')), findsOneWidget);
      // Publishing is not an edit's business.
      expect(find.byKey(const ValueKey('media-publish')), findsNothing);
      expect(find.byKey(const ValueKey('media-draft')), findsNothing);
    });

    testWidgets('audio is named audio', (tester) async {
      await _openEditor(
        tester,
        row: _row(type: 'music'),
        kind: MediaUploadKind.music,
      );

      expect(find.text(AppStrings.editAudioTitle), findsOneWidget);
      expect(find.text(AppStrings.editVideoTitle), findsNothing);
    });

    testWidgets('the row says what it is, over what the caller guessed', (
      tester,
    ) async {
      // The studio hands over a kind read from a list that can be minutes
      // old. The row's own type is the one the copy should follow.
      await _openEditor(
        tester,
        row: _row(type: 'music'),
        kind: MediaUploadKind.video,
      );

      expect(find.text(AppStrings.editAudioTitle), findsOneWidget);
      expect(find.text(AppStrings.editVideoTitle), findsNothing);
    });

    testWidgets('a visibility the client cannot read shows no value', (
      tester,
    ) async {
      final api = await _openEditor(tester, row: _row(visibility: 'embargoed'));

      // The hint, not a guess. Showing "Private" for a public video and
      // then sending it is how a title fix takes it off the channel.
      expect(find.text(AppStrings.newMediaVisibilityHint), findsOneWidget);
      expect(find.text(AppStrings.visibilityPrivate), findsNothing);

      await tester.tap(find.byKey(const ValueKey('media-save-edit')));
      await tester.pumpAndSettle();

      expect(api.sent['/v1/media/m1']!.containsKey('visibility'), isFalse);
    });

    testWidgets('and its sheet waits for a choice before Done works', (
      tester,
    ) async {
      await _openEditor(tester, row: _row(visibility: 'embargoed'));

      await tester.tap(find.byKey(const ValueKey('media-visibility')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<PrimaryButton>(
              find.byKey(const ValueKey('visibility-confirm')),
            )
            .enabled,
        isFalse,
      );

      await tester.tap(find.byKey(const ValueKey('visibility-public')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<PrimaryButton>(
              find.byKey(const ValueKey('visibility-confirm')),
            )
            .enabled,
        isTrue,
      );
    });

    testWidgets('the file is not on the form, and it says where it is', (
      tester,
    ) async {
      await _openEditor(tester);

      // Neither the picker nor the progress card: this row's file is up,
      // and replacing it is not something this screen can do.
      expect(find.byType(MediaPickCard), findsNothing);
      expect(find.byType(MediaFileCard), findsNothing);
      expect(find.text(AppStrings.editMediaFileOnWeb), findsOneWidget);
    });

    testWidgets('a row with no file yet says so', (tester) async {
      await _openEditor(tester, row: _row(status: 'draft'));

      expect(find.text(AppStrings.editMediaNoFile), findsOneWidget);
    });

    testWidgets('a row whose file would not process says so', (tester) async {
      await _openEditor(tester, row: _row(status: 'failed'));

      expect(find.text(AppStrings.editMediaFailed), findsOneWidget);
    });

    testWidgets('a row nobody may edit is closed, with no retry', (
      tester,
    ) async {
      await _openEditor(tester, row: _row(status: 'archived'));

      expect(find.text(AppStrings.editMediaNotEditable), findsOneWidget);
      expect(find.byKey(const ValueKey('media-open-retry')), findsNothing);
      expect(find.byKey(const ValueKey('media-save-edit')), findsNothing);
    });

    testWidgets('a read that failed can be tried again', (tester) async {
      final api = await _openEditor(tester, getError: [_fails()]);

      expect(find.text(AppStrings.newMediaRejected), findsOneWidget);
      expect(find.byKey(const ValueKey('media-title')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('media-open-retry')));
      await tester.pumpAndSettle();

      expect(api.reads, 2);
      expect(_text(tester, const ValueKey('media-title')), 'Walking by Faith');
    });

    // One screen per test: pumping a second identical tree keeps the first
    // one's State, so `initState` — and the read — never runs again.
    testWidgets('a row that is gone is not retried', (tester) async {
      await _openEditor(tester, getError: [_fails(status: 404)]);

      expect(find.text(AppStrings.editMediaGone), findsOneWidget);
      expect(find.byKey(const ValueKey('media-open-retry')), findsNothing);
    });

    testWidgets('a row that is not yours is not retried', (tester) async {
      await _openEditor(tester, getError: [_fails(status: 403)]);

      expect(find.text(AppStrings.editMediaNotYours), findsOneWidget);
      expect(find.byKey(const ValueKey('media-open-retry')), findsNothing);
    });
  });

  group('saving an edit', () {
    testWidgets('one PATCH, and nothing about publishing', (tester) async {
      final api = await _openEditor(tester);

      await tester.enterText(
        find.byKey(const ValueKey('media-title')),
        'Walking by Faith, Part 2',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('media-save-edit')));
      await tester.pumpAndSettle();

      expect(api.sent['/v1/media/m1'], {
        'title': 'Walking by Faith, Part 2',
        'description': 'A message on trusting God.',
        'categorySlugs': ['sermons'],
        'visibility': 'public',
      });
      // No publish, no unpublish, no source call: a correction leaves the
      // row exactly as published or as draft as it already was.
      expect(api.paths, isNot(contains('/v1/media/m1/publish')));
      expect(api.paths, isNot(contains('/v1/media/m1/unpublish')));
      expect(api.paths, isNot(contains('/v1/media/m1/source')));
      expect(api.patches, 1);
    });

    testWidgets('the thumbnail already filed is never resent', (tester) async {
      final api = await _openEditor(tester);

      await tester.tap(find.byKey(const ValueKey('media-save-edit')));
      await tester.pumpAndSettle();

      // Sending `thumbnailFileId: null` would *drop* the custom thumbnail,
      // and no control on this form asks for that.
      expect(api.sent['/v1/media/m1']!.containsKey('thumbnailFileId'), isFalse);
      expect(api.paths, isNot(contains('/v1/media/thumbnail/upload-url')));
    });

    testWidgets('clearing every category clears them on the row', (
      tester,
    ) async {
      final api = await _openEditor(tester);

      await tester.tap(find.byKey(const ValueKey('media-category')));
      await tester.pumpAndSettle();
      // Unpick the one that is on.
      await tester.tap(find.text('Sermons').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('media-save-edit')));
      await tester.pumpAndSettle();

      // An absent key would keep the old list. The empty list is the
      // creator removing the last topic, and has to be sent.
      expect(api.sent['/v1/media/m1']!['categorySlugs'], isEmpty);
    });

    testWidgets('a title longer than the API takes never leaves the phone', (
      tester,
    ) async {
      final api = await _openEditor(tester);

      await tester.enterText(
        find.byKey(const ValueKey('media-title')),
        'x' * 181,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('media-save-edit')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.newMediaTitleTooLong), findsOneWidget);
      expect(api.patches, 0);
    });

    testWidgets('an emptied title disables the save rather than wiping it', (
      tester,
    ) async {
      await _openEditor(tester);

      await tester.enterText(find.byKey(const ValueKey('media-title')), '');
      await tester.pump();

      final button = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('media-save-edit')),
      );
      expect(button.enabled, isFalse);
    });

    testWidgets('changing who can see it sends the new value', (tester) async {
      final api = await _openEditor(tester);

      await tester.tap(find.byKey(const ValueKey('media-visibility')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('visibility-unlisted')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('visibility-confirm')));
      await tester.pumpAndSettle();

      // And says plainly that it cannot hand over the link, because only
      // publish mints a share token.
      expect(find.text(AppStrings.visibilityUnlistedNoLink), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('media-save-edit')));
      await tester.pumpAndSettle();

      expect(api.sent['/v1/media/m1']!['visibility'], 'unlisted');
    });

    testWidgets('the sheet offers the three values and no others', (
      tester,
    ) async {
      await _openEditor(tester);

      await tester.tap(find.byKey(const ValueKey('media-visibility')));
      await tester.pumpAndSettle();

      for (final value in MediaVisibility.values) {
        expect(
          find.byKey(ValueKey('visibility-${value.slug}')),
          findsOneWidget,
        );
      }
      // "No others" has to be counted, not assumed: the three above being
      // present says nothing about a fourth sitting beside them, and a
      // value the backend does not accept would be refused on save with no
      // hint as to which field caused it.
      const controls = {
        'visibility-confirm',
        'visibility-cancel',
        'visibility-close',
      };
      final options = find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('visibility-') &&
            !controls.contains(key.value);
      });
      expect(
        tester.widgetList(options).length,
        MediaVisibility.values.length,
        reason: 'the sheet grew an option the enum does not have',
      );
    });

    testWidgets('a row filed without a description can still be fixed', (
      tester,
    ) async {
      // Requiring one here would grey out Save with no explanation, so a
      // creator could not correct an old row's title without first writing
      // a description nobody asked them for.
      final api = await _openEditor(tester, row: _row(description: ''));

      final button = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('media-save-edit')),
      );
      expect(button.enabled, isTrue);

      await tester.tap(find.byKey(const ValueKey('media-save-edit')));
      await tester.pumpAndSettle();

      // Empty and still empty: the key is left out rather than sent as
      // `''`, which would risk a refusal to no purpose.
      expect(api.sent['/v1/media/m1']!.containsKey('description'), isFalse);
      expect(api.patches, 1);
    });

    testWidgets('an emptied description is sent, not silently kept', (
      tester,
    ) async {
      final api = await _openEditor(tester);

      await tester.enterText(
        find.byKey(const ValueKey('media-description')),
        '',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('media-save-edit')));
      await tester.pumpAndSettle();

      // An absent key would keep the old words. If the API refuses `''`
      // the creator is told — which beats dropping the change in silence.
      expect(api.sent['/v1/media/m1']!['description'], '');
    });
  });

  group('the schedule', () {
    testWidgets('a row that has published before is told, not offered', (
      tester,
    ) async {
      await _openEditor(
        tester,
        row: _row(status: 'published', publishedAt: '2026-11-10T09:00:00.000Z'),
      );

      expect(find.byKey(const ValueKey('media-schedule-date')), findsNothing);
      expect(find.text(AppStrings.newMediaScheduleClosed), findsOneWidget);
    });

    testWidgets('a row that never has gets the two fields', (tester) async {
      await _openEditor(tester, row: _row(status: 'ready'));

      expect(find.byKey(const ValueKey('media-schedule-date')), findsOneWidget);
      expect(find.byKey(const ValueKey('media-schedule-time')), findsOneWidget);
      // Both of them, empty: a date without a time is not a schedule.
      expect(find.text(AppStrings.newMediaScheduleHint), findsNWidgets(2));
      // Nothing to remove until there is something scheduled.
      expect(find.byKey(const ValueKey('media-schedule-clear')), findsNothing);
    });

    testWidgets('setting one sends it, as UTC', (tester) async {
      final api = await _openEditor(tester, row: _row(status: 'ready'));

      // Opening the wheel and accepting it takes the default the picker
      // starts on: the next round hour, which is always in the future.
      await tester.tap(find.byKey(const ValueKey('media-schedule-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.newMediaDone));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('media-schedule-clear')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.newMediaScheduleNote), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('media-save-edit')));
      await tester.pumpAndSettle();

      final sent = api.sent['/v1/media/m1']!['scheduledAt'] as String;
      final at = DateTime.parse(sent);
      expect(at.isUtc, isTrue);
      expect(at.isAfter(DateTime.now().toUtc()), isTrue);
    });

    testWidgets('a moment moved into the past is marked, not just refused', (
      tester,
    ) async {
      // The picker floors the *date* wheel at today but leaves the clock
      // free, so an earlier hour on today's date is one notch away.
      await _openEditor(tester, row: _row(status: 'ready'), use24h: true);

      await tester.tap(find.byKey(const ValueKey('media-schedule-time')));
      await tester.pumpAndSettle();

      // The wheel opens on the next round hour, between one and sixty
      // minutes ahead.
      final hours = find.byType(ListWheelScrollView).first;
      final gesture = await tester.startGesture(tester.getCenter(hours));
      await gesture.moveBy(const Offset(0, 16));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveBy(const Offset(0, 16));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.newMediaDone));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('media-schedule-past')),
        findsOneWidget,
        reason: 'the field has to say so where the creator is looking',
      );
      final button = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('media-save-edit')),
      );
      expect(button.enabled, isFalse);
    });

    testWidgets('a schedule that merely arrived stale is not an error', (
      tester,
    ) async {
      // The creator did not do this and the save does not resend it, so
      // marking the field red would accuse them of a mistake they have not
      // made — and greying out Save would trap the row.
      final past = DateTime.now()
          .subtract(const Duration(days: 2))
          .toUtc()
          .toIso8601String();
      await _openEditor(
        tester,
        row: _row(status: 'scheduled', scheduledAt: past),
      );

      expect(find.byKey(const ValueKey('media-schedule-past')), findsNothing);
      final button = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('media-save-edit')),
      );
      expect(button.enabled, isTrue);
    });

    testWidgets('an unchanged schedule is not resent', (tester) async {
      // A schedule filed last week may now be in the past.
      final past = DateTime.now()
          .subtract(const Duration(days: 2))
          .toUtc()
          .toIso8601String();
      final api = await _openEditor(
        tester,
        row: _row(status: 'scheduled', scheduledAt: past),
      );

      await tester.tap(find.byKey(const ValueKey('media-save-edit')));
      await tester.pumpAndSettle();

      expect(api.sent['/v1/media/m1']!.containsKey('scheduledAt'), isFalse);
    });

    testWidgets('removing a schedule sends an explicit null', (tester) async {
      final at = DateTime.now()
          .add(const Duration(days: 3))
          .toUtc()
          .toIso8601String();
      final api = await _openEditor(
        tester,
        row: _row(status: 'scheduled', scheduledAt: at),
      );

      expect(
        find.byKey(const ValueKey('media-schedule-clear')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('media-schedule-clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('media-save-edit')));
      await tester.pumpAndSettle();

      final body = api.sent['/v1/media/m1']!;
      // An absent key would keep the schedule. Only a null unschedules.
      expect(body.containsKey('scheduledAt'), isTrue);
      expect(body['scheduledAt'], isNull);
    });
  });

  group('the form fits a phone', () {
    // The fields are added in edit mode — visibility, the two schedule
    // wheels, the notes — and a Row of two date fields is the one that can
    // run off the side.
    testWidgets('on a 390-wide screen, with everything on', (tester) async {
      final at = DateTime.now()
          .add(const Duration(days: 3))
          .toUtc()
          .toIso8601String();
      await _openEditor(
        tester,
        row: _row(status: 'scheduled', scheduledAt: at, visibility: 'unlisted'),
        size: const Size(390, 844),
      );

      expect(tester.takeException(), isNull);
      // And the whole form is reachable by scrolling.
      await tester.drag(
        find.byKey(const ValueKey('media-title')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('media-schedule-date')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and on the narrowest phone the design allows', (tester) async {
      final at = DateTime.now()
          .add(const Duration(days: 3))
          .toUtc()
          .toIso8601String();
      await _openEditor(
        tester,
        row: _row(status: 'scheduled', scheduledAt: at),
        size: const Size(320, 844),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the upload form is untouched by any of this', (tester) async {
      // One screen, two modes: the mode that was already shipping must
      // still draw its file card and its two publish controls.
      final api = _FakeApi();
      tester.view.physicalSize = const Size(390 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (context) => MaterialApp(
            home: NewMediaScreen(
              kind: MediaUploadKind.video,
              creatorId: 'c1',
              uploads: MediaUploadRepo(api),
              creators: CreatorRepo(api: api),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.newVideoTitle), findsOneWidget);
      expect(find.byType(MediaPickCard), findsOneWidget);
      expect(find.byKey(const ValueKey('media-publish')), findsOneWidget);
      expect(find.byKey(const ValueKey('media-draft')), findsOneWidget);
      // And none of the edit-only fields.
      expect(find.byKey(const ValueKey('media-visibility')), findsNothing);
      expect(find.byKey(const ValueKey('media-schedule-date')), findsNothing);
      // It never reads a row, because there is none to read.
      expect(api.reads, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('the repo on its own', () {
    test('an edit keeps empties that an upload leaves out', () async {
      final api = _FakeApi();
      final repo = MediaUploadRepo(api);

      await repo.saveEdits(
        mediaId: 'm1',
        title: 'T',
        description: 'D',
        visibility: MediaVisibility.private,
      );
      // `categorySlugs: []` is sent, because on an edit an empty list is
      // the creator clearing it.
      expect(api.sent['/v1/media/m1'], {
        'title': 'T',
        'description': 'D',
        'categorySlugs': <String>[],
        'visibility': 'private',
      });

      // A null description is "leave it alone", and leaves out the key.
      await repo.saveEdits(
        mediaId: 'm1',
        title: 'T',
        visibility: MediaVisibility.private,
      );
      expect(api.sent['/v1/media/m1']!.containsKey('description'), isFalse);
    });

    test('a schedule goes out as UTC', () async {
      final api = _FakeApi();
      final repo = MediaUploadRepo(api);
      final at = DateTime(2026, 12, 1, 9);

      await repo.saveEdits(
        mediaId: 'm1',
        title: 'T',
        description: 'D',
        visibility: MediaVisibility.public,
        scheduledAt: at,
      );

      expect(
        api.sent['/v1/media/m1']!['scheduledAt'],
        at.toUtc().toIso8601String(),
      );
    });

    test(
      'clearSchedule wins over a value, so a clear is never ambiguous',
      () async {
        final api = _FakeApi();
        final repo = MediaUploadRepo(api);

        await repo.saveEdits(
          mediaId: 'm1',
          title: 'T',
          description: 'D',
          visibility: MediaVisibility.public,
          scheduledAt: DateTime(2026, 12, 1, 9),
          clearSchedule: true,
        );

        expect(api.sent['/v1/media/m1']!['scheduledAt'], isNull);
      },
    );

    test('a new thumbnail is named, an old one never resent', () async {
      final api = _FakeApi();
      final repo = MediaUploadRepo(api);

      await repo.saveEdits(
        mediaId: 'm1',
        title: 'T',
        description: 'D',
        visibility: MediaVisibility.public,
        thumbnailFileId: 'f9',
      );
      expect(api.sent['/v1/media/m1']!['thumbnailFileId'], 'f9');

      await repo.saveEdits(
        mediaId: 'm1',
        title: 'T',
        description: 'D',
        visibility: MediaVisibility.public,
      );
      // Null would *drop* the custom thumbnail, so the key goes away.
      expect(api.sent['/v1/media/m1']!.containsKey('thumbnailFileId'), isFalse);
    });

    test('the screen uploads a new thumbnail before it saves', () {
      // Asserted on the source, not by driving the picker: the picker
      // decodes and measures the image, and image decoding never settles on
      // a widget test's fake clock.
      final screen = File(
        'lib/features/creator/views/new_media_screen.dart',
      ).readAsStringSync();
      final edit = screen.substring(
        screen.indexOf('Future<void> _saveEdit()'),
        screen.indexOf('// ---- publishing'),
      );

      final upload = edit.indexOf('uploadThumbnail(');
      final save = edit.indexOf('saveEdits(');
      expect(upload, greaterThan(-1));
      expect(save, greaterThan(upload));
      // And both are inside one try, so a thumbnail that will not land
      // stops the save rather than half-finishing it.
      expect(edit.indexOf('try {'), lessThan(upload));
    });

    test('a 200 with an unreadable body is still a save', () async {
      // Turning a saved edit into "something went wrong" over a field
      // nobody reads would send a creator back to redo work that is done.
      final api = _FakeApi(
        bodies: {
          'PATCH /v1/media/m1': const {'success': true, 'data': null},
        },
      );

      final saved = await MediaUploadRepo(api).saveEdits(
        mediaId: 'm1',
        title: 'T',
        description: 'D',
        visibility: MediaVisibility.public,
      );

      expect(saved, isNull);
      expect(api.sent['/v1/media/m1']!['title'], 'T');
    });

    test('a visibility the client could not read is left alone', () async {
      // Guessing here is how a save that fixed a title would take a public
      // video off the channel.
      final api = _FakeApi();

      await MediaUploadRepo(
        api,
      ).saveEdits(mediaId: 'm1', title: 'T', description: 'D');

      expect(api.sent['/v1/media/m1']!.containsKey('visibility'), isFalse);
    });

    test('it answers the saved row, so a caller can reseed', () async {
      final repo = MediaUploadRepo(_FakeApi());

      final saved = await repo.saveEdits(
        mediaId: 'm1',
        title: 'T',
        description: 'D',
        visibility: MediaVisibility.public,
      );

      expect(saved!.id, 'm1');
      expect(saved.updatedAt, isNotNull);
    });
  });
}
