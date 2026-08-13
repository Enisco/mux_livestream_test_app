import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/models/auth_models/auth_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

class AuthRepo {
  final ApiService _api = GetIt.instance<ApiService>();
  final TokenStorageService _tokenStorage =
      GetIt.instance<TokenStorageService>();

  Future<RegisterResponse> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    String? gender,
    String? countryCode,
  }) async {
    final response = await _api.post(
      ApiEndpoints.register,
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email.toLowerCase(),
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (countryCode != null && countryCode.isNotEmpty)
          'countryCode': countryCode,
      },
    );
    return RegisterResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> requestPasswordReset({required String email}) async {
    await _api.post(
      ApiEndpoints.forgotPassword,
      data: {'email': email.toLowerCase()},
    );
  }

  Future<void> verifyChallenge({
    required String challengeId,
    required String code,
  }) async {
    await _api.post(
      ApiEndpoints.verify2faChallenge,
      data: {'challengeId': challengeId, 'code': code},
    );
  }

  Future<void> resendChallengeOtp({required String challengeId}) async {
    await _api.post(
      ApiEndpoints.resend2faOtp,
      data: {'challengeId': challengeId},
    );
  }

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      ApiEndpoints.login,
      data: {
        'email': email.toLowerCase(),
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

  Future<bool> tryRefreshSession() async {
    if (!await _tokenStorage.hasSession) return false;
    try {
      final refresh = await _tokenStorage.refreshToken;
      final response = await _api.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refresh},
        options: Options(headers: {}),
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
      final status = e is DioException ? e.response?.statusCode : null;
      if (status != null && status >= 400 && status < 500) {
        logger.e('Session refresh rejected ($status)', error: e);
        await _tokenStorage.clearAll();
        return false;
      }
      logger.w(
        'Session refresh unreachable — keeping cached session',
        error: e,
      );
      return true;
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
