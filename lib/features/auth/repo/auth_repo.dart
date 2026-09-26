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

  /// Finishes a reset with the token from the email.
  ///
  /// `POST /v1/auth/password/reset` takes `{token, newPassword}` and answers
  /// **"Invalid or expired reset token."** for a token that has been used,
  /// has lapsed, or was never issued — one message for all three, so the
  /// screen cannot tell the reader which it was.
  ///
  /// `newPassword` is bounded at 8–128 characters server-side.
  Future<void> completePasswordReset({
    required String token,
    required String newPassword,
  }) async {
    await _api.post(
      ApiEndpoints.resetPassword,
      data: {'token': token, 'newPassword': newPassword},
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

  /// Renews the session at launch.
  ///
  /// This goes through [ApiService.refreshSession] rather than posting to
  /// the refresh route itself. Refresh tokens rotate, so a refresh here
  /// racing one the interceptor started — which is exactly what a cold
  /// start produces — would spend the same token twice and the loser's 401
  /// would clear a session that had just been renewed.
  Future<bool> tryRefreshSession() async {
    if (!await _tokenStorage.hasSession) return false;

    final outcome = await _api.refreshSession();
    switch (outcome) {
      case RefreshOutcome.refreshed:
        return true;
      case RefreshOutcome.rejected:
        logger.e('Session refresh rejected');
        await _tokenStorage.clearAll();
        return false;
      case RefreshOutcome.unavailable:
        // Never reached the server, so the tokens are probably still good;
        // signing the reader out over a dropped connection would lose the
        // session for nothing.
        logger.w('Session refresh unreachable — keeping cached session');
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
