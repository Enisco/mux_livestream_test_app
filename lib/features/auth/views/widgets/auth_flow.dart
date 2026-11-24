import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_app/utils/helpers/keyboard.dart';

/// Where a sign-in goes next, for every screen that can start one.
///
/// Three screens start one — the welcome page, the sign-in form and the
/// sign-up form — and they used to disagree about what to do with the
/// answer: one routed a success to the feed, one to onboarding, and none of
/// them handled a second-factor challenge at all. Routing lives here so
/// they cannot drift again.
abstract final class AuthFlow {
  /// Acts on [state]. Does nothing for a state it does not handle, so it is
  /// safe to call from a `BlocListener` that sees all of them.
  static void follow(BuildContext context, AuthState state) {
    // Every branch below leaves the screen the keyboard belongs to. A
    // `FocusNode` disposed while it still holds focus does not reliably
    // reach the engine with a hide, so the keyboard outlives the form.
    if (state is AuthSuccess || state is AuthTwoFactorRequired) {
      dismissKeyboard();
    }

    switch (state) {
      case AuthSuccess(:final user, :final isNewUser):
        // An account that has just been created has nothing to show in a
        // feed and no preferences to read it with, so it starts where the
        // email flow starts.
        if (isNewUser) {
          final name = Uri.encodeComponent(user.firstName);
          context.go('${AppRouter.welcomeNote}?name=$name');
        } else {
          context.go(AppRouter.home);
        }

      case AuthTwoFactorRequired(:final challengeId, :final email):
        // No session exists yet — this is a code in a mailbox, not a
        // signed-in person, which is why it is pushed over the form rather
        // than replacing it.
        context.push(
          Uri(
            path: AppRouter.verifyEmail,
            queryParameters: {
              'challengeId': challengeId,
              'email': ?email,
              if (state.isNewUser) 'newUser': '1',
            },
          ).toString(),
        );

      default:
        break;
    }
  }
}

/// Wraps a screen in the listener above.
class AuthFlowListener extends StatelessWidget {
  const AuthFlowListener({super.key, required this.child, this.onState});

  final Widget child;

  /// Called for every state this screen is in front for, after
  /// [AuthFlow.follow] has had it. A screen uses this for the part that is
  /// its own — a snackbar, clearing a field — rather than for navigation.
  final void Function(BuildContext context, AuthState state)? onState;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // **Only the screen the reader is looking at reacts.** There is one
        // AuthBloc for the whole app and the welcome page *pushes* both
        // forms, so two or three of these listeners are mounted at once and
        // every one of them hears every state. Without this, a single
        // `2FA_REQUIRED` pushed the code screen once per listener — so
        // backing out of it landed on an identical copy of itself — and the
        // welcome page's snackbar appeared from underneath a form that had
        // already said the same thing in its own banner.
        //
        // Defaults to acting when there is no route to ask, which is the
        // case in a widget test that pumps a screen on its own.
        if (ModalRoute.of(context)?.isCurrent ?? true) {
          AuthFlow.follow(context, state);
          onState?.call(context, state);
        }
      },
      child: child,
    );
  }
}
