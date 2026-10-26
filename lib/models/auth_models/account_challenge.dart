/// The step between asking for a credential change and it happening.
///
/// `POST /v1/user/me/email-change` and `POST /v1/user/me/two-factor/enable`
/// answer the same shape, so the OTP screen behind both decodes one model.
library;

class AccountChallenge {
  const AccountChallenge({
    required this.challengeId,
    required this.maskedDestination,
    this.expiresAt,
    this.resendAvailableAt,
    this.delivery = 'email',
  });

  final String challengeId;

  /// `n•••w@example.com` — so the screen can name where the code went without
  /// echoing back an address typed into a field that has scrolled away.
  ///
  /// The email change calls this `maskedNewEmail` (the code goes to the new
  /// address); enabling 2FA calls it `maskedEmail` (there is no new address).
  /// Both land here.
  final String maskedDestination;

  /// Ten minutes out. A verify after this is a 401, not a wrong code.
  final DateTime? expiresAt;

  /// What the resend countdown counts down to. Reading it beats the client
  /// inventing an interval and then disagreeing with the server's cooldown.
  final DateTime? resendAvailableAt;

  final String delivery;

  /// Seconds until a resend is allowed, floored at zero.
  ///
  /// The OTP view takes a cooldown in seconds; this is where the server's
  /// instant becomes one. A missing `resendAvailableAt` falls back to the
  /// 60 seconds the view defaults to rather than enabling the button at once.
  int get resendCooldownSeconds {
    final at = resendAvailableAt;
    if (at == null) return 60;
    final left = at.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  factory AccountChallenge.fromJson(Map<String, dynamic> json) =>
      AccountChallenge(
        challengeId: json['challengeId'] as String? ?? '',
        maskedDestination:
            json['maskedNewEmail'] as String? ??
            json['maskedEmail'] as String? ??
            '',
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
        resendAvailableAt: DateTime.tryParse(
          json['resendAvailableAt'] as String? ?? '',
        ),
        delivery: json['delivery'] as String? ?? 'email',
      );
}

/// What `POST /v1/user/me/password` answers.
class PasswordChangeResult {
  const PasswordChangeResult({
    required this.currentSessionRetained,
    this.sessionsRevoked = 0,
    this.passwordChangedAt,
  });

  /// False when the calling session went with the others — which happens when
  /// no `refreshToken` was sent. The next call will 401, so the app has to
  /// send the reader back to sign-in rather than assume it survived.
  final bool currentSessionRetained;

  /// How many **other** sessions ended.
  final int sessionsRevoked;

  final DateTime? passwordChangedAt;

  factory PasswordChangeResult.fromJson(Map<String, dynamic> json) =>
      PasswordChangeResult(
        currentSessionRetained:
            json['currentSessionRetained'] as bool? ?? false,
        sessionsRevoked: (json['sessionsRevoked'] as num?)?.toInt() ?? 0,
        passwordChangedAt: DateTime.tryParse(
          json['passwordChangedAt'] as String? ?? '',
        ),
      );
}
