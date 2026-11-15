import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:test_app/features/onboarding/views/widgets/interest_chip.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';

/// A glyph for each slug in the API's taxonomy.
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
