import 'package:hugeicons/hugeicons.dart';

import 'package:test_app/models/explore_models/explore_models.dart';

/// Placeholder content for the Explore tab.
///
/// TEMPORARY. The Explore rails have no API yet, so the screen reads this
/// instead. Everything Explore invents rather than renders lives here, and the
/// artwork it points at lives in `assets/images/explore_dummy/`.
///
/// To retire it once the endpoints land: delete this file and the asset folder,
/// then fix the resulting import errors in `explore_screen.dart` — they mark
/// every place a real request belongs. Nothing else references it.
abstract final class ExploreDummyData {
  static const _art = 'assets/images/explore_dummy';

  // ---------------------------------------------------------------- creators

  static const _grace = ExploreCreatorRef(
    id: 'c-grace',
    name: 'Grace Community',
    handle: 'gracecommunity',
    avatarAsset: '$_art/avatar_a.png',
    verified: true,
    isOrganisation: true,
  );

  static const _horizon = ExploreCreatorRef(
    id: 'c-horizon',
    name: 'Horizon Fellowship',
    handle: 'horizonfellowship',
    avatarAsset: '$_art/avatar_b.png',
    verified: true,
    isOrganisation: true,
  );

  static const _nextgen = ExploreCreatorRef(
    id: 'c-nextgen',
    name: 'NextGen Innovators',
    handle: 'nextgen',
    avatarAsset: '$_art/avatar_c.png',
    verified: true,
  );

  static const _cityscape = ExploreCreatorRef(
    id: 'c-cityscape',
    name: 'CityScape Chronicles',
    handle: 'cityscape',
    avatarAsset: '$_art/avatar_d.png',
    verified: true,
  );

  static const _cci = ExploreCreatorRef(
    id: 'c-cci',
    name: 'CCI International',
    handle: 'cciinternational',
    avatarAsset: '$_art/avatar_d.png',
    verified: true,
    isOrganisation: true,
  );

  // -------------------------------------------------------------------- hero

  static const hero = ExploreHero(
    id: 'hero-1',
    title: 'Walking by Faith',
    description:
        'A family of believers sharing the gospel one sermon at a time. '
        'Sunday services live at 10am',
    creator: _cci,
    backdropAsset: '$_art/hero_backdrop.png',
  );

  // ------------------------------------------------------------------- rails

  static const live = <ExploreCard>[
    ExploreCard(
      id: 'live-1',
      title: 'The Power of Persistent Prayer',
      creator: _grace,
      thumbnailAsset: '$_art/live_thumb.png',
    ),
    ExploreCard(
      id: 'live-2',
      title: 'Sunday Morning Worship',
      creator: _horizon,
      thumbnailAsset: '$_art/live_thumb.png',
    ),
    ExploreCard(
      id: 'live-3',
      title: 'Midweek Bible Hour',
      creator: _cci,
      thumbnailAsset: '$_art/live_thumb.png',
    ),
  ];

  static const continueWatching = <ExploreCard>[
    ExploreCard(
      id: 'cw-1',
      title: 'The Power of Persistent Prayer',
      creator: _grace,
      thumbnailAsset: '$_art/continue_thumb.png',
      progress: 0.65,
    ),
    ExploreCard(
      id: 'cw-2',
      title: 'Celestial Ascent',
      creator: _horizon,
      thumbnailAsset: '$_art/continue_thumb.png',
      progress: 0.28,
    ),
    ExploreCard(
      id: 'cw-3',
      title: 'Anchored in Hope',
      creator: _nextgen,
      thumbnailAsset: '$_art/continue_thumb.png',
      progress: 0.82,
    ),
  ];

  static const trending = <ExploreCard>[
    ExploreCard(
      id: 'tr-1',
      title: 'The Power of Persistent Prayer',
      creator: _grace,
      thumbnailAsset: '$_art/trending_thumb.png',
      badge: '32:15',
    ),
    ExploreCard(
      id: 'tr-2',
      title: 'When Mountains Move',
      creator: _horizon,
      thumbnailAsset: '$_art/trending_thumb.png',
      badge: '18:42',
      sponsored: true,
    ),
    ExploreCard(
      id: 'tr-3',
      title: 'Songs for the Journey',
      creator: _nextgen,
      thumbnailAsset: '$_art/trending_thumb.png',
      badge: '44:07',
    ),
    ExploreCard(
      id: 'tr-4',
      title: 'Grace Upon Grace',
      creator: _cityscape,
      thumbnailAsset: '$_art/trending_thumb.png',
      badge: '27:30',
    ),
    ExploreCard(
      id: 'tr-5',
      title: 'A Steadfast Heart',
      creator: _cci,
      thumbnailAsset: '$_art/trending_thumb.png',
      badge: '12:55',
    ),
  ];

  static const devotionals = <ExploreCard>[
    ExploreCard(
      id: 'dv-1',
      title: 'Embracing Change Daily',
      creator: _horizon,
      thumbnailAsset: '$_art/poster_thumb.png',
      badge: '40 days',
    ),
    ExploreCard(
      id: 'dv-2',
      title: 'Building Resilience Daily',
      creator: _nextgen,
      thumbnailAsset: '$_art/poster_thumb.png',
      badge: '12 weeks',
    ),
    ExploreCard(
      id: 'dv-3',
      title: 'Mastering Stillness',
      creator: _grace,
      thumbnailAsset: '$_art/poster_thumb.png',
      badge: '21 days',
    ),
    ExploreCard(
      id: 'dv-4',
      title: 'Rooted and Ready',
      creator: _cityscape,
      thumbnailAsset: '$_art/poster_thumb.png',
      badge: '7 days',
    ),
  ];

