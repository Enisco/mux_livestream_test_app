import 'package:flutter/widgets.dart';

/// How a video is laid into the surface that shows it.
abstract final class VideoFit {
  /// The shape of the frame a video is watched in: the media detail
  /// hero, and the creator's own preview of what they are broadcasting.
  static const landscapeAspect = 16 / 9;

  /// A frame with a landscape shape of its own, sitting in a page: the
  /// media detail hero ([landscapeAspect]) and the home feed card
  /// (338:195).
  static const landscapeFrame = BoxFit.cover;

  /// A surface that *is* the screen: [PlayerScreen], the hero's fullscreen
  /// route, the swipe feed.
  static const fullBleed = BoxFit.contain;
}
