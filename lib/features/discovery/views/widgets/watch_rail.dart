import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:test_app/shared/components/design_icon.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';

/// The column of controls down the right of a video that has the whole
/// screen — the swipe feed and the upright watching view.
///
/// One component for both, because they are the same control in the reader's
/// mind: whichever upright video they are on, the heart is in the same place.
/// Two private copies is how that stops being true.
abstract final class WatchRail {
  /// Between one control and the next.
  static const gap = 20.0;

  /// Between the avatar and the first control, which is wider because the
  /// follow badge hangs off the avatar's bottom edge.
  static const gapAfterAvatar = 24.0;
}

/// The ministry's avatar, with the follow badge on its corner.
///
/// The avatar opens the ministry and the badge follows it — two targets in
/// one, which is why the badge is a [GestureDetector] of its own rather than
/// part of the avatar's.
class WatchRailAvatar extends StatelessWidget {
  const WatchRailAvatar({
    super.key,
    required this.displayName,
    required this.onTap,
    required this.onFollow,
    this.avatarUrl,
    this.following = false,
  });

  final String displayName;

  /// Opens the ministry. See [[creator-profile-entry-points]]: every avatar
  /// in the app goes to the same place.
  final VoidCallback onTap;

  /// Follows, or unfollows, the ministry.
  final VoidCallback onFollow;

  final String? avatarUrl;

  /// Whether the viewer already follows this ministry.
  final bool following;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return SizedBox(
      width: 52,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                color: AppColors.neutral800,
              ),
              child: ClipOval(
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? Center(child: _Initial(initial))
                    : Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        width: 48,
                        height: 48,
                        // A ministry with no picture, or one that will not
                        // load, still has a name to stand in for it.
                        errorBuilder: (_, _, _) =>
                            Center(child: _Initial(initial)),
                      ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: onFollow,
              child: Center(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    // Following turns the badge grey with a tick.
                    color: following
                        ? AppColors.neutral700
                        : AppColors.brandPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    following ? Icons.check_rounded : Icons.add_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial(this.letter);

  final String letter;

  @override
  Widget build(BuildContext context) => Text(
    letter,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 20,
    ),
  );
}

/// One control on the rail: an icon with its count or its name under it.
class WatchRailAction extends StatelessWidget {
  const WatchRailAction({
    super.key,
    this.icon,
    this.asset,
    this.label = '',
    this.color = Colors.white,
    this.onTap,
  }) : assert(icon != null || asset != null, 'give the row something to draw');

  final IconData? icon;

  /// An SVG from the design set, drawn instead of [icon]. The rail is a
  /// font-icon rail, but a few of these actions also appear on the feed
  /// cards and have to be the same glyph there and here.
  final String? asset;

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {},
      // The gaps between the controls are dead space otherwise, and on a
      // moving video a missed tap reads as the app ignoring you.
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: label.isEmpty ? null : label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The shadows are what keep a white icon legible over a video
            // that might be white at that moment too.
            if (asset case final svg?)
              _ShadowedGlyph(asset: svg, color: color)
            else
              Icon(
                icon,
                color: color,
                size: 30,
                shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
              ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An SVG with the same legibility treatment [Icon] gets from `shadows`.
///
/// There is no shadow parameter on `SvgPicture`, so the glyph is drawn
/// twice: a blurred black copy underneath, then the real one over it.
class _ShadowedGlyph extends StatelessWidget {
  const _ShadowedGlyph({required this.asset, required this.color});

  final String asset;
  final Color color;

  static const _size = 26.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: DesignIcon(
                asset,
                width: _size,
                height: _size,
                color: Colors.black87,
              ),
            ),
            DesignIcon(asset, width: _size, height: _size, color: color),
          ],
        ),
      ),
    );
  }
}