  static const articles = <ExploreCard>[
    ExploreCard(
      id: 'ar-1',
      title: 'Why we still gather: the case for Sunday',
      creator: _horizon,
      thumbnailAsset: '$_art/poster_thumb.png',
      badge: '2 min read',
    ),
    ExploreCard(
      id: 'ar-2',
      title: 'Exploring urban ground',
      creator: _cityscape,
      thumbnailAsset: '$_art/poster_thumb.png',
      badge: '5 min read',
      sponsored: true,
    ),
    ExploreCard(
      id: 'ar-3',
      title: 'Why we sing before we preach',
      creator: _grace,
      thumbnailAsset: '$_art/poster_thumb.png',
      badge: '4 min read',
    ),
    ExploreCard(
      id: 'ar-4',
      title: 'The quiet discipline of listening',
      creator: _nextgen,
      thumbnailAsset: '$_art/poster_thumb.png',
      badge: '6 min read',
    ),
  ];

  static const ministries = <ExploreCreatorRef>[
    ExploreCreatorRef(
      id: 'm-1',
      name: 'John Doe',
      handle: 'johndoe',
      avatarAsset: '$_art/creator_person.png',
      verified: true,
      subscribers: 12900,
    ),
    ExploreCreatorRef(
      id: 'm-2',
      name: 'Celebration Church',
      handle: 'celebration',
      avatarAsset: '$_art/creator_org.png',
      verified: true,
      subscribers: 48200,
      isOrganisation: true,
    ),
    ExploreCreatorRef(
      id: 'm-3',
      name: 'Grace Community',
      handle: 'gracecommunity',
      avatarAsset: '$_art/avatar_a.png',
      verified: true,
      subscribers: 7400,
      isOrganisation: true,
    ),
    ExploreCreatorRef(
      id: 'm-4',
      name: 'Mary Adeyemi',
      handle: 'maryadeyemi',
      avatarAsset: '$_art/avatar_c.png',
      subscribers: 2100,
    ),
    ExploreCreatorRef(
      id: 'm-5',
      name: 'Horizon Fellowship',
      handle: 'horizonfellowship',
      avatarAsset: '$_art/avatar_b.png',
      verified: true,
      subscribers: 31500,
      isOrganisation: true,
    ),
  ];

  static const events = <ExploreEvent>[
    ExploreEvent(
      id: 'ev-1',
      title: 'Youth Conference',
      day: '12',
      month: 'JUN',
      venue: 'River Worship',
      time: '9:00am',
      creator: _cci,
      sponsored: true,
    ),
    ExploreEvent(
      id: 'ev-2',
      title: 'Night of Worship',
      day: '19',
      month: 'JUN',
      venue: 'Grace Auditorium',
      time: '6:30pm',
      creator: _grace,
    ),
    ExploreEvent(
      id: 'ev-3',
      title: 'Leaders Retreat',
      day: '02',
      month: 'JUL',
      venue: 'Horizon Camp',
      time: '8:00am',
      creator: _horizon,
    ),
  ];

  /// The design draws several chips with a duplicated glyph — the same
  /// hands-pray drawing appears on Fellowship, Missions, Testimony and Family.
  /// Each is given the icon its label actually means instead.
  static const categories = <ExploreCategory>[
    ExploreCategory(
      slug: 'preaching',
      label: 'Preaching',
      icon: HugeIcons.strokeRoundedBookOpen01,
    ),
    ExploreCategory(
      slug: 'worship',
      label: 'Worship',
      icon: HugeIcons.strokeRoundedMusicNote01,
    ),
    ExploreCategory(
      slug: 'bible-study',
      label: 'Bible study',
      icon: HugeIcons.strokeRoundedBook02,
    ),
    ExploreCategory(
      slug: 'youth',
      label: 'Youth',
      icon: HugeIcons.strokeRoundedUserGroup,
    ),
    ExploreCategory(
      slug: 'prayer',
      label: 'Prayer',
      icon: HugeIcons.strokeRoundedHandPrayer,
    ),
    ExploreCategory(
      slug: 'fellowship',
      label: 'Fellowship',
      icon: HugeIcons.strokeRoundedUserMultiple,
    ),
    ExploreCategory(
      slug: 'missions',
      label: 'Missions',
      icon: HugeIcons.strokeRoundedGlobe,
    ),
    ExploreCategory(
      slug: 'devotional',
      label: 'Devotional',
      icon: HugeIcons.strokeRoundedBook02,
    ),
    ExploreCategory(
      slug: 'testimony',
      label: 'Testimony',
      icon: HugeIcons.strokeRoundedQuoteDown,
    ),
    ExploreCategory(
      slug: 'music',
      label: 'Music',
      icon: HugeIcons.strokeRoundedMusicNote01,
    ),
    ExploreCategory(
      slug: 'family',
      label: 'Family',
      icon: HugeIcons.strokeRoundedUserGroup,
    ),
    ExploreCategory(
      slug: 'discipleship',
      label: 'Discipleship',
      icon: HugeIcons.strokeRoundedBook02,
    ),
  ];
}
