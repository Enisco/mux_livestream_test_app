import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/device_info_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';

/// Signing in again on every launch.
///
/// The server **rotates** refresh tokens: a successful refresh returns a new
/// one and retires the one it was given. Reusing a spent token answers 401,
/// which this reproduces — and a cold start is exactly where it bites,
/// because several requests go out together on an access token that has
/// just expired and every one of them comes back 401 at once.
///
/// Before the fix each of those 401s started its own refresh with the same
/// token: the first renewed the session and the rest were told 401, which
/// the interceptor read as "this session is over" and cleared the tokens
/// that had just been written.
class _Tokens extends TokenStorageService {
  _Tokens({this.access, this.refresh});

  String? access;
  String? refresh;
  int saves = 0;
  int clears = 0;

  @override
  Future<String?> get accessToken async => access;

  @override
  Future<String?> get refreshToken async => refresh;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    String? sessionId,
  }) async {
    saves++;
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clearAll() async {
    clears++;
    access = null;
    refresh = null;
  }
}

class _Device extends DeviceInfoService {
  @override
  Map<String, String> get headers => const {'x-device-id': 'test'};
}

/// A server that rotates refresh tokens and refuses a spent one, and that
/// answers 401 to anything carrying a stale access token.
class _RotatingServer implements HttpClientAdapter {
  _RotatingServer({required this.liveRefresh, required this.liveAccess});

  /// The only refresh token the server will still accept.
  String liveRefresh;

  /// The only access token it will still accept.
  String liveAccess;

  int refreshCalls = 0;
  int spentRefreshCalls = 0;
  final List<String> paths = [];

  /// Held open so several refreshes can be made to overlap.
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);

    if (options.path.contains('/auth/sessions/refresh')) {
      refreshCalls++;
      if (gate case final open?) await open.future;

      final sent = (options.data as Map)['refreshToken'] as String;
      if (sent != liveRefresh) {
        // Already spent: the server retired it when it was first used.
        spentRefreshCalls++;
        return _json(401, {'success': false, 'error': 'Unauthorized'});
      }
      liveRefresh = '$sent+next';
      liveAccess = '${options.path}-access-$refreshCalls';
      return _json(200, {
        'success': true,
        'data': {'accessToken': liveAccess, 'refreshToken': liveRefresh},
      });
    }

    final sent = options.headers['Authorization'];
    if (sent != 'Bearer $liveAccess') {
      return _json(401, {'success': false, 'error': 'Unauthorized'});
    }
    return _json(200, {'success': true, 'data': <String, dynamic>{}});
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

ApiService _apiWith(_Tokens tokens, _RotatingServer server) =>
    ApiService(tokenStorage: tokens, deviceInfo: _Device())
      ..httpClientAdapter = server;

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.test');
  });

  test('a burst of 401s spends the refresh token exactly once', () async {
    final tokens = _Tokens(access: 'stale', refresh: 'good');
    final server = _RotatingServer(liveRefresh: 'good', liveAccess: 'fresh');
    final api = _apiWith(tokens, server);

    var expired = false;
    ApiService.onSessionExpired = () => expired = true;
    addTearDown(() => ApiService.onSessionExpired = null);

    // Hold the first refresh open so the others pile up behind it, which is
    // what a cold start does.
    server.gate = Completer<void>();
    final calls = [
      api.get<dynamic>('/one'),
      api.get<dynamic>('/two'),
      api.get<dynamic>('/three'),
    ];
    await Future<void>.delayed(const Duration(milliseconds: 50));
    server.gate!.complete();
    final responses = await Future.wait(calls);

    // One refresh for the three of them, so the token is never reused.
    expect(server.refreshCalls, 1);
    expect(server.spentRefreshCalls, 0);
    expect(tokens.saves, 1);

    // And every request was retried with the new token and succeeded.
    for (final response in responses) {
      expect(response.statusCode, 200);
    }

    // Above all: the reader is still signed in.
    expect(expired, isFalse);
    expect(tokens.clears, 0);
    expect(tokens.access, isNotNull);
  });

  test('a refresh the server really refuses still ends the session', () async {
    final tokens = _Tokens(access: 'stale', refresh: 'expired');
    // The live token is something else, so the one held is genuinely dead.
    final server = _RotatingServer(liveRefresh: 'other', liveAccess: 'fresh');
    final api = _apiWith(tokens, server);

    var expired = false;
    ApiService.onSessionExpired = () => expired = true;
    addTearDown(() => ApiService.onSessionExpired = null);

    await api
        .get<dynamic>('/one')
        .catchError(
          (Object _) =>
              Response<dynamic>(requestOptions: RequestOptions(path: '/one')),
        );

    expect(expired, isTrue);
    expect(tokens.clears, 1);
  });

  test('a launch refresh and a 401 refresh do not race each other', () async {
    // The shape of the reported bug: the splash screen renews the session
    // while the feed's first requests are already in flight on the access
    // token that just expired.
    final tokens = _Tokens(access: 'stale', refresh: 'good');
    final server = _RotatingServer(liveRefresh: 'good', liveAccess: 'fresh');
    final api = _apiWith(tokens, server);

    var expired = false;
    ApiService.onSessionExpired = () => expired = true;
    addTearDown(() => ApiService.onSessionExpired = null);

    server.gate = Completer<void>();
    final launch = api.refreshSession();
    final feed = api.get<dynamic>('/feed');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    server.gate!.complete();

    expect(await launch, RefreshOutcome.refreshed);
    expect((await feed).statusCode, 200);

    // One refresh between them, and the session is intact.
    expect(server.refreshCalls, 1);
    expect(server.spentRefreshCalls, 0);
    expect(expired, isFalse);
    expect(tokens.clears, 0);
  });

  test('a later 401 starts a fresh refresh, not a stale one', () async {
    final tokens = _Tokens(access: 'stale', refresh: 'good');
    final server = _RotatingServer(liveRefresh: 'good', liveAccess: 'fresh');
    final api = _apiWith(tokens, server);

    await api.get<dynamic>('/one');
    expect(server.refreshCalls, 1);

    // Something else goes stale later on; the guard must not have latched.
    tokens.access = 'stale-again';
    await api.get<dynamic>('/two');

    expect(server.refreshCalls, 2);
    expect(server.spentRefreshCalls, 0);
  });
}
