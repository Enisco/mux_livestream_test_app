import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// `POST /v1/creator/onboard` as staging answers it — `data` is the
/// channel itself, not nested under `creator`.
Map<String, dynamic> _onboardBody(String id) => {
  'data': {
    'id': id,
    'type': 'individual',
    'handle': 'gracechapel',
    'displayName': 'Grace Chapel',
    'ownerUserId': 'u1',
    'status': 'active',
    'createdAt': '2026-09-25T00:00:00.000Z',
    'updatedAt': '2026-09-25T00:00:00.000Z',
  },
};

/// `GET /v1/creator/profile` for a reader who has one.
const _profileBody = {
  'data': {
    'creator': {
      'id': 'c1',
      'type': 'individual',
      'handle': 'gracechapel',
      'displayName': 'Grace Chapel',
      'status': 'active',
    },
  },
};

DioException _status(int code, String error, {String path = '/x'}) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      response: Response(
        requestOptions: RequestOptions(path: path),
        statusCode: code,
        data: {'success': false, 'data': null, 'error': error},
      ),
    );

class _FakeApi implements ApiService {
  _FakeApi({this.getBody, this.getError, this.postBody, this.postErrors});

  Map<String, dynamic>? getBody;
  DioException? getError;
  Map<String, dynamic>? postBody;

  /// One per call, so a retry can be given a different answer.
  List<DioException?>? postErrors;

  final List<String> paths = [];
  int _posts = 0;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add('GET $path');
    if (getError != null) throw getError!;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (getBody ?? const <String, dynamic>{}) as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add('POST $path');
    final error = postErrors == null || _posts >= postErrors!.length
        ? null
        : postErrors![_posts];
    _posts++;
    if (error != null) throw error;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (postBody ?? const <String, dynamic>{}) as T,
    );
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    paths.add('PATCH $path');
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (postBody ?? const <String, dynamic>{}) as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('does this reader have a channel', () {
    test('a cached id is taken at its word', () async {
      await LocalStorage.setString(LocalStorage.creatorIdKey, 'cached');
      final api = _FakeApi();

      final lookup = await CreatorRepo(api: api).resolveChannel();

      expect(lookup.hasChannel, isTrue);
      expect(lookup.id, 'cached');
      // No need to ask when the answer is already known.
      expect(api.paths, isEmpty);
    });

    test(
      'with nothing cached it asks the server, and caches the answer',
      () async {
        final api = _FakeApi(getBody: _profileBody);

        final lookup = await CreatorRepo(api: api).resolveChannel();

        expect(lookup.hasChannel, isTrue);
        expect(lookup.id, 'c1');
        expect(api.paths, contains('GET /v1/creator/profile'));
        // A reader who signs in on a new phone keeps their studio.
        expect(LocalStorage.creatorId, 'c1');
      },
    );

    test('forcing re-asks even when something is cached', () async {
      await LocalStorage.setString(LocalStorage.creatorIdKey, 'stale');
      final api = _FakeApi(getBody: _profileBody);

      final lookup = await CreatorRepo(api: api).resolveChannel(force: true);

      expect(lookup.id, 'c1');
      expect(api.paths, contains('GET /v1/creator/profile'));
    });

    test('404 means no channel, and that reader may start one', () async {
      final api = _FakeApi(getError: _status(404, 'Creator profile not found'));

      final lookup = await CreatorRepo(api: api).resolveChannel();

      expect(lookup.canStartOne, isTrue);
      expect(lookup.hasChannel, isFalse);
      expect(lookup.id, isNull);
    });

    test('a failure is not the same as having no channel', () async {
      for (final error in [
        _status(500, 'Internal error'),
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      ]) {
        final lookup = await CreatorRepo(
          api: _FakeApi(getError: error),
        ).resolveChannel();

        // Inviting this reader to start a channel could walk them into a
        // 409; hiding the studio from them would be just as wrong.
        expect(lookup.canStartOne, isFalse, reason: '$error');
        expect(lookup.hasChannel, isFalse, reason: '$error');
      }
    });

    test('a body with no creator on it is no channel', () async {
      final api = _FakeApi(getBody: const {'data': <String, dynamic>{}});
      expect(
        (await CreatorRepo(api: api).resolveChannel()).canStartOne,
        isTrue,
      );
    });
  });

  group('starting a channel when one already exists', () {
    test('a taken handle is retried with a suffix', () async {
      final api = _FakeApi(
        postErrors: [_status(409, 'Handle already taken')],
        postBody: _onboardBody('new1'),
      );

      final id = await CreatorRepo(api: api).saveCreatorProfile(
        handle: 'gracechapel',
        displayName: 'Grace Chapel',
        type: 'individual',
      );

      expect(id, 'new1');
      // Two attempts: the taken handle, then the suffixed one.
      expect(api.paths.where((p) => p == 'POST /v1/creator/onboard').length, 2);
    });

    test(
      '"already owns a creator profile" opens the channel they have',
      () async {
        // The same 409 status, a completely different situation: this reader
        // signed in on a new phone. Retrying with another handle would be
        // refused again and leave them locked out of their own studio.
        final api = _FakeApi(
          postErrors: [_status(409, 'User already owns a creator profile')],
          getBody: _profileBody,
        );

        final id = await CreatorRepo(api: api).saveCreatorProfile(
          handle: 'gracechapel',
          displayName: 'Grace Chapel',
          type: 'individual',
        );

        expect(id, 'c1');
        // It did not try to make a second one.
        expect(
          api.paths.where((p) => p == 'POST /v1/creator/onboard').length,
          1,
        );
        expect(LocalStorage.creatorId, 'c1');
      },
    );

    test('a reader who already has a channel never onboards again', () async {
      await LocalStorage.setString(LocalStorage.creatorIdKey, 'c9');
      final api = _FakeApi(postBody: _onboardBody('unused'));

      final id = await CreatorRepo(api: api).saveCreatorProfile(
        handle: 'anything',
        displayName: 'Anything',
        type: 'individual',
      );

      expect(id, 'c9');
      expect(api.paths, isNot(contains('POST /v1/creator/onboard')));
    });
  });
}
