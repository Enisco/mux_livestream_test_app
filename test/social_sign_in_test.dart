import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_app/features/auth/views/sign_in_screen.dart';
import 'package:test_app/features/auth/views/welcome_screen.dart';
import 'package:test_app/models/auth_models/auth_models.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/social_sign_in.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_theme.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// Signing in with Google or Apple, and the second factor behind either.
///
/// The contract is `client-auth-and-session-integration_updated.md` §"Sign In
/// With Google Or Apple" and §"Login And Two-Factor Flow". Two of its rules
/// are the reason most of this file exists:
///
/// * the response `data` is a **union on `type`** and a 200 does not mean a
///   session — the second factor ships on by platform default, so this is
///   the common path, not an edge;
/// * `clientType: "native"` goes on the sign-in **and** on the verification,
///   or the gateway answers cookies the app cannot use and no tokens.
///
/// Probed against staging on 2026-11-18: the route is live for both
/// providers and both are configured (an unverifiable token answers 401
/// "We couldn't verify your Google sign-in", not the 400 an unconfigured
/// provider gives), `provider` refuses anything but `google` and `apple`,
/// and an `idToken` sent beside a `redirectUri` is refused. Nothing past
/// the credential could be exercised from here — a real id token needs a
/// real device and a real Google or Apple account.

class _RecordingApi implements ApiService {
  _RecordingApi(this.answer);

  /// The envelope the next post answers with, or a status to fail on.
  Map<String, dynamic> answer;
  int? status;

