import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/library/repo/playlist_repo.dart';
import 'package:test_app/shared/services/api_service.dart';

/// A viewer-supplied playlist cover: ticket, S3, then `coverFileId`.
///
/// Arrived 2026-10-26. Three things it is easy to get wrong, and each one
/// fails quietly rather than loudly:
///
/// - **The PATCH is what confirms the upload.** Without it the key stays in
///   `quarantine/` and the cover never appears, with no error anywhere.
/// - **The ceiling is read off the ticket**, not hard-coded, because the
///   server may tighten it.
/// - **`coverFileId: null` removes it**, falling back to the derived cover —
///   omitting the key would leave whatever was there.
class _FakeApi implements ApiService {
  _FakeApi({this.maxSizeBytes = 5 * 1024 * 1024, this.malformed = false});

  final int? maxSizeBytes;
  final bool malformed;

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
    if (malformed) return _ok(path, const {'fileId': 'f1'});
    return _ok(path, {
      'fileId': 'f1',
      'uploadUrl': 'https://s3.example/bucket',
      'fields': const {'key': 'quarantine/f1'},
      'constraints': {'maxSizeBytes': ?maxSizeBytes},
    });
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    patched.add((path: path, body: data));
    return _ok(path, const <String, dynamic>{});
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

PickedImage _image({int bytes = 2048}) => PickedImage(
  bytes: Uint8List(bytes),
  filename: 'cover.jpg',
  mimeType: 'image/jpeg',
);

void main() {
  test(
    'the ticket, the bytes and the confirming PATCH, in that order',
    () async {
      final api = _FakeApi();
      final sent = <String>[];

      await PlaylistRepo(
        api: api,
        send:
            ({
              required String uploadUrl,
              required Map<String, dynamic> fields,
              required Uint8List bytes,
              required String filename,
            }) async => sent.add(uploadUrl),
      ).uploadCover('p1', _image());

      expect(api.posted.single.path, '/v1/media/playlists/p1/cover/upload-url');
      expect(api.posted.single.body, {
        'filename': 'cover.jpg',
        'mimeType': 'image/jpeg',
        'size': 2048,
      });
      expect(sent, ['https://s3.example/bucket']);
      // Naming the fileId is what promotes the key out of quarantine.
      expect(api.patched.single.path, '/v1/media/playlists/p1');
      expect(api.patched.single.body, {'coverFileId': 'f1'});
    },
  );

  test('a file over the ticket\'s own ceiling never reaches S3', () async {
    final api = _FakeApi(maxSizeBytes: 1024);
    var reached = false;

    await expectLater(
      PlaylistRepo(
        api: api,
        send:
            ({
              required String uploadUrl,
              required Map<String, dynamic> fields,
              required Uint8List bytes,
              required String filename,
            }) async => reached = true,
      ).uploadCover('p1', _image(bytes: 4096)),
      throwsA(isA<PlaylistCoverTooLarge>()),
    );

    expect(reached, isFalse);
    expect(api.patched, isEmpty);
  });

  test('a malformed ticket is refused rather than half-used', () async {
    final api = _FakeApi(malformed: true);

    await expectLater(
      PlaylistRepo(
        api: api,
        send:
            ({
              required String uploadUrl,
              required Map<String, dynamic> fields,
              required Uint8List bytes,
              required String filename,
            }) async {},
      ).uploadCover('p1', _image()),
      throwsA(isA<PlaylistCoverTooLarge>()),
    );

    expect(api.patched, isEmpty);
  });

  test('removing a cover sends an explicit null', () async {
    // Omitting the key would leave whatever was there; null is what falls
    // back to the derived cover.
    final api = _FakeApi();
    await PlaylistRepo(api: api).removeCover('p1');

    expect(api.patched.single.body, {'coverFileId': null});
  });
}
