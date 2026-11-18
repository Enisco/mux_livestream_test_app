part of 'auth_bloc.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

/// A provider sign-in is in flight. Which provider, so only the button
/// that was tapped spins — two buttons busy at once reads as the app
/// having lost track of which was pressed.
class AuthSocialLoading extends AuthState {
  AuthSocialLoading(this.provider);

  final SocialProvider provider;
}

class AuthSuccess extends AuthState {
  final GtubeUser user;
  final String? creatorId;

  /// This sign-in created the account, so onboarding comes next rather
  /// than the feed. Only the provider routes can report it.
  final bool isNewUser;

  AuthSuccess(this.user, {this.creatorId, this.isNewUser = false});
}

/// The account wants the code it was just emailed. No session exists yet.
class AuthTwoFactorRequired extends AuthState {
  AuthTwoFactorRequired({
    required this.challengeId,
    this.email,
    this.isNewUser = false,
  });

  final String challengeId;
  final String? email;
  final bool isNewUser;
}

/// The person backed out of the provider's own sheet. Not a failure, and
/// never worded as one — it exists only so a spinning button stops.
class AuthCancelled extends AuthState {}

class AuthRegistered extends AuthState {}

class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
}

class AuthLoggedOut extends AuthState {}
