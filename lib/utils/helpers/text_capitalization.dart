import 'package:flutter/services.dart';

/// What the shift key should do in a field whose screen has not said.
///
/// Anywhere a reader types prose — a comment, a bio, a title, a venue, the
/// description of a fund — the keyboard should come up shifted, the way
/// every other keyboard on the phone does. Machine text is the exception:
/// an email address, a URL, a password, a phone number or an amount is
/// wrong the moment a letter is shifted for it, so those stay
/// [TextCapitalization.none].
///
/// This reads the decision off the keyboard the field already asked for
/// rather than a second flag, because the keyboard is the thing that is
/// always set and always right: a field that wants digits says so. The
/// list is deliberately a list of what *does* capitalise — a keyboard type
/// nobody has thought about yet is likelier to be a specialised one than
/// prose, and a field that wants shift can always ask.
///
/// A field that knows better passes its own value and this never runs: a
/// person's name takes [TextCapitalization.words].
TextCapitalization sentenceCaseUnlessMachineText(
  TextInputType? keyboardType, {
  bool obscured = false,
}) {
  if (obscured) return TextCapitalization.none;
  return switch (keyboardType) {
    null ||
    TextInputType.text ||
    TextInputType.multiline ||
    TextInputType.name ||
    TextInputType.streetAddress => TextCapitalization.sentences,
    _ => TextCapitalization.none,
  };
}
