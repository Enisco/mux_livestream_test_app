part of 'auth_bloc.dart';

abstract class AuthEvent {}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;

  AuthSignInRequested({required this.email, required this.password});
}

class AuthSignUpRequested extends AuthEvent {
  final String firstName;
  final String lastName;
  final String email;
  final String password;

  // Optional per RegisterUserDto — the design marks phone and gender optional
  // and has no country field, so countryCode comes from the device locale.
  final String? phone;
  final String? gender;
  final String? countryCode;

  AuthSignUpRequested({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    this.phone,
    this.gender,
    this.countryCode,
  });
}

class AuthLogoutRequested extends AuthEvent {}
