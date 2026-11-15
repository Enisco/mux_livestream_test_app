import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/repo/media_upload_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/creator/views/new_media_screen.dart';
import 'package:test_app/features/creator/views/widgets/go_live_sheet.dart';
import 'package:test_app/features/creator/views/widgets/new_media_parts.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// `POST /v1/media/request-upload` exactly as staging answers it.
Map<String, dynamic> _ticketBody({String target = 'ios'}) => {
  'data': {
    'uploadId': 'up_123',
    'uploadUrl': 'https://direct-uploads.mux.com/upload/up_123?token=x',
    'expiresAt': '2026-09-19T11:03:45.387Z',
    'method': 'PUT',
    'headers': <String, dynamic>{},
    'chunkedUpload': true,
    'resumable': true,
    'maxChunkSizeBytes': 8388608,
    'recommendedPartSizeBytes': 8388608,
    'playbackPolicy': 'signed',
    'constraints': {
      'allowedMimeTypes': [
        'video/mp4',
        if (target == 'android') 'video/webm',
        'video/quicktime',
        'video/x-m4v',
      ],
      'maxSizeBytes': 5368709120,
    },
  },
};

const _track = PickedMediaFile(
  path: '/tmp/sample.mp3',
  filename: 'sample.mp3',
  mimeType: 'audio/mpeg',
  size: 103070,
);

const _file = PickedMediaFile(
  path: '/tmp/walking-by-faith.mp4',
  filename: 'walking-by-faith.mp4',
  mimeType: 'video/mp4',
  size: 1288490188,
);

class _FakeApi implements ApiService {
  _FakeApi({this.body, this.error, Map<String, Map<String, dynamic>>? bodies})
    : bodies = bodies ?? {};

  Map<String, dynamic>? body;
  DioException? error;

  /// Per-route answers, for a flow that touches more than one route.
  /// Falls back to [body] for anything not named here.
  final Map<String, Map<String, dynamic>> bodies;

  /// Refusals queued per route, taken one per call. A draft-first upload
  /// recovers from the first 409 and succeeds on the second attempt, so a
  /// single [error] cannot express it.
  final Map<String, List<DioException>> refusals = {};

  final List<String> paths = [];
  final Map<String, Map<String, dynamic>> sent = {};

  Map<String, dynamic> _answer(String path) =>
      bodies[path] ?? body ?? const <String, dynamic>{};

  void _maybeRefuse(String path) {
    final queued = refusals[path];
    if (queued != null && queued.isNotEmpty) throw queued.removeAt(0);
    if (error != null) throw error!;
  }

  /// The category list, unless the route was named in [bodies] — reading a
  /// draft back is a GET too.
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    _maybeRefuse(path);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          (bodies[path] ??
                  const {
                    'data': {
                      'data': [
                        {'slug': 'sermons', 'name': 'Sermons'},
                      ],
                    },
                  })
              as T,
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
    _maybeRefuse(path);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: _answer(path) as T,
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
    _maybeRefuse(path);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: _answer(path) as T,
    );
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    _maybeRefuse(path);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: _answer(path) as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A draft as the write routes answer it.
Map<String, dynamic> _draftBody({
  String id = 'm1',
  String updatedAt = '2026-11-13T09:12:44.120Z',
  String status = 'draft',
}) => {
  'data': {'id': id, 'updatedAt': updatedAt, 'status': status},
};

FiledMedia _draft({String id = 'm1'}) =>
    FiledMedia.fromJson(_draftBody(id: id)['data']! as Map<String, dynamic>);

/// A 409, the way the upload route answers one.
DioException _conflict(String message) => DioException(
  requestOptions: RequestOptions(path: '/v1/media/request-upload'),
  response: Response(
    requestOptions: RequestOptions(path: '/v1/media/request-upload'),
    statusCode: 409,
    data: {'success': false, 'data': null, 'error': message},
  ),
);

