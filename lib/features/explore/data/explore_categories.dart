import 'package:hugeicons/hugeicons.dart';

import 'package:test_app/models/explore_models/explore_models.dart';

/// The browse chips at the foot of Explore.
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