  final List<String> paths = [];
  final List<Map<String, dynamic>> bodies = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    bodies.add(Map<String, dynamic>.from(data as Map));
    final request = RequestOptions(path: path);
    if (status case final code?) {
      throw DioException.badResponse(
        statusCode: code,
        requestOptions: request,
        response: Response<dynamic>(
          requestOptions: request,
          statusCode: code,
          data: {'success': false, 'error': 'no'},
        ),
      );
    }
    return Response<T>(
      requestOptions: request,
      statusCode: 200,
      data: answer as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Tokens implements TokenStorageService {
  String? access;
  String? refresh;
  String? session;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    String? sessionId,
  }) async {
    access = accessToken;
    refresh = refreshToken;
    session = sessionId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A platform that hands back whatever the test says, without a channel.
class _FakeSocial implements SocialSignInService {
  _FakeSocial({
    this.credential,
    this.failure,
    this.offered = const {},
    this.gate,
  });

  final SocialCredential? credential;
  final SocialSignInFailure? failure;
  final Set<SocialProvider> offered;

  /// Holds the provider's sheet open, so the busy state can be looked at.
  /// Without it the whole flow finishes inside one `pump` and the screen
  /// has already navigated away.
  final Completer<void>? gate;

  SocialProvider? asked;

  @override
  bool isOffered(SocialProvider provider) => offered.contains(provider);

  @override
  Future<SocialCredential> start(SocialProvider provider) async {
    asked = provider;
    if (gate case final held?) await held.future;
    if (failure case final reason?) throw SocialSignInException(reason);
    return credential!;
  }
}

const _user = {
  'id': 'u1',
  'email': 'ada@example.com',
  'firstName': 'Ada',
  'lastName': 'Obi',
  'role': 'user',
  'status': 'active',
  'createdAt': '2026-11-01T00:00:00.000Z',
  'updatedAt': '2026-11-01T00:00:00.000Z',
};

const _session = {
  'id': 's1',
  'userId': 'u1',
  'familyId': 'f1',
  'expiresAt': '2026-12-01T00:00:00.000Z',
  'createdAt': '2026-11-01T00:00:00.000Z',
  'lastUsedAt': '2026-11-01T00:00:00.000Z',
};

Map<String, dynamic> _loggedIn({bool isNewUser = false}) => {
  'success': true,
  'data': {
    'type': 'LOGGED_IN',
    'user': _user,
    'session': _session,
    'accessToken': 'at',
    'refreshToken': 'rt',
    if (isNewUser) 'isNewUser': true,
  },
};

Map<String, dynamic> _challenge({String? email}) => {
  'success': true,
  'data': {
    'type': '2FA_REQUIRED',
    'email': ?email,
    'data': {'challengeId': 'ch1', 'expiresInMinutes': 10},
  },
};

const _google = SocialCredential(
  provider: SocialProvider.google,
  idToken: 'google-jwt',
);

const _apple = SocialCredential(
  provider: SocialProvider.apple,
  idToken: 'apple-jwt',
  authorizationCode: 'code-123',
  nonce: 'raw-nonce',
  firstName: 'Ada',
  lastName: 'Obi',
);

Future<_RecordingApi> _wire(Map<String, dynamic> answer) async {
  SharedPreferences.setMockInitialValues({});
  await LocalStorage.init();
  final api = _RecordingApi(answer);
  GetIt.instance
    ..allowReassignment = true
    ..registerSingleton<ApiService>(api)
    ..registerSingleton<TokenStorageService>(_Tokens());
  addTearDown(GetIt.instance.reset);
  return api;
}

void main() {
  setUpAll(loadAppFonts);

  group('what the gateway is handed', () {
    test('Google sends the token, and says it is a native client', () async {
      final api = await _wire(_loggedIn());

      await AuthRepo().signInWithProvider(_google);

      expect(api.paths.single, '/v1/auth/providers/google/sign-in');
      expect(api.bodies.single, {
        'idToken': 'google-jwt',
        'clientType': 'native',
        'rememberDevice': true,
      });
    });

    test('and nothing Google would refuse', () async {
      // An `idToken` sent with a `redirectUri` is refused outright, and the
      // other three keys belong to Apple. Verified against staging: a body
      // with both credentials answers "Send an idToken (with Apple's
      // authorizationCode on native), or an authorizationCode with its
      // redirectUri and nonce."
      final api = await _wire(_loggedIn());

      await AuthRepo().signInWithProvider(_google);

      expect(
        api.bodies.single.keys,
        isNot(
          contains(
            anyOf('redirectUri', 'codeVerifier', 'authorizationCode', 'nonce'),
          ),
        ),
      );
    });

    test(
      'Apple sends its authorization code, its nonce and the name',
      () async {
        // The code is sent on *every* Apple sign-in, not just the first:
        // `user-service` trades it for a refresh token and keeps that, so
        // deleting the account can revoke the Apple link — which Apple
        // requires of apps offering Sign in with Apple.
        final api = await _wire(_loggedIn(isNewUser: true));

        await AuthRepo().signInWithProvider(_apple);

        expect(api.paths.single, '/v1/auth/providers/apple/sign-in');
        expect(api.bodies.single, {
          'idToken': 'apple-jwt',
          'authorizationCode': 'code-123',
          'nonce': 'raw-nonce',
          'firstName': 'Ada',
          'lastName': 'Obi',
          'clientType': 'native',
          'rememberDevice': true,
        });
      },
    );

    test('and leaves an empty authorization code out', () async {
      // The field is non-nullable in the plugin, so an empty one would go
      // out as an empty string and be judged by the gateway rather than
      // left out of the request.
      final api = await _wire(_loggedIn());

      await AuthRepo().signInWithProvider(
        const SocialCredential(
          provider: SocialProvider.apple,
          idToken: 'apple-jwt',
          authorizationCode: '',
          nonce: 'raw-nonce',
        ),
      );

      expect(api.bodies.single.containsKey('authorizationCode'), isFalse);
    });

    test('and leaves the name out when Apple gave none', () async {
      // Apple hands a name over on the first authorization only. Sending
      // empty strings on every later sign-in would be sending the gateway
      // a name the person does not have.
      final api = await _wire(_loggedIn());

      await AuthRepo().signInWithProvider(
        const SocialCredential(
          provider: SocialProvider.apple,
          idToken: 'apple-jwt',
          authorizationCode: 'code-123',
          nonce: 'raw-nonce',
        ),
      );

      expect(api.bodies.single.containsKey('firstName'), isFalse);
      expect(api.bodies.single.containsKey('lastName'), isFalse);
    });
  });

  group('branching on the answer, which a 200 does not settle', () {
    test('a session is parsed and stored', () async {
      final api = await _wire(_loggedIn());
      final tokens = GetIt.instance<TokenStorageService>() as _Tokens;

      final outcome = await AuthRepo().signInWithProvider(_google);

      expect(outcome, isA<AuthSignedIn>());
      expect((outcome as AuthSignedIn).session.user.firstName, 'Ada');
      expect(tokens.access, 'at');
      expect(tokens.refresh, 'rt');
      expect(tokens.session, 's1');
      expect(api.paths, hasLength(1));
    });

    test(
      'isNewUser is carried through, because onboarding turns on it',
      () async {
        await _wire(_loggedIn(isNewUser: true));

        final outcome = await AuthRepo().signInWithProvider(_google);

        expect((outcome as AuthSignedIn).session.isNewUser, isTrue);
      },
    );

    test('a challenge is read from one level deeper than the rest', () async {
      // `data.data.challengeId`, not `data.challengeId`. Reading the tokens
      // straight out of `data` threw a TypeError here, on every account
      // with the second factor on — which is the platform default.
      await _wire(_challenge(email: 'ada@privaterelay.appleid.com'));

      final outcome = await AuthRepo().signInWithProvider(_apple);

      expect(outcome, isA<AuthChallengeRequired>());
      final challenge = outcome as AuthChallengeRequired;
      expect(challenge.challengeId, 'ch1');
      expect(challenge.expiresInMinutes, 10);
      expect(challenge.email, 'ada@privaterelay.appleid.com');
    });

    test('and stores no tokens, because there are none yet', () async {
      await _wire(_challenge());
      final tokens = GetIt.instance<TokenStorageService>() as _Tokens;

      await AuthRepo().signInWithProvider(_google);

      expect(tokens.access, isNull);
      expect(tokens.refresh, isNull);
    });

    test('a password login branches the same way', () async {
      // It is one union and one parse; the only route that ever reached it
      // was login, and it could not read half of it.
      await _wire(_challenge());

      final outcome = await AuthRepo().login(email: 'a@b.c', password: 'x');

      expect(outcome, isA<AuthChallengeRequired>());
    });

    test('an account with no name signs in rather than throwing', () async {
      // Apple puts no name in the token and hands one over on the first
      // authorization only, and the person may share none at all. The model
      // read both with `as String`, so that account crashed at the moment
      // of signing in.
      await _wire({
        'success': true,
        'data': {
          'type': 'LOGGED_IN',
          'user': {..._user, 'firstName': null, 'lastName': null},
          'session': _session,
          'accessToken': 'at',
          'refreshToken': 'rt',
          'isNewUser': true,
        },
      });

      final outcome = await AuthRepo().signInWithProvider(_apple);

      expect((outcome as AuthSignedIn).session.user.firstName, '');
      expect(outcome.session.user.fullName, '');
    });

    test(
      'a signed-in answer with no tokens is a sentence, not a TypeError',
      () async {
        // Reachable rather than theoretical: the same `LOGGED_IN` body omits
        // both tokens for `clientType: "web"`, so a build that stopped
        // sending "native" lands exactly here.
        await _wire({
          'success': true,
          'data': {'type': 'LOGGED_IN', 'user': _user, 'session': _session},
        });

        expect(
          () => AuthRepo().signInWithProvider(_google),
          throwsA(isA<AuthContractException>()),
        );
      },
    );

    test('and so is a challenge with no challenge in it', () async {
      await _wire({
        'success': true,
        'data': {'type': '2FA_REQUIRED', 'data': <String, dynamic>{}},
      });

      expect(
        () => AuthRepo().login(email: 'a@b.c', password: 'x'),
        throwsA(isA<AuthContractException>()),
      );
    });
  });

  group('finishing the second factor', () {
    test(
      'says it is a native client, or it gets cookies and no tokens',
      () async {
        final api = await _wire(_loggedIn());

        await AuthRepo().verifyChallenge(challengeId: 'ch1', code: '123456');

        expect(api.paths.single, '/v1/auth/2fa/challenges/verify');
        expect(api.bodies.single, {
          'challengeId': 'ch1',
          'code': '123456',
          'clientType': 'native',
        });
      },
    );

    test('and stores the session it answers with', () async {
      // The old version threw the whole response away, so a verified code
      // left the app exactly as signed out as before it.
      await _wire(_loggedIn());
      final tokens = GetIt.instance<TokenStorageService>() as _Tokens;

      final outcome = await AuthRepo().verifyChallenge(
        challengeId: 'ch1',
        code: '123456',
      );

      expect(outcome, isA<AuthSignedIn>());
      expect(tokens.access, 'at');
      expect(LocalStorage.cachedEmail, 'ada@example.com');
    });

    test('a resend reports the window it opened', () async {
      // Resending rotates the code, so the countdown restarts from this
      // answer rather than from the one that raised the challenge.
      await _wire({
        'success': true,
        'data': {'expiresInMinutes': 7},
      });

      final minutes = await AuthRepo().resendChallengeOtp(challengeId: 'ch1');

      expect(minutes, 7);
    });
  });

  group('which buttons a build offers', () {
    tearDown(() => dotenv.testLoad(fileInput: ''));

    void configure({String server = '', String ios = ''}) => dotenv.testLoad(
      fileInput: 'GOOGLE_SERVER_CLIENT_ID=$server\nGOOGLE_IOS_CLIENT_ID=$ios',
    );

    T on<T>(TargetPlatform platform, T Function() body) {
      debugDefaultTargetPlatformOverride = platform;
      try {
        return body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    test('Apple is not offered on Android, at any configuration', () {
      // `sign_in_with_apple` would fall back to a Chrome Custom Tab against
      // the web Services ID, which needs a redirect endpoint that hands the
      // code back to the app. The gateway publishes none — probed
      // 2026-11-18: `/v1/auth/providers/apple/start` is 404, and the only
      // `/start` is the web auth app's own Next.js route.
      configure(server: 'web-id', ios: 'ios-id');

      expect(
        on(TargetPlatform.android, () {
          return SocialSignIn().isOffered(SocialProvider.apple);
        }),
        isFalse,
      );
    });

    test('and is offered on iOS, which needs no identifier of ours', () {
      configure();

      expect(
        on(TargetPlatform.iOS, () {
          return SocialSignIn().isOffered(SocialProvider.apple);
        }),
        isTrue,
      );
    });

    test('Google needs the server client id', () {
      configure();

      expect(
        on(TargetPlatform.android, () {
          return SocialSignIn().isOffered(SocialProvider.google);
        }),
        isFalse,
      );
    });

    test('and nothing more than that on Android', () {
      // Android identifies the app by package name and signing certificate
      // against the Android client in the same Google project, so it
      // carries no client id of its own at all.
      configure(server: 'web-id');

      expect(
        on(TargetPlatform.android, () {
          return SocialSignIn().isOffered(SocialProvider.google);
        }),
        isTrue,
      );
    });

    test('but iOS needs its own client id too', () {
      // Without it the SDK cannot start, and the reversed form of it is
      // what Google redirects back to.
      configure(server: 'web-id');

      expect(
        on(TargetPlatform.iOS, () {
          return SocialSignIn().isOffered(SocialProvider.google);
        }),
        isFalse,
      );

      configure(server: 'web-id', ios: 'ios-id');

      expect(
        on(TargetPlatform.iOS, () {
          return SocialSignIn().isOffered(SocialProvider.google);
        }),
        isTrue,
      );
    });

    test('an unloaded environment offers nothing rather than throwing', () {
      // `dotenv.env` throws NotInitializedError before `load`, and the
      // welcome page is the first screen of the app. Note that `clean()`
      // does *not* reset the initialised flag, so a test that used it was
      // only ever reading an empty map — a fresh DotEnv is the one way to
      // get back to the uninitialised state.
      dotenv = DotEnv();
      addTearDown(() => dotenv.testLoad(fileInput: ''));

      expect(() => dotenv.env, throwsA(isA<NotInitializedError>()));
      expect(SocialAuthConfig.googleServerClientId, isEmpty);
      expect(SocialAuthConfig.googleIosClientId, isEmpty);
      expect(SocialSignIn().isOffered(SocialProvider.google), isFalse);
    });
  });

  group('what a screen is told', () {
    Future<AuthBloc> blocFor(
      _FakeSocial social, {
      Map<String, dynamic>? answer,
    }) async {
      await _wire(answer ?? _loggedIn());
      return AuthBloc(repo: AuthRepo(), social: social);
    }

    test('backing out of the sheet is not a failure', () async {
      // A cancellation that emitted AuthFailure put an error banner over
      // the form for closing a sheet, which reads as the app being broken.
      final bloc = await blocFor(
        _FakeSocial(failure: SocialSignInFailure.cancelled),
      );

      final states = <AuthState>[];
      bloc.stream.listen(states.add);
      bloc.add(AuthSocialSignInRequested(SocialProvider.google));
      await Future<void>.delayed(Duration.zero);

      expect(states.first, isA<AuthSocialLoading>());
      expect(states.last, isA<AuthCancelled>());
      expect(states.whereType<AuthFailure>(), isEmpty);
    });

    test('an unsupported platform says so in its own words', () async {
      final bloc = await blocFor(
        _FakeSocial(failure: SocialSignInFailure.unsupported),
      );

      final states = <AuthState>[];
      bloc.stream.listen(states.add);
      bloc.add(AuthSocialSignInRequested(SocialProvider.apple));
      await Future<void>.delayed(Duration.zero);

      expect(
        (states.last as AuthFailure).message,
        AppStrings.socialUnsupported,
      );
    });

    test('only the provider that was tapped is busy', () async {
      final bloc = await blocFor(_FakeSocial(credential: _apple));

      final states = <AuthState>[];
      bloc.stream.listen(states.add);
      bloc.add(AuthSocialSignInRequested(SocialProvider.apple));
      await Future<void>.delayed(Duration.zero);

      expect(
        (states.first as AuthSocialLoading).provider,
        SocialProvider.apple,
      );
    });

    test('a second tap while a sheet is open is dropped', () async {
      // Events run concurrently by default, and both buttons only go inert
      // on the frame after the first emit — so two fingers landing together
      // reached the handler twice and raced two provider sheets.
      final gate = Completer<void>();
      final social = _FakeSocial(
        credential: _google,
        offered: SocialProvider.values.toSet(),
        gate: gate,
      );
      final bloc = await blocFor(social);

      final states = <AuthState>[];
      bloc.stream.listen(states.add);
      bloc.add(AuthSocialSignInRequested(SocialProvider.google));
      await Future<void>.delayed(Duration.zero);
      bloc.add(AuthSocialSignInRequested(SocialProvider.apple));
      await Future<void>.delayed(Duration.zero);

      expect(states.whereType<AuthSocialLoading>(), hasLength(1));
      expect(social.asked, SocialProvider.google);
      gate.complete();
    });

    test('and nothing is dropped once the first one has answered', () async {
      final bloc = await blocFor(
        _FakeSocial(failure: SocialSignInFailure.cancelled),
      );

      final states = <AuthState>[];
      bloc.stream.listen(states.add);
      bloc.add(AuthSocialSignInRequested(SocialProvider.google));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(AuthSocialSignInRequested(SocialProvider.google));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(states.whereType<AuthSocialLoading>(), hasLength(2));
    });

    test('a new account is reported as new, so onboarding follows', () async {
      final bloc = await blocFor(
        _FakeSocial(credential: _google),
        answer: _loggedIn(isNewUser: true),
      );

      final states = <AuthState>[];
      bloc.stream.listen(states.add);
      bloc.add(AuthSocialSignInRequested(SocialProvider.google));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final success = states.whereType<AuthSuccess>().single;
      expect(success.isNewUser, isTrue);
    });

    test('a challenge reaches the screen with its address', () async {
      final bloc = await blocFor(
        _FakeSocial(credential: _apple),
        answer: _challenge(email: 'ada@privaterelay.appleid.com'),
      );

      final states = <AuthState>[];
      bloc.stream.listen(states.add);
      bloc.add(AuthSocialSignInRequested(SocialProvider.apple));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final challenge = states.whereType<AuthTwoFactorRequired>().single;
      expect(challenge.challengeId, 'ch1');
      expect(challenge.email, 'ada@privaterelay.appleid.com');
    });
  });

  group('the buttons themselves', () {
    Future<void> pump(
      WidgetTester tester,
      Widget screen,
      _FakeSocial social,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      GetIt.instance
        ..allowReassignment = true
        ..registerSingleton<ApiService>(_RecordingApi(_loggedIn()))
        ..registerSingleton<TokenStorageService>(_Tokens());
      addTearDown(GetIt.instance.reset);

      tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(repo: AuthRepo(), social: social),
          child: SizingBuilder(
            baseSize: const Size(390, 844),
            respectSystemFontScale: false,
            builder: (context) => MaterialApp.router(
              theme: AppTheme.dark,
              routerConfig: GoRouter(
                initialLocation: '/here',
                routes: [
                  GoRoute(path: '/here', builder: (_, _) => screen),
                  GoRoute(
                    path: AppRouter.signUp,
                    builder: (_, _) => const Text('SIGN UP'),
                  ),
                  GoRoute(
                    path: AppRouter.home,
                    builder: (_, _) => const Text('HOME'),
                  ),
                  GoRoute(
                    path: AppRouter.welcomeNote,
                    builder: (_, _) => const Text('WELCOME NOTE'),
                  ),
                  GoRoute(
                    path: AppRouter.verifyEmail,
                    builder: (_, _) => const Text('CODE'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      // Not `pumpAndSettle`: the welcome page's feature carousel animates
      // for as long as it is on screen, so nothing ever settles.
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('a provider this build cannot start is left out', (
      tester,
    ) async {
      // Not greyed out. A dead control beside a live one reads as the live
      // one being broken too, and on Android the Apple button could never
      // work whatever a creator did.
      await pump(
        tester,
        const WelcomeScreen(),
        _FakeSocial(offered: const {SocialProvider.google}),
      );

      expect(find.text(AppStrings.continueWithGoogle), findsOneWidget);
      expect(find.text(AppStrings.continueWithApple), findsNothing);
      expect(find.text(AppStrings.continueWithEmail), findsOneWidget);
    });

    testWidgets('and both are drawn where both work', (tester) async {
      await pump(
        tester,
        const WelcomeScreen(),
        _FakeSocial(offered: SocialProvider.values.toSet()),
      );

      expect(find.text(AppStrings.continueWithGoogle), findsOneWidget);
      expect(find.text(AppStrings.continueWithApple), findsOneWidget);
    });

    testWidgets('tapping one starts that provider', (tester) async {
      final social = _FakeSocial(
        credential: _apple,
        offered: SocialProvider.values.toSet(),
      );
      await pump(tester, const WelcomeScreen(), social);

      await tester.tap(find.byKey(const ValueKey('continue-with-apple')));
      await tester.pump();

      expect(social.asked, SocialProvider.apple);
    });

    testWidgets('and the one that was tapped is the one that spins', (
      tester,
    ) async {
      final gate = Completer<void>();
      final social = _FakeSocial(
        credential: _apple,
        offered: SocialProvider.values.toSet(),
        gate: gate,
      );
      addTearDown(() => gate.isCompleted ? null : gate.complete());
      await pump(tester, const WelcomeScreen(), social);

      await tester.tap(find.byKey(const ValueKey('continue-with-apple')));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('continue-with-apple')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('continue-with-google')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
    });

    testWidgets('the sign-in form draws Apple before Google, as drawn', (
      tester,
    ) async {
      // The design puts them in that order here and the other way round on
      // the welcome page's full-width buttons. Iterating the enum gave both
      // rows the enum's order and silently flipped this one.
      await pump(
        tester,
        const SignInScreen(),
        _FakeSocial(offered: SocialProvider.values.toSet()),
      );

      final apple = tester.getTopLeft(
        find.byKey(const ValueKey('sign-in-with-apple')),
      );
      final google = tester.getTopLeft(
        find.byKey(const ValueKey('sign-in-with-google')),
      );
      expect(apple.dx, lessThan(google.dx));
    });

    testWidgets('while the welcome page draws Google first, as drawn', (
      tester,
    ) async {
      await pump(
        tester,
        const WelcomeScreen(),
        _FakeSocial(offered: SocialProvider.values.toSet()),
      );

      final google = tester.getTopLeft(
        find.byKey(const ValueKey('continue-with-google')),
      );
      final apple = tester.getTopLeft(
        find.byKey(const ValueKey('continue-with-apple')),
      );
      expect(google.dy, lessThan(apple.dy));
    });

    testWidgets('the sign-in form drops the divider with the last provider', (
      tester,
    ) async {
      // An "Or" over an empty row claims there was another way in.
      await pump(tester, const SignInScreen(), _FakeSocial());

      expect(find.text(AppStrings.orDivider), findsNothing);
    });

    testWidgets('and keeps it while one is offered', (tester) async {
      await pump(
        tester,
        const SignInScreen(),
        _FakeSocial(offered: const {SocialProvider.google}),
      );

      expect(find.text(AppStrings.orDivider), findsOneWidget);
      expect(find.byKey(const ValueKey('sign-in-with-google')), findsOneWidget);
      expect(find.byKey(const ValueKey('sign-in-with-apple')), findsNothing);
    });
  });

  group('where an answer lands, with screens stacked', () {
    // The welcome page *pushes* the sign-in form, so both are mounted and
    // both listen to the one app-wide AuthBloc.
    Future<(GoRouter, AuthBloc)> pumpStack(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      GetIt.instance
        ..allowReassignment = true
        ..registerSingleton<ApiService>(_RecordingApi(_challenge()))
        ..registerSingleton<TokenStorageService>(_Tokens());
      addTearDown(GetIt.instance.reset);

      tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final bloc = AuthBloc(
        repo: AuthRepo(),
        social: _FakeSocial(offered: SocialProvider.values.toSet()),
      );
      addTearDown(bloc.close);

      final router = GoRouter(
        initialLocation: AppRouter.welcome,
        routes: [
          GoRoute(
            path: AppRouter.welcome,
            builder: (_, _) => const WelcomeScreen(),
          ),
          GoRoute(
            path: AppRouter.signIn,
            builder: (_, _) => const SignInScreen(),
          ),
          GoRoute(
            path: AppRouter.signUp,
            builder: (_, _) => const Text('SIGN UP'),
          ),
          GoRoute(path: AppRouter.home, builder: (_, _) => const Text('HOME')),
          GoRoute(
            path: AppRouter.welcomeNote,
            builder: (_, _) => const Text('WELCOME NOTE'),
          ),
          GoRoute(
            path: AppRouter.forgotPassword,
            builder: (_, _) => const Text('FORGOT'),
          ),
          GoRoute(
            path: AppRouter.verifyEmail,
            builder: (_, _) => const Text('CODE'),
          ),
        ],
      );

      await tester.pumpWidget(
        BlocProvider<AuthBloc>.value(
          value: bloc,
          child: SizingBuilder(
            baseSize: const Size(390, 844),
            respectSystemFontScale: false,
            builder: (context) =>
                MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
          ),
        ),
      );
      // Never `pumpAndSettle`: the welcome page's carousel animates for as
      // long as it is on screen.
      await tester.pump(const Duration(milliseconds: 400));
      return (router, bloc);
    }

    List<String> stack(GoRouter router) => router
        .routerDelegate
        .currentConfiguration
        .matches
        .map((m) => m.matchedLocation)
        .toList();

    testWidgets('a challenge opens one code screen, not one per screen', (
      tester,
    ) async {
      // Every screen that can start a sign-in listens to the same bloc, and
      // a buried one is still listening. Two listeners both acting on one
      // `2FA_REQUIRED` pushed the code screen twice, so backing out of it
      // landed on an identical copy of itself.
      final (router, bloc) = await pumpStack(tester);

      router.push(AppRouter.signIn);
      // One frame to start the transition and one to carry it past the end:
      // a single pump with a delta leaves the new route offstage, where
      // `find` cannot see it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SignInScreen), findsOneWidget);

      bloc.add(AuthSignInRequested(email: 'ada@example.com', password: 'x'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('CODE'), findsOneWidget);
      expect(
        stack(router).where((p) => p == AppRouter.verifyEmail).length,
        1,
        reason: 'the buried welcome page pushed a second one',
      );
    });

    testWidgets('and a buried screen reports nothing of its own either', (
      tester,
    ) async {
      // The welcome page says a refusal in a snackbar. Said from under the
      // sign-in form — which has a banner of its own for it — it would be
      // the same refusal told twice, in two places.
      final (router, bloc) = await pumpStack(tester);
      (GetIt.instance<ApiService>() as _RecordingApi).status = 401;

      router.push(AppRouter.signIn);
      // One frame to start the transition and one to carry it past the end:
      // a single pump with a delta leaves the new route offstage, where
      // `find` cannot see it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      bloc.add(AuthSignInRequested(email: 'ada@example.com', password: 'x'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('while the page in front still does', (tester) async {
      final (_, bloc) = await pumpStack(tester);
      (GetIt.instance<ApiService>() as _RecordingApi).status = 401;

      bloc.add(AuthSocialSignInRequested(SocialProvider.google));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('resending the code', () {
    test('answers the window the server gave', () async {
      final api = await _wire({
        'success': true,
        'data': {'expiresInMinutes': 7},
      });

      expect(await AuthRepo().resendChallengeOtp(challengeId: 'c1'), 7);
      expect(api.paths.single, contains('/resend'));
    });

    test('and a window it cannot read is not worth throwing over', () async {
      // The new code is already in the mailbox by then, and nothing
      // displays this number. Throwing would clear no field and restart no
      // countdown, leaving Resend a button that does nothing at all.
      await _wire({
        'success': true,
        'data': {'expiresInMinutes': 'ten minutes'},
      });

      expect(await AuthRepo().resendChallengeOtp(challengeId: 'c1'), 10);
    });
  });

  group('the build settings a provider sign-in needs', () {
    // None of this can be caught by running the code: a missing URL scheme
    // or an unapplied entitlement fails on a device, in the provider's own
    // UI, with nothing in the Dart to look at.
    late final String plist = File('ios/Runner/Info.plist').readAsStringSync();
    late final String entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    late final String social = File(
      'ios/Flutter/Social.xcconfig',
    ).readAsStringSync();

    test('Google redirects back through a registered URL scheme', () {
      expect(plist, contains('<key>CFBundleURLTypes</key>'));
      expect(plist, contains(r'$(GOOGLE_IOS_REVERSED_CLIENT_ID)'));
    });

    test('and the variable it reads is defined', () {
      expect(social, contains('GOOGLE_IOS_REVERSED_CLIENT_ID = '));
      // An empty value would leave an empty string in CFBundleURLSchemes,
      // which App Store validation rejects.
      final value = RegExp(
        r'^GOOGLE_IOS_REVERSED_CLIENT_ID\s*=\s*(\S+)\s*$',
        multiLine: true,
      ).firstMatch(social);
      expect(value, isNotNull);
      expect(value!.group(1), isNotEmpty);
    });

    test('in both configurations, which is all three the app builds', () {
      for (final name in ['Debug', 'Release']) {
        final config = File('ios/Flutter/$name.xcconfig').readAsStringSync();
        expect(
          config,
          contains('#include "Social.xcconfig"'),
          reason: '$name.xcconfig does not include it',
        );
      }
    });

    test('Sign in with Apple is entitled', () {
      expect(
        entitlements,
        contains('<key>com.apple.developer.applesignin</key>'),
      );
    });

    test('and the entitlements file actually reaches the build', () {
      // It was in the repo and referenced nowhere — not in the project
      // file, not in any xcconfig — so neither this nor the applinks:
      // domains beside it had ever been applied.
      for (final name in ['Debug', 'Release']) {
        final config = File('ios/Flutter/$name.xcconfig').readAsStringSync();
        expect(
          config,
          contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements'),
          reason: '$name.xcconfig does not point at the entitlements file',
        );
      }
    });

    test('and a configured iOS client id matches the registered scheme', () {
      // iOS takes two edits — the client id in .env for the SDK, and its
      // reversed form in Social.xcconfig for the redirect — so they can
      // drift, and the symptom is a button that opens Google and comes
      // back to nothing. .env is gitignored, so this checks it only where
      // one exists and names a client.
      final env = File('.env');
      if (!env.existsSync()) return;
      final id = RegExp(
        r'^GOOGLE_IOS_CLIENT_ID\s*=\s*(\S+)\s*$',
        multiLine: true,
      ).firstMatch(env.readAsStringSync())?.group(1);
      if (id == null || id.isEmpty) return;

      final reversed =
          'com.googleusercontent.apps.'
          '${id.replaceAll('.apps.googleusercontent.com', '')}';
      expect(
        social,
        contains(reversed),
        reason:
            'GOOGLE_IOS_CLIENT_ID is set in .env but '
            'ios/Flutter/Social.xcconfig does not carry its reversed form',
      );
    });

    test('the client ids are documented where a new clone will look', () {
      final example = File('.env.example').readAsStringSync();
      expect(example, contains('GOOGLE_SERVER_CLIENT_ID='));
      expect(example, contains('GOOGLE_IOS_CLIENT_ID='));
    });

    test('and neither provider needs a runtime permission', () {
      // Which is the point of the native SDKs: Google goes through
      // CredentialManager / GIDSignIn and Apple through
      // ASAuthorizationController, and neither reads anything the system
      // guards. A `Permission.` here would have to be declared, compiled
      // in on iOS and explained to a person — see
      // ios_permission_config_test and android_permission_config_test.
      final source = File(
        'lib/shared/services/social_sign_in.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('permission_handler')));
      expect(source, isNot(contains('Permission.')));
    });

    test('and the Android build needs nothing declared for them either', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      // INTERNET is all of it, and it was already there. Anything else
      // would be a permission the app asks for and cannot explain.
      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, isNot(contains('GET_ACCOUNTS')));
      expect(manifest, isNot(contains('USE_CREDENTIALS')));
    });
  });
}