DioException _refusal(List<String> errors) => DioException(
  requestOptions: RequestOptions(path: '/v1/media/request-upload'),
  response: Response(
    requestOptions: RequestOptions(path: '/v1/media/request-upload'),
    statusCode: 400,
    data: {'success': false, 'data': null, 'error': errors},
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 900),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            // The parts are all full-width: a Center would leave the Rows
            // inside them unbounded.
            child: SizedBox(width: size.width, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('a video upload is not a livestream', () {
    test('the three ingest routes stay apart', () {
      // Video and audio are the only things that go through this repo.
      expect(MediaUploadKind.values.map((k) => k.slug), ['video', 'music']);
      expect(
        MediaUploadKind.values.map((k) => k.slug),
        isNot(contains('livestream')),
      );
    });

    test('audio is offered the containers the API names, everywhere', () {
      const audio = MediaUploadKind.music;
      for (final target in MediaUploadTarget.values) {
        expect(uploadMimeTypes(audio, target).values.toSet(), {
          'audio/mpeg',
          'audio/mp4',
          'audio/wav',
          'audio/webm',
        }, reason: target.name);
      }
      // Unlike video, audio's list does not change by platform.
      expect(
        uploadMimeTypes(audio, MediaUploadTarget.ios),
        uploadMimeTypes(audio, MediaUploadTarget.android),
      );
      // And nothing here is a video container.
      expect(
        uploadMimeTypes(
          audio,
          MediaUploadTarget.ios,
        ).values.where((m) => m.startsWith('video/')),
        isEmpty,
      );
    });

    test('the two ceilings are the two the API answers with', () {
      expect(MediaUploadKind.video.maxBytes, 5368709120);
      expect(MediaUploadKind.music.maxBytes, 1073741824);
      expect(MediaUploadKind.music.isAudio, isTrue);
      expect(MediaUploadKind.video.isAudio, isFalse);
    });

    test('iOS is offered a narrower list than Android', () {
      expect(
        uploadMimeTypes(MediaUploadKind.video, MediaUploadTarget.ios).values,
        isNot(contains('video/webm')),
      );
      expect(
        uploadMimeTypes(
          MediaUploadKind.video,
          MediaUploadTarget.android,
        ).values,
        contains('video/webm'),
      );
      expect(
        uploadMimeTypes(MediaUploadKind.video, MediaUploadTarget.ios).keys,
        ['mp4', 'mov', 'm4v'],
      );
    });
  });

  group('the ticket', () {
    test('reads what staging answers', () {
      final ticket = MediaUploadTicket.fromJson(
        _ticketBody()['data'] as Map<String, dynamic>,
      );

      expect(ticket.uploadId, 'up_123');
      expect(ticket.method, 'PUT');
      expect(ticket.maxSizeBytes, 5368709120);
      expect(ticket.allowedMimeTypes, contains('video/quicktime'));
      expect(ticket.isUsable, isTrue);
    });

    test('a ticket with no url is not usable', () {
      expect(
        MediaUploadTicket.fromJson(const {'uploadId': 'x'}).isUsable,
        isFalse,
      );
    });
  });

  group('the repo', () {
    test('asks for a ticket in the platform\'s terms', () async {
      final api = _FakeApi(body: _ticketBody());
      await MediaUploadRepo(api).requestUpload(
        creatorId: 'c1',
        kind: MediaUploadKind.video,
        file: _file,
        draft: _draft(),
      );

      final body = api.sent['/v1/media/request-upload']!;
      expect(body['mediaType'], 'video');
      expect(body['mimeType'], 'video/mp4');
      expect(body['size'], _file.size);
      // The API takes web, android or ios and nothing else.
      expect(['web', 'android', 'ios'], contains(body['uploadTarget']));
    });

    test('the monthly quota comes back in the server\'s own words', () async {
      final api = _FakeApi(
        error: _refusal([
          'Monthly upload limit reached (5 uploads on '
              'current plan)',
        ]),
      );

      await expectLater(
        MediaUploadRepo(api).requestUpload(
          creatorId: 'c1',
          kind: MediaUploadKind.video,
          file: _file,
          draft: _draft(),
        ),
        throwsA(
          isA<MediaUploadException>()
              .having(
                (e) => e.failure,
                'failure',
                MediaUploadFailure.quotaReached,
              )
              .having((e) => e.message, 'message', contains('5 uploads')),
        ),
      );
    });

    test('an oversized file is named as such', () async {
      final api = _FakeApi(
        error: _refusal([
          'File size exceeds max allowed size (5368709120 '
              'bytes)',
        ]),
      );

      await expectLater(
        MediaUploadRepo(api).requestUpload(
          creatorId: 'c1',
          kind: MediaUploadKind.video,
          file: _file,
          draft: _draft(),
        ),
        throwsA(
          isA<MediaUploadException>().having(
            (e) => e.failure,
            'failure',
            MediaUploadFailure.tooLarge,
          ),
        ),
      );
    });

    test('the server ceiling outranks the one compiled in', () async {
      final body = _ticketBody();
      (body['data']! as Map)['constraints'] = {'maxSizeBytes': 1024};
      final api = _FakeApi(body: body);

      await expectLater(
        MediaUploadRepo(api).requestUpload(
          creatorId: 'c1',
          kind: MediaUploadKind.video,
          file: _file,
          draft: _draft(),
        ),
        throwsA(
          isA<MediaUploadException>().having(
            (e) => e.failure,
            'failure',
            MediaUploadFailure.tooLarge,
          ),
        ),
      );
    });

    test('the draft is filed before a byte moves, and stays private', () async {
      final api = _FakeApi(bodies: {'/v1/media/drafts': _draftBody()});

      final draft = await MediaUploadRepo(
        api,
      ).createDraft(creatorId: 'c1', kind: MediaUploadKind.video);

      expect(draft.id, 'm1');
      expect(draft.updatedAt, DateTime.utc(2026, 11, 13, 9, 12, 44, 120));
      final body = api.sent['/v1/media/drafts']!;
      expect(body['creatorId'], 'c1');
      expect(body['type'], 'video');
      // Nothing reaches the channel until publish says so.
      expect(body['visibility'], 'private');
    });

    test('a draft answered without updatedAt is read again', () async {
      // The ticket has to quote it back, so a guess is not good enough.
      final api = _FakeApi(
        bodies: {
          '/v1/media/drafts': const {
            'data': {'id': 'm9'},
          },
          '/v1/media/m9': _draftBody(id: 'm9'),
        },
      );

      final draft = await MediaUploadRepo(
        api,
      ).createDraft(creatorId: 'c1', kind: MediaUploadKind.video);

      expect(api.paths, ['/v1/media/drafts', '/v1/media/m9']);
      expect(draft.updatedAt, isNotNull);
    });

    test('the ticket is bound to the row it will fill', () async {
      final api = _FakeApi(body: _ticketBody());

      await MediaUploadRepo(api).requestUpload(
        creatorId: 'c1',
        kind: MediaUploadKind.video,
        file: _file,
        draft: _draft(),
      );

      final body = api.sent['/v1/media/request-upload']!;
      expect(body['mediaId'], 'm1');
      expect(body['expectedMediaUpdatedAt'], '2026-11-13T09:12:44.120Z');
    });

    test('a draft that moved on is read again and asked again', () async {
      final api = _FakeApi(
        body: _ticketBody(),
        bodies: {
          '/v1/media/m1': _draftBody(updatedAt: '2026-11-13T10:00:00.000Z'),
        },
      );
      api.refusals['/v1/media/request-upload'] = [
        _conflict('The media draft changed since it was read'),
      ];

      final ticket = await MediaUploadRepo(api).requestUpload(
        creatorId: 'c1',
        kind: MediaUploadKind.video,
        file: _file,
        draft: _draft(),
      );

      expect(ticket.uploadId, 'up_123');
      expect(api.paths, [
        '/v1/media/request-upload',
        '/v1/media/m1',
        '/v1/media/request-upload',
      ]);
      // And the second attempt carries the fresh stamp, not the stale one.
      expect(
        api.sent['/v1/media/request-upload']!['expectedMediaUpdatedAt'],
        '2026-11-13T10:00:00.000Z',
      );
    });

    test('a draft that already holds a file drops it first', () async {
      final api = _FakeApi(
        body: _ticketBody(),
        bodies: {'/v1/media/m1': _draftBody()},
      );
      api.refusals['/v1/media/request-upload'] = [
        _conflict('This media is already processing an uploaded asset'),
      ];

      await MediaUploadRepo(api).requestUpload(
        creatorId: 'c1',
        kind: MediaUploadKind.video,
        file: _file,
        draft: _draft(),
      );

      expect(api.paths, [
        '/v1/media/request-upload',
        '/v1/media/m1/source',
        '/v1/media/m1',
        '/v1/media/request-upload',
      ]);
    });

    test('but it only tries once more', () async {
      final api = _FakeApi(bodies: {'/v1/media/m1': _draftBody()});
      api.refusals['/v1/media/request-upload'] = [
        _conflict('The media draft changed since it was read'),
        _conflict('The media draft changed since it was read'),
      ];

      await expectLater(
        MediaUploadRepo(api).requestUpload(
          creatorId: 'c1',
          kind: MediaUploadKind.video,
          file: _file,
          draft: _draft(),
        ),
        throwsA(
          isA<MediaUploadException>().having(
            (e) => e.failure,
            'failure',
            MediaUploadFailure.draftChanged,
          ),
        ),
      );
    });

    test('the details go on as a PATCH to the row', () async {
      final api = _FakeApi();

      final at = DateTime.utc(2026, 11, 20, 9);
      await MediaUploadRepo(api).updateMedia(
        mediaId: 'm1',
        title: 'Walking by faith',
        description: 'A message on trusting God.',
        categorySlugs: const ['sermons'],
        thumbnailFileId: 'f1',
        visibility: MediaVisibility.public,
        scheduledAt: at,
      );

      final body = api.sent['/v1/media/m1']!;
      expect(body['title'], 'Walking by faith');
      expect(body['visibility'], 'public');
      expect(body['thumbnailFileId'], 'f1');
      expect(body['scheduledAt'], at.toIso8601String());
      // The upload is already bound to the row; nothing names it again.
      expect(body.containsKey('sourceUploadId'), isFalse);
      // Both belong to a livestream session.
      expect(body.containsKey('scheduledTimezone'), isFalse);
      expect(body.containsKey('notifyFollowers'), isFalse);
    });

    test('an empty field is left out rather than sent blank', () async {
      // A draft being filled in for the first time: absent and empty mean
      // the same thing, and absent cannot trip a validator.
      final api = _FakeApi();

      await MediaUploadRepo(api).updateMedia(
        mediaId: 'm2',
        title: 'Draft',
        description: '',
        visibility: MediaVisibility.private,
      );

      final body = api.sent['/v1/media/m2']!;
      expect(body['visibility'], 'private');
      expect(body.containsKey('description'), isFalse);
      expect(body.containsKey('categorySlugs'), isFalse);
      expect(body.containsKey('scheduledAt'), isFalse);
      expect(body.containsKey('thumbnailFileId'), isFalse);
    });

    test(
      'a spent ticket is named, not reported as a generic refusal',
      () async {
        final api = _FakeApi(
          error: _refusal([
            'sourceUploadId is invalid or expired. Request upload again.',
          ]),
        );

        await expectLater(
          MediaUploadRepo(api).requestUpload(
            creatorId: 'c1',
            kind: MediaUploadKind.video,
            file: _file,
            draft: _draft(),
          ),
          throwsA(
            isA<MediaUploadException>().having(
              (e) => e.failure,
              'failure',
              MediaUploadFailure.ticketExpired,
            ),
          ),
        );
      },
    );

    test('a schedule that has passed is named as such', () async {
      final api = _FakeApi(
        error: _refusal(['scheduledAt must be in the future']),
      );

      await expectLater(
        MediaUploadRepo(api).updateMedia(
          mediaId: 'm1',
          title: 'T',
          visibility: MediaVisibility.public,
          scheduledAt: DateTime(2020),
        ),
        throwsA(
          isA<MediaUploadException>().having(
            (e) => e.failure,
            'failure',
            MediaUploadFailure.scheduleInPast,
          ),
        ),
      );
    });

    test('the screen makes the row before it asks for a ticket', () {
      // The ticket is bound to the row, so the order is the whole point of
      // the change. A widget test cannot reach this: picking a file goes
      // through the platform.
      final source = File(
        'lib/features/creator/views/new_media_screen.dart',
      ).readAsStringSync();

      final draftAt = source.indexOf('_repo.createDraft(');
      final ticketAt = source.indexOf('_repo.requestUpload(');
      expect(draftAt, greaterThan(0), reason: 'no draft is filed at all');
      expect(ticketAt, greaterThan(draftAt));
    });

    test('and fills it with a PATCH, not a second create', () {
      final source = File(
        'lib/features/creator/views/new_media_screen.dart',
      ).readAsStringSync();

      expect(source, contains('_repo.updateMedia('));
      expect(
        source,
        isNot(contains('createMedia')),
        reason:
            'POST /v1/media has no shipped client and an unconfirmed '
            'contract; the guide lists it under routes not covered',
      );
    });

    test('swapping the file keeps the row that was already filed', () {
      // Otherwise every re-pick strands an empty draft in the creator's
      // library.
      final source = File(
        'lib/features/creator/views/new_media_screen.dart',
      ).readAsStringSync();
      final from = source.indexOf('void _removeFile()');
      final body = source.substring(from, source.indexOf('\n  }', from));

      expect(from, greaterThan(0));
      expect(body, isNot(contains('_draft = null')));
    });

    test('publish takes visibility and nothing else', () async {
      final api = _FakeApi(body: const {'data': {}});
      await MediaUploadRepo(
        api,
      ).publish(mediaId: 'm1', visibility: MediaVisibility.public);

      expect(api.sent['/v1/media/m1/publish'], {'visibility': 'public'});
    });
  });

  group('the audio screen', () {
    Future<void> pumpAudio(WidgetTester tester) async {
      final api = _FakeApi(body: _ticketBody());
      tester.view.physicalSize = const Size(390 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (context) => MaterialApp(
            home: NewMediaScreen(
              kind: MediaUploadKind.music,
              creatorId: 'c1',
              uploads: MediaUploadRepo(api),
              creators: CreatorRepo(api: api),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('it names audio, not video', (tester) async {
      await pumpAudio(tester);

      expect(find.text(AppStrings.newAudioTitle), findsOneWidget);
      expect(find.text(AppStrings.newAudioSelect), findsOneWidget);
      // The design repeats the video frame's hint and subtitle verbatim;
      // neither is true of an audio upload.
      expect(find.text(AppStrings.newAudioPickHint), findsOneWidget);
      expect(find.text(AppStrings.newVideoPickHint), findsNothing);
      expect(find.text(AppStrings.newVideoSubtitle), findsNothing);
    });

    testWidgets('it asks the API for music, at the music ceiling', (
      tester,
    ) async {
      final api = _FakeApi(body: _ticketBody());
      await MediaUploadRepo(api).requestUpload(
        creatorId: 'c1',
        kind: MediaUploadKind.music,
        file: _track,
        draft: _draft(),
      );

      final body = api.sent['/v1/media/request-upload']!;
      expect(body['mediaType'], 'music');
      expect(body['mimeType'], 'audio/mpeg');
    });

    testWidgets('the card leads with a headphones tile, not a still', (
      tester,
    ) async {
      await _pump(
        tester,
        MediaFileCard(
          kind: MediaUploadKind.music,
          file: _track,
          sent: _track.size,
          onRemove: () {},
        ),
      );

      expect(find.byKey(const ValueKey('media-tile-audio')), findsOneWidget);
      expect(find.byKey(const ValueKey('media-tile-video')), findsNothing);
      expect(find.text('sample.mp3'), findsOneWidget);
    });

    testWidgets('a video keeps its own tile', (tester) async {
      await _pump(
        tester,
        MediaFileCard(
          kind: MediaUploadKind.video,
          file: _file,
          sent: _file.size,
          onRemove: () {},
        ),
      );

      expect(find.byKey(const ValueKey('media-tile-video')), findsOneWidget);
      expect(find.byKey(const ValueKey('media-tile-audio')), findsNothing);
    });

    test('each kind says its own name when it lands', () {
      // The audio design reuses "Your video is live" verbatim.
      expect(AppStrings.newAudioLiveTitle, isNot(AppStrings.newVideoLiveTitle));
      expect(
        AppStrings.newAudioLiveTitle.toLowerCase(),
        isNot(contains('video')),
      );
      expect(
        AppStrings.newAudioSubtitle.toLowerCase(),
        isNot(contains('video')),
      );
    });
  });

  group('the file card', () {
    testWidgets('an upload in flight shows how far it has got', (tester) async {
      await _pump(
        tester,
        MediaFileCard(
          kind: MediaUploadKind.video,
          file: _file,
          sent: (_file.size * 0.64).ceil(),
          onRemove: () {},
        ),
      );

      expect(find.textContaining('64%'), findsOneWidget);
      expect(find.textContaining('1.2 GB'), findsOneWidget);
      expect(find.byKey(const ValueKey('media-remove')), findsOneWidget);
    });

    testWidgets('a finished upload says it is ready, not processing', (
      tester,
    ) async {
      await _pump(
        tester,
        MediaFileCard(
          kind: MediaUploadKind.video,
          file: _file,
          sent: _file.size,
          onRemove: () {},
        ),
      );

      expect(find.textContaining(AppStrings.newMediaUploaded), findsOneWidget);
      // "Processing" means the transcode, which happens after this screen.
      expect(find.textContaining('Processing'), findsNothing);
    });

    testWidgets('a refused upload says so on the card, not just in a snack', (
      tester,
    ) async {
      await _pump(
        tester,
        MediaFileCard(
          kind: MediaUploadKind.video,
          file: _file,
          sent: 0,
          failed: true,
          onRemove: () {},
        ),
      );

      // The monthly quota makes this the likeliest ending, and the snackbar
      // is long gone by the time the creator looks.
      expect(
        find.textContaining(AppStrings.newMediaUploadFailed),
        findsOneWidget,
      );
      expect(find.textContaining('Uploading 0%'), findsNothing);
    });

    test('bytes read the way the design writes them', () {
      expect(formatBytes(1288490188), '1.2 GB');
      expect(formatBytes(5 * 1024 * 1024), '5 MB');
      expect(formatBytes(2048), '2 KB');
    });
  });

  group('the go-live sheet', () {
    testWidgets('publish now is the default and comes back as such', (
      tester,
    ) async {
      PublishChoice? choice;
      await _pump(tester, GoLiveSheet(onChoose: (c) => choice = c));

      expect(find.text(AppStrings.goLiveSheetTitle), findsOneWidget);
      expect(find.text(AppStrings.goLiveLater), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('go-live-confirm')));
      await tester.pump();

      expect(choice?.timing, PublishTiming.now);
      expect(choice?.at, isNull);
    });

    testWidgets('scheduling hands back a moment in the future', (tester) async {
      PublishChoice? choice;
      await _pump(tester, GoLiveSheet(onChoose: (c) => choice = c));

      await tester.tap(find.byKey(const ValueKey('go-live-later')));
      await tester.pump();

      // The button says what it will do now.
      expect(find.text(AppStrings.goLiveSchedule), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('go-live-confirm')));
      await tester.pump();

      expect(choice?.timing, PublishTiming.schedule);
      expect(choice?.at?.isAfter(DateTime.now()), isTrue);
    });

    testWidgets('a moment that has passed cannot be confirmed', (tester) async {
      PublishChoice? choice;
      // What sitting on the sheet past the chosen hour would leave behind.
      await _pump(
        tester,
        GoLiveSheet(
          onChoose: (c) => choice = c,
          initialAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('go-live-later')));
      await tester.pump();

      expect(find.text(AppStrings.goLivePastMoment), findsOneWidget);
      expect(
        tester
            .widget<PrimaryButton>(
              find.byKey(const ValueKey('go-live-confirm')),
            )
            .enabled,
        isFalse,
      );

      await tester.tap(find.byKey(const ValueKey('go-live-confirm')));
      await tester.pump();
      // The API would refuse it: "scheduledAt must be in the future".
      expect(choice, isNull);
    });

    test('the date and time read the way the design writes them', () {
      final at = DateTime(2025, 6, 1, 6);
      expect(formatSheetDate(at), 'Sun, Jun 1, 2025');
      expect(formatSheetTime(at), '6:00 AM');
      expect(formatSheetTime(DateTime(2025, 6, 1, 0, 5)), '12:05 AM');
      expect(formatSheetTime(DateTime(2025, 6, 1, 13, 30)), '1:30 PM');
    });
  });

  group('the screen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      final api = _FakeApi(body: _ticketBody());
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
      await tester.pump();
    }

    testWidgets('it asks for a video, not a stream', (tester) async {
      await pumpScreen(tester);

      expect(find.text(AppStrings.newVideoTitle), findsOneWidget);
      expect(find.text(AppStrings.newVideoSubtitle), findsOneWidget);
      expect(find.byKey(const ValueKey('media-select')), findsOneWidget);
      // Nothing here belongs to the livestream flow.
      expect(find.textContaining('Live', skipOffstage: false), findsNothing);
    });

    testWidgets('publishing stays shut until the form is whole', (
      tester,
    ) async {
      await pumpScreen(tester);

      final button = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('media-publish')),
      );
      expect(button.enabled, isFalse);

      // Typing a title is not enough on its own: the design marks the file,
      // the thumbnail and the description required too.
      await tester.enterText(
        find.byKey(const ValueKey('media-title')),
        'Walking by faith',
      );
      await tester.pump();

      expect(
        tester
            .widget<PrimaryButton>(find.byKey(const ValueKey('media-publish')))
            .enabled,
        isFalse,
      );
    });

    testWidgets('nothing overflows on a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (context) => MaterialApp(
            home: NewMediaScreen(
              kind: MediaUploadKind.video,
              creatorId: 'c1',
              uploads: MediaUploadRepo(_FakeApi(body: _ticketBody())),
              creators: CreatorRepo(api: _FakeApi(body: _ticketBody())),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('the pieces', () {
    testWidgets('an empty picker says what will be taken', (tester) async {
      await _pump(
        tester,
        MediaPickCard(
          hint: AppStrings.newVideoPickHint,
          selectLabel: AppStrings.newVideoSelect,
          onPick: () {},
        ),
      );

      expect(find.text(AppStrings.newVideoPickHint), findsOneWidget);
      expect(find.text(AppStrings.newVideoSelect), findsOneWidget);
    });

    testWidgets('a required label marks itself', (tester) async {
      await _pump(tester, const RequiredLabel(AppStrings.newMediaTitleLabel));

      expect(
        find.textContaining(AppStrings.newMediaRequired, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('an empty thumbnail well invites one', (tester) async {
      await _pump(tester, ThumbnailWell(image: null, onPick: () {}));

      expect(find.text(AppStrings.newMediaThumbnailCta), findsOneWidget);
    });

    testWidgets('the success card names what happened', (tester) async {
      await _pump(
        tester,
        PublishedCard(
          title: AppStrings.newVideoLiveTitle,
          body: AppStrings.newVideoLiveBody,
          onDone: () {},
        ),
      );

      expect(find.text(AppStrings.newVideoLiveTitle), findsOneWidget);
      expect(find.text(AppStrings.newVideoLiveBody), findsOneWidget);
    });

    testWidgets('nothing overflows on a narrow phone', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            MediaPickCard(
              hint: AppStrings.newVideoPickHint,
              selectLabel: AppStrings.newVideoSelect,
              onPick: () {},
            ),
            MediaFileCard(
              kind: MediaUploadKind.video,
              file: _file,
              sent: 100,
              onRemove: () {},
            ),
            ThumbnailWell(image: _swatch, onPick: () {}),
          ],
        ),
        size: const Size(320, 900),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

/// A 1×1 PNG, enough for the well to draw something.
final _swatch = PickedImage(
  bytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  ),
  filename: 'swatch.png',
  mimeType: 'image/png',
);
