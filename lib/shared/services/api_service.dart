import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/models/auth_models/auth_models.dart';
import 'package:test_app/shared/services/device_info_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Why a refresh attempt ended. Only [rejected] should end the session.
enum RefreshOutcome {
  refreshed,
  rejected,

  /// The refresh never reached the server, so the tokens may still be good.
  unavailable,
}

/// What to do about a 401.
enum SessionAction {
  /// Let the error surface. Nothing about the session changed.
  passThrough,

  /// The refresh worked; replay the original request.
  retry,

  /// The server refused the refresh token — sign the user out.
  endSession,
}

/// The whole policy for a 401, in one place.
///
/// Two mistakes live here if it is spread across the interceptor: signing a
/// user out because the network dropped mid-refresh, and dragging a signed-out
/// browser to the sign-in screen over a stale token they never asked for.
SessionAction sessionActionFor({
  required bool hasRefreshToken,
  RefreshOutcome? outcome,
}) {
  if (!hasRefreshToken) return SessionAction.passThrough;
  return switch (outcome) {
    RefreshOutcome.refreshed => SessionAction.retry,
    RefreshOutcome.rejected => SessionAction.endSession,
    _ => SessionAction.passThrough,
  };
}

class ApiService {
  late final Dio _dio;
  bool _isHandlingExpiry = false;

  /// The refresh currently in flight, if any.
  ///
  /// The server **rotates** refresh tokens: every successful refresh returns
  /// a new one and invalidates the one that was spent. So a burst of 401s —
  /// which is exactly what a cold start produces, when several requests go
  /// out together on an access token that has just expired — must not each
  /// start its own refresh. The first would succeed and the rest would send
  /// a token the server had already retired, get 401, and tear down a
  /// session that had in fact just been renewed.
  Future<RefreshOutcome>? _refreshInFlight;

  final TokenStorageService _tokenStorage;
  final DeviceInfoService _deviceInfo;

  static void Function()? onSessionExpired;

