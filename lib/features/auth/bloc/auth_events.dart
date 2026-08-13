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
