import 'package:flutter/widgets.dart';

/// How a video is laid into the surface that shows it.
///
/// The phone films upright. Both native livestream SDKs take the encoder's
/// frame size from the *interface* orientation and expose no knob for it
/// — iOS reads `UIApplication.shared.statusBarOrientation` when the
/// controller is built, Android takes the display's rotation — so a
/// replay of a phone livestream is a 9:16 asset. Measured on staging
/// 2026-11-13: `720x1280`, rotation 0, upright picture.
///
/// The decision taken with the product owner that day: **leave what the
/// phone captures alone**, and have the frames that are shaped landscape
/// present an upright video the way the creator's own live screen
/// presents the upright camera — filled, not pillarboxed.
///
/// Which fit applies turns on what the surface *is*, not on the video:
abstract final class VideoFit {
  /// The shape of the frame a video is watched in: the media detail
  /// hero, and the creator's own preview of what they are broadcasting.
  ///
  /// Shared so the two cannot drift. A creator looking at themselves is
  /// looking at the frame the congregation will watch them in, which is
  /// only true while both say 16:9.
  static const landscapeAspect = 16 / 9;

  /// A frame with a landscape shape of its own, sitting in a page: the
  /// media detail hero ([landscapeAspect]) and the home feed card
  /// (338:195).
  ///
  /// Fills it and centre-crops what will not fit, so the page reads the
  /// same whatever shape the asset is. A landscape source is untouched —
  /// cover and contain agree when the aspects already match — so it is
  /// only an upright replay that changes, and that one stops sitting in a
  /// 123 px strip inside a 390 px frame.
  ///
  /// Never used for a surface that is the whole screen. See [fullBleed].
  static const landscapeFrame = BoxFit.cover;

  /// A surface that *is* the screen: [PlayerScreen], the hero's fullscreen
  /// route, the swipe feed.
  ///
  /// Keeps the whole picture. A phone screen is not 16:9 — 390x844 upright
  /// is 9:19.5, and rotated it is 2.16:1 — so filling one would crop an
  /// ordinary 16:9 sermon to about a quarter of its width upright, or
  /// shave a fifth off its height in fullscreen. Someone who opened the
  /// player or tapped fullscreen is asking to see *more* of the video, so
  /// this is the one place black bars are the right answer.
  static const fullBleed = BoxFit.contain;
}