  ApiService({
    required TokenStorageService tokenStorage,
    required DeviceInfoService deviceInfo,
  }) : _tokenStorage = tokenStorage,
       _deviceInfo = deviceInfo {
    _dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['BASE_URL'] ?? '',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
      ),
    );
    _dio.interceptors.add(_buildInterceptor());
  }

  /// Lets a test answer this service's requests without a network, so the
  /// interceptor's own behaviour — refreshing, retrying, giving up — can be
  /// exercised rather than mocked around.
  @visibleForTesting
  set httpClientAdapter(HttpClientAdapter adapter) =>
      _dio.httpClientAdapter = adapter;

  InterceptorsWrapper _buildInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.headers.addAll(_deviceInfo.headers);

        final token = await _tokenStorage.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        final qp = options.queryParameters.isNotEmpty
            ? ' params=${options.queryParameters}'
            : '';
        final body = options.data != null ? '\n  body: ${options.data}' : '';
        logger.d('→ ${options.method} ${options.path}$qp$body');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        logger.d(
          '← ${response.statusCode} ${response.requestOptions.method} '
          '${response.requestOptions.path}\n${response.data}',
        );
        return handler.next(response);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        final path = error.requestOptions.path;
        final responseBody = error.response?.data;

        logger.e(
          '← $statusCode ${error.requestOptions.method} $path: ${error.message}'
          '${responseBody != null ? '\n  response: $responseBody' : ''}',
        );

        if (statusCode == 401 &&
            !path.contains(ApiEndpoints.refresh) &&
            !path.contains(ApiEndpoints.login) &&
            !path.contains(ApiEndpoints.register) &&
            !path.contains(ApiEndpoints.beaconsAuth)) {
          // A guest has no session to expire. Without this, a stale access
          // token that outlived its refresh token drags anyone browsing
          // signed-out onto the sign-in screen.
          final refresh = await _tokenStorage.refreshToken;
          if (refresh == null || refresh.isEmpty) {
            final stale = await _tokenStorage.accessToken;
            if (stale != null && stale.isNotEmpty) {
              await _tokenStorage.clearAll();
            }
            return handler.next(error);
          }

          final outcome = await _tryRefreshToken();
          final action = sessionActionFor(
            hasRefreshToken: true,
            outcome: outcome,
          );
          if (action == SessionAction.retry) {
            try {
              final newToken = await _tokenStorage.accessToken;
              final retryOpts = error.requestOptions;
              retryOpts.headers['Authorization'] = 'Bearer $newToken';
              final response = await _dio.fetch(retryOpts);
              return handler.resolve(response);
            } catch (_) {
              // The retry failed on its own terms; the session is still good.
              return handler.next(error);
            }
          }
          // Only a refusal ends the session. If the refresh could not reach the
          // server the tokens are probably still valid, and signing the user
          // out over a dropped connection loses their session for good.
          if (action == SessionAction.endSession) {
            await _handleSessionExpiry();
          }
        }

        return handler.next(error);
      },
    );
  }

  /// Renews the session, joining a refresh already under way rather than
  /// starting a competing one.
  ///
  /// Everything that renews goes through here — the interceptor on a 401
  /// and the splash screen on launch alike. Two paths refreshing at once
  /// would spend the same rotating token twice, and the loser's 401 would
  /// tear down the session the winner had just renewed.
  Future<RefreshOutcome> refreshSession() => _tryRefreshToken();

  /// Refreshes once, however many callers ask at the same time.
  Future<RefreshOutcome> _tryRefreshToken() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    late final Future<RefreshOutcome> attempt;
    attempt = _refreshOnce().whenComplete(() {
      // Only ever clears itself: a later refresh may already have taken
      // its place by the time this one finishes.
      if (identical(_refreshInFlight, attempt)) _refreshInFlight = null;
    });
    _refreshInFlight = attempt;
    return attempt;
  }

  Future<RefreshOutcome> _refreshOnce() async {
    final refresh = await _tokenStorage.refreshToken;
    if (refresh == null || refresh.isEmpty) return RefreshOutcome.rejected;
    try {
      final response = await _dio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refresh},
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        await _tokenStorage.saveSession(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        );
        // The response carries the account too; caching it here means the
        // launch path gets everything it used to without a second refresh.
        if (data['user'] case final Map<String, dynamic> user) {
          await LocalStorage.setString(
            LocalStorage.cachedUserKey,
            GtubeUser.fromJson(user).toJsonString(),
          );
        }
        return RefreshOutcome.refreshed;
      }
      return RefreshOutcome.rejected;
    } on DioException catch (e) {
      // No response at all means we never reached the server.
      if (e.response == null) {
        logger.w('Token refresh unreachable — keeping the session');
        return RefreshOutcome.unavailable;
      }
      final status = e.response?.statusCode ?? 0;
      if (status == 401 || status == 403) return RefreshOutcome.rejected;
      logger.w('Token refresh failed with $status — keeping the session');
      return RefreshOutcome.unavailable;
    } catch (e) {
      logger.e('Token refresh errored', error: e);
      return RefreshOutcome.unavailable;
    }
  }

  Future<void> _handleSessionExpiry() async {
    if (_isHandlingExpiry) return;
    _isHandlingExpiry = true;
    try {
      await _tokenStorage.clearAll();
      onSessionExpired?.call();
    } finally {
      _isHandlingExpiry = false;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _dio.post<T>(
    path,
    data: data,
    queryParameters: queryParameters,
    options: options,
  );

  Future<Response<T>> put<T>(String path, {dynamic data, Options? options}) =>
      _dio.put<T>(path, data: data, options: options);

  Future<Response<T>> patch<T>(String path, {dynamic data, Options? options}) =>
      _dio.patch<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(String path, {Options? options}) =>
      _dio.delete<T>(path, options: options);
}
