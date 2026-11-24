import 'package:flutter/widgets.dart';

/// Takes the keyboard down before something else takes the screen.
///
/// Three things make this necessary rather than merely tidy:
///
///  * A **native sheet** — Google's account chooser, Apple's dialog, the
///    photo picker — is presented by the platform *over* Flutter's view.
///    It does not own the keyboard, so the field's keyboard is left
///    standing behind it, and still standing when it closes.
///  * **Navigating away** disposes the focused field's `FocusNode`.
///    Disposing a node that still holds focus does not reliably reach the
///    engine with a hide, so the keyboard outlives the screen that asked
///    for it. That is how signing in with Google left one standing over
///    the feed, with a "Done" bar and nothing to type into.
///  * `FocusScope.of(context).unfocus()` only reaches the scope that
///    context sits in. [FocusManager.instance] names whatever actually
///    holds focus, wherever it lives — which is the thing that has to let
///    go — and needs no `BuildContext`, so it can be called from the
///    service that is about to open the sheet rather than from each of the
///    buttons that reach it.
void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();
