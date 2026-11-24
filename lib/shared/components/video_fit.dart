import 'package:flutter/widgets.dart';

/// Which way a video is shaped, and so which surface it belongs on.
enum VideoShape {
  /// Not known yet. The decoder reports the picture's size a beat after
  /// playback starts, so every surface has to be able to draw without it.
  unknown,

  /// Taller than it is wide by enough to be worth the whole screen: what a
  /// phone camera shoots held upright, and what a reel is cut to.
  portrait,

  /// Square or wider. A frame in a page, with the rest of the page under it.
  standard,
}

/// How a video is laid into the surface that shows it.
abstract final class VideoFit {
  /// The shape a video is assumed to be until its own is known, and the
  /// widest frame one is given in a page.
  static const landscapeAspect = 16 / 9;

  /// Narrower than this — width over height — and a video is watched upright
  /// on the whole screen rather than in a frame.
  ///
  /// Just under square on purpose. The shapes that read as *about* square,
  /// 1:1 and 5:4, keep the page they were designed for, where a title, a
  /// description and the comments all sit under the picture. Below it the
  /// picture stops being something a page can hold: 4:5 fills under half the
  /// width of a 16:9 frame, and the 9:16 a phone shoots fills under a third.
  static const portraitBelow = 0.95;

  /// Which surface a picture of this size belongs on.
  static VideoShape shapeOf({required int width, required int height}) {
    if (width <= 0 || height <= 0) return VideoShape.unknown;
    return width / height < portraitBelow
        ? VideoShape.portrait
        : VideoShape.standard;
  }

  /// The shape of the frame a [VideoShape.standard] video sits in.
  ///
  /// The video's own, so there is nothing to crop and no bars to pad it
  /// with — but never narrower than square, which is the point the page
  /// layout stops working, and never wider than [landscapeAspect], so a
  /// cinema-cut 2.35:1 is letterboxed inside a familiar frame instead of
  /// squeezing the page into a letterbox of its own.
  static double frameAspect({required int width, required int height}) {
    if (width <= 0 || height <= 0) return landscapeAspect;
    return (width / height).clamp(1.0, landscapeAspect);
  }

  /// A frame with a shape of its own, sitting in a page: the media detail
  /// hero, and the creator's own preview of what they are broadcasting.
  ///
  /// `contain`, because [frameAspect] gives the frame the video's own shape
  /// wherever it can. Cropping to fill was what turned an upright clip into
  /// a strip across the middle of a 16:9 box; where the two still differ —
  /// a 2.35:1 cut, a picture whose size is not known yet — bars are honest
  /// and a crop is not.
  static const inPageFrame = BoxFit.contain;

  /// The home feed card, which keeps one card height whatever it is given.
  ///
  /// This one does crop, and should: the cards are a grid the eye reads down,
  /// and a card that grew to fit an upright video would break the rhythm for
  /// every card under it. The detail is where the video gets its own shape.
  static const landscapeFrame = BoxFit.cover;

  /// A surface that *is* the screen: [PlayerScreen], the hero's fullscreen
  /// route, the swipe feed, the upright watching view.
  static const fullBleed = BoxFit.contain;
}
