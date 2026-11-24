import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/utils/helpers/keyboard.dart';

/// Which identity provider a credential came from.
///
/// The slugs are the gateway's own path segment —
/// `POST /v1/auth/providers/{provider}/sign-in` answers
/// *"provider must be one of the following values: google, apple"* to
/// anything else, so there is nothing else to model.
enum SocialProvider {
  google('google'),
  apple('apple');

  const SocialProvider(this.slug);

  /// The `{provider}` path segment.
  final String slug;
}

/// The OAuth client identifiers this build signs in with.
///
/// They live in `.env` beside `BASE_URL` because they are **per
/// environment**, not per release: staging and production are different
/// Google projects and different Apple App IDs. None of them is a secret —
/// an OAuth client id ships inside every copy of every app that uses it —
/// but a build pointed at the wrong one fails verification at the gateway
/// rather than anywhere a creator could understand.
abstract final class SocialAuthConfig {
  /// The **web** OAuth client id, passed as Google's server client id.
  ///
  /// This is what decides the `aud` claim of the id token on both
  /// platforms, and the gateway accepts the web client as an audience
  /// without anything being added to `GOOGLE_OAUTH_NATIVE_CLIENT_IDS`.
  static String get googleServerClientId => _read('GOOGLE_SERVER_CLIENT_ID');

  /// The **iOS** OAuth client id, which only iOS needs.
  ///
  /// Android resolves the app by package name and signing certificate
  /// against the Android client registered in the same Google project, so
  /// it carries no client id at all. iOS has no such handshake and must be
  /// told which client it is — along with the matching reversed-client-id
  /// URL scheme in `Info.plist`, which is what Google redirects back to.
  static String get googleIosClientId => _read('GOOGLE_IOS_CLIENT_ID');

  /// Reading this before `dotenv.load` throws rather than answering empty,
  /// and a missing identifier means "this build does not offer that
  /// button" — never a crash on the first screen of the app.
  static String _read(String key) {
    try {
      return (dotenv.env[key] ?? '').trim();
    } catch (_) {
      return '';
    }
  }
}

/// What the platform handed back, in the shape the gateway takes it.
@immutable
class SocialCredential {
  const SocialCredential({
    required this.provider,
    required this.idToken,
    this.authorizationCode,
    this.nonce,
    this.firstName,
    this.lastName,
  });

  final SocialProvider provider;

  /// The signed assertion the gateway verifies. The one required field.
  final String idToken;

  /// Apple only, and sent on **every** Apple sign-in: `user-service` trades
  /// it for a refresh token and keeps that, so deleting the account can
  /// revoke the person's Apple link — which Apple requires of every app
  /// that offers Sign in with Apple. Google ignores the field.
  final String? authorizationCode;

  /// Sent whenever the token carries one, because the gateway then insists
  /// on it. Passed raw: the guide says the provider may hold it as given or
  /// as its lowercase SHA-256 hex, and Apple holds a native request's nonce
  /// verbatim.
  final String? nonce;

  /// Apple gives a name to the client on the **first** authorization only
  /// and never puts it in the token, so an account created without these
  /// has no name anywhere. Absent on later sign-ins, which is correct — the
  /// account already has them.
  final String? firstName;
  final String? lastName;
}

/// Why a sign-in produced no credential.
enum SocialSignInFailure {
  /// The person backed out. Not an error, and never worded as one.
  cancelled,

  /// This build carries no client id for that provider, so the button
  /// should not have been offered. See [SocialAuthConfig].
  unconfigured,

  /// The platform cannot do it at all — Apple on Android, anything on web.
  unsupported,

  /// The flow finished but handed back no id token. Nothing to send.
  noCredential,

  /// Everything else, including a misconfigured OAuth client.
  failed,
}

class SocialSignInException implements Exception {
  const SocialSignInException(this.failure, [this.detail]);

  final SocialSignInFailure failure;

  /// For the log, never for a person.
  final String? detail;

  @override
  String toString() => 'SocialSignInException($failure, $detail)';
}

/// Starting a provider sign-in. An interface so a screen or a bloc can be
/// tested without a platform channel under it.
abstract interface class SocialSignInService {
  /// Whether this build, on this platform, can offer [provider] at all.
  bool isOffered(SocialProvider provider);

  /// Runs the platform's own sign-in UI.
  ///
  /// Throws [SocialSignInException] for every outcome that is not a
  /// credential, cancellation included.
  Future<SocialCredential> start(SocialProvider provider);
}

/// The real thing: Google's `CredentialManager` / `GIDSignIn`, and Apple's
/// `ASAuthorizationController`.
class SocialSignIn implements SocialSignInService {
  SocialSignIn();

  /// `GoogleSignIn.instance` is a singleton that must be initialized once
  /// and only once; a second `initialize` re-inits the native SDK and
  /// subscribes a second time to its event stream. **Static**, because the
  /// thing it guards is static — a per-instance guard would let a second
  /// `SocialSignIn` init the same SDK again. Holding the future also means
  /// two taps in a row share one setup.
  static Future<void>? _googleReady;

  /// The nonce Google's token will carry, which the gateway insists on
  /// seeing: *"If the token has a nonce, you must send it."*
  ///
  /// Supplying one is the only way to **know** it. Google's iOS SDK mints a
  /// nonce of its own when none is given, puts it in the token and never
  /// tells the client — so the gateway saw a nonce in the token, got none
  /// in the request, and answered 401 on every iOS Google sign-in.
  ///
  /// It lasts as long as the process, not the attempt, because the plugin
  /// only takes a nonce at `initialize` and re-initializing subscribes a
  /// second time to the SDK's event stream. A per-run random value still
  /// does the job a nonce is for: a token minted for some other request
  /// cannot be presented here.
  static String? _googleNonce;

