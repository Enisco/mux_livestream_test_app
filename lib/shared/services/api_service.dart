import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/shared/services/device_info_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

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

  Future<RefreshOutcome> _tryRefreshToken() async {
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
