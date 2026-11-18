import 'package:get_it/get_it.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/models/auth_models/auth_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/social_sign_in.dart';
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
  Future<void> completePasswordReset({
    required String token,
    required String newPassword,
  }) async {
    await _api.post(
      ApiEndpoints.resetPassword,
      data: {'token': token, 'newPassword': newPassword},
    );
  }

  /// Finishes a second-factor challenge.
  ///
  /// `clientType` has to be carried through from the call that raised the
  /// challenge: the guide is explicit that *"a native client that omits it
  /// here gets cookies it cannot use and no tokens"* — a silent sign-in
  /// that leaves the app signed out.
  Future<AuthOutcome> verifyChallenge({
    required String challengeId,
    required String code,
  }) async {
    final response = await _api.post(
      ApiEndpoints.verify2faChallenge,
      data: {'challengeId': challengeId, 'code': code, 'clientType': 'native'},
    );
    return _settle(response.data as Map<String, dynamic>);
  }

  /// Rotates the code. Anything the person already has stops working, so a
  /// screen clears its field and restarts the countdown from the window
  /// this answers with.
  Future<int> resendChallengeOtp({required String challengeId}) async {
    final response = await _api.post(
      ApiEndpoints.resend2faOtp,
      data: {'challengeId': challengeId},
    );
    // Read loosely, because nothing here is load-bearing: the new code is
    // already in the mailbox by the time this returns, and the view's own
    // countdown is the 60-second resend cooldown. Throwing over the shape
    // of a window nobody displays would leave the view with no new code
    // *and* nothing to read — Resend doing visibly nothing.
    final data = response.data;
    final window = data is Map && data['data'] is Map
        ? data['data']['expiresInMinutes']
        : null;
    return switch (window) {
      final num n => n.toInt(),
      final String s => int.tryParse(s) ?? 10,
      _ => 10,
    };
  }

  Future<AuthOutcome> login({
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
    return _settle(response.data as Map<String, dynamic>);
  }

  /// `POST /v1/auth/providers/{google|apple}/sign-in`.
  ///
  /// One call covers all three things it can mean: a new account, a return
  /// visit, and linking the provider to an account that was registered with
  /// the same **verified** address. Which of the three happened is the
  /// server's answer, not a question the app asks first.
  Future<AuthOutcome> signInWithProvider(SocialCredential credential) async {
    final response = await _api.post(
      ApiEndpoints.providerSignIn(credential.provider.slug),
      data: {
        'idToken': credential.idToken,
        // Apple only. Sent with every Apple sign-in and never with a
        // `redirectUri`, which the route refuses alongside an id token.
        'authorizationCode': ?_orNull(credential.authorizationCode),
        // Only when the token carries one — the gateway then requires it.
        'nonce': ?_orNull(credential.nonce),
        // Apple hands these over once and never again, so an account made
        // without them has no name at all.
        'firstName': ?_orNull(credential.firstName),
        'lastName': ?_orNull(credential.lastName),
        'clientType': 'native',
        'rememberDevice': true,
      },
    );
    return _settle(response.data as Map<String, dynamic>);
  }

  /// Leaves an optional field out rather than sending it empty.
  ///
  /// Every one of these is a field the gateway validates when it is
  /// present, and `authorizationCode` is non-nullable in the Apple plugin
  /// — so an empty one would travel as `""` and be judged, rather than
  /// simply not asked about.
  static String? _orNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Stores whatever a sign-in answered, and nothing when it answered a
  /// challenge — there is no session to store until that is finished.
  Future<AuthOutcome> _settle(Map<String, dynamic> body) async {
    final outcome = AuthOutcome.fromEnvelope(body);
    if (outcome is! AuthSignedIn) return outcome;

    final result = outcome.session;
    await _tokenStorage.saveSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      sessionId: result.session.id,
    );
    // Anything keyed to whoever was signed in before has to go, even though
    // `logout` already clears it: a session that simply expired never runs
    // `logout`, so the next person to sign in on this device inherited the
    // previous account's `creatorId` — and with it their studio, which the
    // studio screens key off entirely.
    await LocalStorage.clearCreatorData();
    await LocalStorage.setString(
      LocalStorage.cachedUserKey,
      result.user.toJsonString(),
    );
    return outcome;
  }

  /// Renews the session at launch.
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
