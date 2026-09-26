import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:test_app/features/onboarding/views/widgets/interest_chip.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';

/// A glyph for each slug in the API's taxonomy.
///
/// The interest chips used to be the design's own eleven labels, four of which
/// had no category behind them — so picking only those sent nothing at all and
/// four real categories (`prayer`, `live-services`, `testimonies`,
/// `devotionals`) could not be chosen. The chips are drawn from
/// `GET /v1/user/categories` now, which means the label and slug can never
/// drift apart again, and this is the one thing the API does not supply.
///
/// A slug with no entry here still gets a chip: the taxonomy is the backend's
/// to grow, and a new category should appear rather than vanish because the
/// app has no picture for it.
abstract final class CategoryGlyphs {
  static const _bySlug = <String, String>{
    'worship': AppAssets.iconCatDove,
    'sermons': AppAssets.iconCatMicrophone,
    'bible-study': AppAssets.iconCatBible,
    'prayer': AppAssets.iconCatHeartHand,
    'gospel-music': AppAssets.iconCatMusicNote,
    'live-services': AppAssets.iconVideoCamera,
    'testimonies': AppAssets.iconFeedChat,
    'youth': AppAssets.iconFeedUsers,
    'devotionals': AppAssets.iconBookOpen,
  };

  /// `family` is the one drawn rather than filed: it is the three-figure mark
  /// the design uses, not a single SVG.
  static const _familySlug = 'family';

  /// Shown for a category this build has no glyph for.
  static const fallback = AppAssets.iconCatGlobe;

  static Widget? forSlug(String slug) {
    if (slug == _familySlug) return const FamilyGlyph();
    return _svg(_bySlug[slug] ?? fallback);
  }

  /// Whether the taxonomy has outgrown this map, which a test asserts against
  /// the live category list so a new slug is noticed rather than shipped as a
  /// globe.
  static bool hasGlyph(String slug) =>
      slug == _familySlug || _bySlug.containsKey(slug);

  static Widget _svg(String asset) => SvgPicture.asset(
    asset,
    width: InterestChip.iconSize,
    height: InterestChip.iconSize,
  );
}
