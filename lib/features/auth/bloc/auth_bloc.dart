import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/logger.dart';
import '../../../features/creator/repo/creator_repo.dart';
import '../models/auth_models.dart';
import '../repo/auth_repo.dart';

part 'auth_event.dart';
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

  // ------------------------------------------------------------------
  // Sign in
  // ------------------------------------------------------------------

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

      // Ensure stream credentials are fresh for this device/session.
      final creatorId = await _provisionIfNeeded(response.user.id);
      emit(AuthSuccess(response.user, creatorId: creatorId));
    } on DioException catch (e) {
      emit(AuthFailure(_extractMessage(e)));
    } catch (e) {
      logger.e('Unexpected sign-in error', error: e);
      emit(AuthFailure('Something went wrong. Please try again.'));
    }
  }

  // ------------------------------------------------------------------
  // Sign up → auto-login → onboard creator → provision stream
  // ------------------------------------------------------------------

  Future<void> _onSignUp(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // 1. Register (returns user data, no tokens)
      await _authRepo.register(
        firstName: event.firstName,
        lastName: event.lastName,
        email: event.email,
        phone: event.phone,
        password: event.password,
        gender: event.gender,
        countryCode: event.countryCode,
      );

      // 2. Auto-login to get session tokens
      final loginResp = await _authRepo.login(
        email: event.email,
        password: event.password,
      );

      // 3. Create creator channel — handle derived from email prefix
      final creatorRepo = GetIt.instance<CreatorRepo>();
      final handle = _deriveHandle(event.email);
      final creator = await creatorRepo.onboardCreator(
        handle: handle,
        displayName: event.firstName,
        bio: '${event.firstName}\'s channel on GTube',
      );

      // 4. Provision livestream profile and save credentials
      await creatorRepo.provisionLivestream(creator.id);

      emit(AuthSuccess(loginResp.user, creatorId: creator.id));
    } on DioException catch (e) {
      emit(AuthFailure(_extractMessage(e)));
    } catch (e) {
      logger.e('Unexpected sign-up error', error: e);
      emit(AuthFailure('Something went wrong. Please try again.'));
    }
  }

  // ------------------------------------------------------------------
  // Logout
  // ------------------------------------------------------------------

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepo.logout();
    emit(AuthLoggedOut());
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /// Provisions the livestream profile if creatorId is available in storage.
  /// Safe to call on every login — the endpoint is idempotent.
  Future<String?> _provisionIfNeeded(String userId) async {
    try {
      final creatorRepo = GetIt.instance<CreatorRepo>();
      // Use stored creatorId; on a fresh device it may be null.
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
    // Use cached value if present (common case). Otherwise fetch from the
    // profile endpoint — happens after logout/re-login or on a fresh device.
    return creatorRepo.cachedCreatorId ??
        await creatorRepo.fetchAndCacheCreatorId();
  }

  /// Converts email prefix to a clean lowercase handle.
  String _deriveHandle(String email) {
    final prefix = email.split('@').first;
    final clean = prefix.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (clean.isEmpty) {
      return 'user${DateTime.now().millisecondsSinceEpoch % 100000}';
    }
    return clean.length > 20 ? clean.substring(0, 20) : clean;
  }

  String _extractMessage(DioException e) {
    if (e.response?.data is Map) {
      final data = e.response!.data as Map;
      final msg = data['message'];
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
