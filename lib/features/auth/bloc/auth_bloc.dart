import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/models/auth_models/auth_models.dart';

part 'auth_events.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepo _authRepo;

  AuthBloc({AuthRepo? repo})
    : _authRepo = repo ?? AuthRepo(),
      super(AuthInitial()) {
    on<AuthSignInRequested>(_onSignIn);
    on<AuthSignUpRequested>(_onSignUp);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onSignIn(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _authRepo.login(
        email: event.email,
        password: event.password,
      );

      final creatorId = await _provisionIfNeeded(response.user.id);
      emit(AuthSuccess(response.user, creatorId: creatorId));
    } on DioException catch (e) {
      emit(AuthFailure(_extractMessage(e)));
    } catch (e) {
      logger.e('Unexpected sign-in error', error: e);
      emit(AuthFailure('Something went wrong. Please try again.'));
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

      final loginResp = await _authRepo.login(
        email: event.email,
        password: event.password,
      );

      emit(AuthSuccess(loginResp.user));
    } on DioException catch (e) {
      emit(AuthFailure(_extractMessage(e)));
    } catch (e) {
      logger.e('Unexpected sign-up error', error: e);
      emit(AuthFailure('Something went wrong. Please try again.'));
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepo.logout();
    emit(AuthLoggedOut());
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
      DioExceptionType.receiveTimeout =>
        'Connection timed out. Please try again.',
      DioExceptionType.connectionError => 'No internet connection.',
      _ => 'Request failed. Please try again.',
    };
  }
}
