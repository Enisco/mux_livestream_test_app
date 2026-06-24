import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../../core/logger.dart';
import '../../../services/api_service.dart';
import '../../../services/token_storage_service.dart';
import '../../../utils/api_endpoints.dart';
import '../../../utils/local_storage.dart';
import '../models/auth_models.dart';

class AuthRepo {
  final ApiService _api = GetIt.instance<ApiService>();
  final TokenStorageService _tokenStorage =
      GetIt.instance<TokenStorageService>();

  Future<RegisterResponse> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String gender,
    required String countryCode,
  }) async {
    final response = await _api.post(
      ApiEndpoints.register,
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'gender': gender,
        'countryCode': countryCode,
      },
    );
    return RegisterResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      ApiEndpoints.login,
      data: {
        'email': email,
        'password': password,
        'rememberDevice': true,
        'clientType': 'native',
      },
    );
    final result = LoginResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
    await _tokenStorage.saveSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      sessionId: result.session.id,
    );
    await LocalStorage.setString(
      LocalStorage.cachedUserKey,
      result.user.toJsonString(),
    );
    return result;
  }

  /// Called on every app launch after a stored refresh token is found.
  /// Sends refresh token in JSON body, updates stored tokens + user cache.
  /// Returns false (and clears session) if the server rejects the token.
  Future<bool> tryRefreshSession() async {
    if (!await _tokenStorage.hasSession) return false;
    try {
      final refresh = await _tokenStorage.refreshToken;
      final response = await _api.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refresh},
        options: Options(
          // Skip the auth interceptor adding the expired access token here —
          // the interceptor won't loop because this path contains 'sessions/refresh'.
          headers: {},
        ),
      );
      final result = RefreshSessionResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      await _tokenStorage.saveSession(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      await LocalStorage.setString(
        LocalStorage.cachedUserKey,
        result.user.toJsonString(),
      );
      return true;
    } catch (e) {
      logger.e('Session refresh failed', error: e);
      await _tokenStorage.clearAll();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiEndpoints.logout);
    } catch (_) {}
    await _tokenStorage.clearAll();
    await LocalStorage.remove(LocalStorage.cachedUserKey);
    await LocalStorage.clearCreatorData();
  }

  GtubeUser? getCachedUser() => GtubeUser.fromJsonString(
    LocalStorage.getString(LocalStorage.cachedUserKey),
  );
}
