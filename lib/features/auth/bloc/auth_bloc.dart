import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:test_app/features/notifications/data/notification_store.dart';
import 'package:test_app/shared/services/push_service.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/models/auth_models/auth_models.dart';
import 'package:test_app/shared/services/social_sign_in.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

part 'auth_events.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepo _authRepo;
  final SocialSignInService _social;

  AuthBloc({AuthRepo? repo, SocialSignInService? social})
    : _authRepo = repo ?? AuthRepo(),
      _social = social ?? SocialSignIn(),
      super(AuthInitial()) {
    on<AuthSignInRequested>(_onSignIn);
    on<AuthSignUpRequested>(_onSignUp);
    on<AuthSocialSignInRequested>(_onSocialSignIn);
    on<AuthLogoutRequested>(_onLogout);
  }

  /// Whether a provider button should be drawn at all on this build.
  bool offers(SocialProvider provider) => _social.isOffered(provider);

  Future<void> _onSignIn(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final outcome = await _authRepo.login(
        email: event.email,
        password: event.password,
      );
      emit(await _resolve(outcome, email: event.email));
    } on AuthContractException catch (e) {
      logger.e('Login answered a shape with no session', error: e);
      emit(AuthFailure(AppStrings.authContractBroken));
    } on DioException catch (e) {
      emit(AuthFailure(_extractMessage(e)));
    } catch (e) {
      logger.e('Unexpected sign-in error', error: e);
      emit(AuthFailure(AppStrings.somethingWentWrong));
    }
  }

  Future<void> _onSignUp(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepo.register(
        firstName: event.firstName,
        lastName: event.lastName,
        email: event.email,
        phone: event.phone,
        password: event.password,
        gender: event.gender,
        countryCode: event.countryCode,
      );

      // Registering does not sign anybody in, so the password is spent
      // once more here — and this login is challenged like any other when
      // the account carries the platform's default second factor.
      final outcome = await _authRepo.login(
        email: event.email,
        password: event.password,
      );

      emit(await _resolve(outcome, email: event.email, isNewUser: true));
    } on AuthContractException catch (e) {
      logger.e('Sign-up login answered a shape with no session', error: e);
      emit(AuthFailure(AppStrings.authContractBroken));
    } on DioException catch (e) {
      emit(AuthFailure(_extractMessage(e)));
    } catch (e) {
      logger.e('Unexpected sign-up error', error: e);
      emit(AuthFailure(AppStrings.somethingWentWrong));
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Take this device off the account's push list before the session goes,
    // so the next person to hold the phone does not get their notifications.
    // It needs the session to authorise, hence before `logout`.
    await GetIt.instance<PushService>().unregister();
    await _authRepo.logout();
    GetIt.instance<NotificationStore>().clear();
    emit(AuthLoggedOut());
  }

  Future<void> _onSocialSignIn(
    AuthSocialSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    // One provider at a time. Events are processed concurrently by
    // default, and the two buttons are only disabled on the frame *after*
    // the first emit — so two fingers landing together started two flows,
    // and two sheets racing to present is a failure on both platforms.
    // Safe to drop the second because neither SDK can leave this pending:
    // `authenticate()` always completes or throws, and Apple's own docs
    // promise the same on iOS (which is the only place it is offered).
    if (state is AuthSocialLoading) return;

    emit(AuthSocialLoading(event.provider));
    try {
      final credential = await _social.start(event.provider);
      final outcome = await _authRepo.signInWithProvider(credential);
      emit(await _resolve(outcome));
    } on SocialSignInException catch (e) {
      // The detail, never the credential: an id token is a bearer token
      // for the person's Google or Apple account and does not go in a log.
      // The detail is the SDK's own code and description, and it is the
      // whole story when the complaint is "the button does nothing" — a
      // missing SHA-1 or the wrong server client id reads as a plain
      // cancellation on Android otherwise.
      logger.w(
        'Provider sign-in did not complete: ${e.failure}'
        '${e.detail == null ? '' : ' — ${e.detail}'}',
      );
      emit(switch (e.failure) {
        SocialSignInFailure.cancelled => AuthCancelled(),
        SocialSignInFailure.unsupported => AuthFailure(
          AppStrings.socialUnsupported,
        ),
        SocialSignInFailure.unconfigured => AuthFailure(
          AppStrings.socialUnavailable,
        ),
        _ => AuthFailure(AppStrings.socialFailed),
      });
    } on AuthContractException catch (e) {
      logger.e('Provider sign-in answered a shape with no session', error: e);
      emit(AuthFailure(AppStrings.authContractBroken));
    } on DioException catch (e) {
      emit(AuthFailure(_extractMessage(e)));
    } catch (e) {
      logger.e('Unexpected provider sign-in error', error: e);
      emit(AuthFailure(AppStrings.somethingWentWrong));
    }
  }

  /// Turns either arm of the union into the state a screen acts on.
  ///
  /// `isNewUser` is the server's where it says so and the caller's
  /// otherwise, because only the provider routes report it — registering
  /// through the form is the one other way an account is new, and that
  /// path knows it already.
  Future<AuthState> _resolve(
    AuthOutcome outcome, {
    String? email,
    bool isNewUser = false,
  }) async {
    switch (outcome) {
      case AuthChallengeRequired():
        return AuthTwoFactorRequired(
          challengeId: outcome.challengeId,
          // The server's address wins where it gave one: a provider
          // account can be signed in under an Apple private relay that the
          // person never typed anywhere.
          email: outcome.email ?? email,
          isNewUser: isNewUser || outcome.isNewUser,
        );
      case AuthSignedIn(:final session):
        final creatorId = await _provisionIfNeeded(session.user.id);
        return AuthSuccess(
          session.user,
          creatorId: creatorId,
          isNewUser: isNewUser || session.isNewUser,
        );
    }
  }

  Future<String?> _provisionIfNeeded(String userId) async {
    try {
      final creatorRepo = GetIt.instance<CreatorRepo>();
      final creatorId = await _resolveCreatorId(userId);
      if (creatorId == null) return null;
      await creatorRepo.provisionLivestream(creatorId);
      return creatorId;
    } catch (e) {
      logger.w('Provision on sign-in failed (non-fatal)', error: e);
      return null;
    }
  }

  Future<String?> _resolveCreatorId(String userId) async {
    final creatorRepo = GetIt.instance<CreatorRepo>();
    return creatorRepo.cachedCreatorId ??
        await creatorRepo.fetchAndCacheCreatorId();
  }

  String _extractMessage(DioException e) {
    if (e.response?.data is Map) {
      final data = e.response!.data as Map;
      final msg = data['error'];
      if (msg is String && msg.isNotEmpty) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
    }
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => AppStrings.authTimedOut,
      DioExceptionType.connectionError => AppStrings.authNoConnection,
      _ => AppStrings.authRequestFailed,
    };
  }
}
