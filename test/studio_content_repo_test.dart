import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/creator/repo/studio_content_repo.dart';
import 'package:test_app/models/creator_models/studio_content_models.dart';
import 'package:test_app/shared/services/api_service.dart';

/// The envelope all three search routes answer with.
Map<String, dynamic> _envelope(List<Map<String, dynamic>> rows) => {
  'data': {
    'data': rows,
    'meta': {'total': rows.length},
  },
};

class _FakeApi implements ApiService {
  final List<String> paths = [];
  final Map<String, Map<String, dynamic>> bodies = {};
  Map<String, dynamic> Function(String path)? answer;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (answer?.call(path) ?? _envelope(const [])) as T,
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
    if (data is Map<String, dynamic>) bodies[path] = data;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (answer?.call(path) ?? _envelope(const [])) as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());

  /// The one body sent to the media search.
  Map<String, dynamic> get mediaBody =>
      bodies.entries.firstWhere((e) => e.key.contains('/media/')).value;

  List<String> get mediaTypes =>
      ((mediaBody['filters'] as Map)['type'] as Map)['in'] as List<String>;
}

void main() {
  group('what the media search is asked for', () {
    test('All asks for livestreams too', () async {
      final api = _FakeApi();
      await StudioContentRepo(api).fetch(creatorId: 'c1');

      // Leaving livestream out made a creator's Sunday service invisible in
      // the studio: it is a separate media type, not a video.
      expect(api.mediaTypes, containsAll(['video', 'music', 'livestream']));
    });

    test('the Videos chip covers uploads and broadcasts', () async {
      final api = _FakeApi();
      await StudioContentRepo(
        api,
      ).fetch(creatorId: 'c1', kind: StudioContentKind.video);

      expect(api.mediaTypes, ['video', 'livestream']);
      expect(api.mediaTypes, isNot(contains('music')));
    });

    test('the Audio chip asks for music alone', () async {
      final api = _FakeApi();
      await StudioContentRepo(
        api,
      ).fetch(creatorId: 'c1', kind: StudioContentKind.audio);

      expect(api.mediaTypes, ['music']);
    });

    test(
      'a chip with no media behind it never calls the media route',
      () async {
        final api = _FakeApi();
        await StudioContentRepo(
          api,
        ).fetch(creatorId: 'c1', kind: StudioContentKind.event);

        expect(api.paths.where((p) => p.contains('/media/')), isEmpty);
      },
    );
  });

  test('a livestream reaches the list as a livestream', () async {
    final api = _FakeApi()
      ..answer = (path) => path.contains('/media/')
          ? _envelope([
              {
                'id': 'ls1',
                'type': 'livestream',
                'title': 'Sunday Second Service',
                'status': 'ready',
                'visibility': 'unlisted',
                'isLiveNow': false,
                'analyticsViews': 2140,
                'endedAt': '2026-09-14T11:20:00.000Z',
              },
            ])
          : _envelope(const []);

    final page = await StudioContentRepo(api).fetch(creatorId: 'c1');

    expect(page.items, hasLength(1));
    expect(page.items.single.kind, StudioContentKind.livestream);
    // The session itself has ended; its recording is a separate video row.
    expect(page.items.single.state, StudioContentState.ended);
  });

  test('one failing service does not empty the list', () async {
    final api = _FakeApi()
      ..answer = (path) {
        if (path.contains('/posts/')) {
          throw DioException(requestOptions: RequestOptions(path: path));
        }
        return _envelope(
          path.contains('/media/')
              ? [
                  {
                    'id': 'v1',
                    'type': 'video',
                    'title': 'The Prodigal Returns',
                    'status': 'published',
                  },
                ]
              : const [],
        );
      };

    final page = await StudioContentRepo(api).fetch(creatorId: 'c1');

    expect(page.items, hasLength(1));
    expect(page.items.single.kind, StudioContentKind.video);
  });
}
