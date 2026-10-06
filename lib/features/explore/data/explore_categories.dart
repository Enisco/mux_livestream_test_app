import 'package:hugeicons/hugeicons.dart';

import 'package:test_app/models/explore_models/explore_models.dart';

/// The browse chips at the foot of Explore.
///
/// **These are the ten slugs the platform actually ships**
/// (`PLATFORM_CONTENT_CATEGORIES`, served by `GET /v1/user/categories`), not a
/// list of plausible-sounding topics. An earlier version of this screen
/// offered `preaching`, `fellowship`, `missions` and `discipleship`, none of
/// which exist — a filter built on one would have matched nothing and a
/// creator could never have tagged content into it.
///
/// Only the icons are local: the API serves a slug, a name and a sort order,
/// and says nothing about artwork. The labels here follow the API's `name`
/// so the chip and the filter agree.
abstract final class ExploreCategories {
  static const all = <ExploreCategory>[
    ExploreCategory(
      slug: 'worship',
      label: 'Worship',
      icon: HugeIcons.strokeRoundedMusicNote01,
    ),
    ExploreCategory(
      slug: 'sermons',
      label: 'Sermons',
      icon: HugeIcons.strokeRoundedBookOpen01,
    ),
    ExploreCategory(
      slug: 'bible-study',
      label: 'Bible study',
      icon: HugeIcons.strokeRoundedBook02,
    ),
    ExploreCategory(
      slug: 'prayer',
      label: 'Prayer',
      icon: HugeIcons.strokeRoundedHandPrayer,
    ),
    ExploreCategory(
      slug: 'gospel-music',
      label: 'Gospel music',
      icon: HugeIcons.strokeRoundedMusicNote01,
    ),
    ExploreCategory(
      slug: 'live-services',
      label: 'Live services',
      icon: HugeIcons.strokeRoundedGlobe,
    ),
    ExploreCategory(
      slug: 'testimonies',
      label: 'Testimonies',
      icon: HugeIcons.strokeRoundedQuoteDown,
    ),
    ExploreCategory(
      slug: 'youth',
      label: 'Youth',
      icon: HugeIcons.strokeRoundedUserGroup,
    ),
    ExploreCategory(
      slug: 'family',
      label: 'Family',
      icon: HugeIcons.strokeRoundedUserMultiple,
    ),
    ExploreCategory(
      slug: 'devotionals',
      label: 'Devotionals',
      icon: HugeIcons.strokeRoundedBook02,
    ),
  ];
}
