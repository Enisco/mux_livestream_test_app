/// What the two-factor screens read out.
///
/// TEMPORARY, and the gap here is wider than a missing payload.
///
/// The design describes **TOTP**: a secret shown as a QR, added to Google
/// Authenticator or Authy, then confirmed with the code the app generates.
/// Nothing in the staging spec enrols a TOTP authenticator — there is no route
/// that mints a secret, none that confirms one, and none that turns 2FA off.
///
/// What does exist is `POST /v1/auth/2fa/challenges/verify` and
/// `POST /v1/auth/2fa/challenges/resend-otp`. A *resend* only makes sense for
/// a code the server sends out, so the backend's second factor looks like a
/// mailed or texted OTP rather than an authenticator app. That is a different
/// feature from the one drawn here, and worth settling before this is wired.
///
/// To retire this file: delete it and fix the import errors in
/// `two_factor_screens.dart`.
abstract final class TwoFactorDummyData {
  /// The shared secret, in the four-character groups the design prints.
  static const secret = 'BSW Y3DP EHPK 3PXP';

  /// What the QR encodes. `otpauth://` is the standard every authenticator
  /// app reads, so the placeholder is at least the right shape.
  static String get provisioningUri {
    final key = secret.replaceAll(' ', '');
    return 'otpauth://totp/GospelTube:you@example.com'
        '?secret=$key&issuer=GospelTube&algorithm=SHA1&digits=6&period=30';
  }

  /// Whether the account already has a second factor, and what the manage
  /// screen says about it.
  static const enabled = false;
  static const enabledOn = 'Enabled Jun 9';
  static const method = 'authenticator app';
}
