import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/logger.dart';
import '../utils/api_endpoints.dart';
import 'device_info_service.dart';
import 'token_storage_service.dart';

class ApiService {
  late final Dio _dio;
  bool _isHandlingExpiry = false;

  final TokenStorageService _tokenStorage;
  final DeviceInfoService _deviceInfo;

  // Set by locator once the router exists — avoids circular dependency.
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

        logger.d('→ ${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        logger.d(
          '← ${response.statusCode} ${response.requestOptions.path}\n${response.data}',
        );
        return handler.next(response);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        final path = error.requestOptions.path;

        logger.e('← $statusCode $path: ${error.message}');

        // Silent token refresh on 401, but never for auth endpoints themselves.
        if (statusCode == 401 &&
            !path.contains(ApiEndpoints.refresh) &&
            !path.contains(ApiEndpoints.login) &&
            !path.contains(ApiEndpoints.register)) {
          try {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final newToken = await _tokenStorage.accessToken;
              final retryOpts = error.requestOptions;
              retryOpts.headers['Authorization'] = 'Bearer $newToken';
              final response = await _dio.fetch(retryOpts);
              return handler.resolve(response);
            }
          } catch (_) {}
          await _handleSessionExpiry();
        }

        return handler.next(error);
      },
    );
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final refresh = await _tokenStorage.refreshToken;
      if (refresh == null || refresh.isEmpty) return false;

      // Refresh endpoint: POST with JSON body {"refreshToken": "..."}
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
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Token refresh failed', error: e);
      return false;
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

  // HTTP helpers --------------------------------------------------------

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