  /// Apple's native flow exists on Apple's own platforms. On Android and
  /// the web `sign_in_with_apple` falls back to a Chrome Custom Tab against
  /// the **Services ID**, which needs a redirect endpoint that hands the
  /// code back to the app — and the gateway publishes none
  /// (`/v1/auth/providers/apple/start` is 404; the only `/start` is the web
  /// auth app's own Next.js route). So the button is iOS-only rather than
  /// offered and broken.
  static bool get _onApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  bool isOffered(SocialProvider provider) {
    if (kIsWeb) return false;
    return switch (provider) {
      SocialProvider.google =>
        SocialAuthConfig.googleServerClientId.isNotEmpty &&
            // iOS cannot start the flow without its own client id, and a
            // button that opens a sheet which fails is worse than no
            // button.
            (!_onApplePlatform ||
                SocialAuthConfig.googleIosClientId.isNotEmpty),
      SocialProvider.apple => _onApplePlatform,
    };
  }

  @override
  Future<SocialCredential> start(SocialProvider provider) {
    // Both providers present a **native** sheet over Flutter's view, which
    // does not take the keyboard with it. Tapping the button from a form
    // that still had focus left the keyboard up behind Google's chooser and
    // still up on the feed afterwards, with nothing left to type into.
    // Here rather than on each button, because this is the moment the sheet
    // is about to appear and every caller passes through it.
    dismissKeyboard();

    if (!isOffered(provider)) {
      throw SocialSignInException(
        provider == SocialProvider.apple
            ? SocialSignInFailure.unsupported
            : SocialSignInFailure.unconfigured,
        '${provider.slug} is not offered on this build',
      );
    }
    return switch (provider) {
      SocialProvider.google => _google(),
      SocialProvider.apple => _apple(),
    };
  }

  Future<SocialCredential> _google() async {
    try {
      await _initGoogle();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const SocialSignInException(SocialSignInFailure.unsupported);
      }

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;

      // Google's own session is of no further use — the gateway's is what
      // signs anybody in. Dropping it means the next tap always offers the
      // account chooser, so a shared phone cannot sign a second person in
      // as the first.
      await _forgetGoogle();

      if (idToken == null || idToken.isEmpty) {
        throw const SocialSignInException(
          SocialSignInFailure.noCredential,
          'Google returned no id token — check the server client id',
        );
      }
      return SocialCredential(
        provider: SocialProvider.google,
        idToken: idToken,
        nonce: _googleNonce,
      );
    } on GoogleSignInException catch (e) {
      throw SocialSignInException(switch (e.code) {
        GoogleSignInExceptionCode.canceled => SocialSignInFailure.cancelled,
        // The Android SDK reports some configuration faults as a
        // cancellation and the plugin cannot tell them apart, so a missing
        // SHA or a wrong server client id can arrive here too. It still
        // reads to the person as "nothing happened", which is the one
        // honest thing to show.
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          SocialSignInFailure.unconfigured,
        _ => SocialSignInFailure.failed,
      }, '${e.code}: ${e.description}');
    }
  }

  Future<void> _initGoogle() async {
    try {
      await (_googleReady ??= GoogleSignIn.instance.initialize(
        // Unused on Android, where the app is identified by its package
        // and signing certificate; passing the iOS client there would be
        // naming the wrong client.
        clientId: _onApplePlatform ? SocialAuthConfig.googleIosClientId : null,
        serverClientId: SocialAuthConfig.googleServerClientId,
        // `generateNonce` is Apple's package, but it is a plain
        // secure-random string and there is no reason to grow a second one.
        nonce: _googleNonce ??= generateNonce(),
      ));
    } catch (e) {
      // A failed setup must not be cached, or every later tap replays it.
      _googleReady = null;
      _googleNonce = null;
      throw SocialSignInException(SocialSignInFailure.failed, '$e');
    }
  }

  Future<void> _forgetGoogle() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      // The credential is already in hand; failing to tidy up behind it is
      // not worth refusing a sign-in over.
      logger.w('Could not clear the Google session', error: e);
    }
  }

  Future<SocialCredential> _apple() async {
    // A fresh value per attempt, which is the whole point of it: the token
    // carries it, so a token captured from one attempt cannot be replayed
    // into another.
    final nonce = generateNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const SocialSignInException(SocialSignInFailure.noCredential);
      }

      return SocialCredential(
        provider: SocialProvider.apple,
        idToken: idToken,
        // Trimmed rather than passed through: the field is non-nullable in
        // the plugin, so "no code" arrives as an empty string and the
        // credential should say absent. The repo refuses to send an empty
        // optional field either way.
        authorizationCode: _trimmed(credential.authorizationCode),
        nonce: nonce,
        firstName: _trimmed(credential.givenName),
        lastName: _trimmed(credential.familyName),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      throw SocialSignInException(
        e.code == AuthorizationErrorCode.canceled
            ? SocialSignInFailure.cancelled
            : SocialSignInFailure.failed,
        '${e.code}: ${e.message}',
      );
    } on SignInWithAppleNotSupportedException catch (e) {
      throw SocialSignInException(
        SocialSignInFailure.unsupported,
        e.toString(),
      );
    } on SignInWithAppleException catch (e) {
      throw SocialSignInException(SocialSignInFailure.failed, e.toString());
    }
  }

  static String? _trimmed(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
