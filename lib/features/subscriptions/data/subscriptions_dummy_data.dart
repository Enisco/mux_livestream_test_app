import 'package:test_app/models/subscription_models/subscription_models.dart';

/// Placeholder ministries for the Manage following screen.
///
/// TEMPORARY. `POST /v1/engagement/follow` and its delete counterpart exist,
/// and `GET /v1/discovery/creators` lists creators generally, but nothing
/// returns *this reader's* following list, when each one last posted, whether
/// it is live, or the per-ministry notification level the sheet sets. The
/// screen is UI ahead of those routes.
///
/// To retire this: delete the file and fix the import errors in
/// `manage_following_screen.dart`.
abstract final class SubscriptionsDummyData {
  static const following = <FollowedMinistry>[
    FollowedMinistry(
      id: 'm1',
      name: 'Cynthia Morgan',
      handle: '@cynthiamorgan',
      lastActivity: 'Live now',
      verified: true,
      isLive: true,
      notify: NotifyLevel.all,
    ),
    FollowedMinistry(
      id: 'm2',
      name: 'Living Faith',
      handle: '@livingfaith',
      lastActivity: 'Live now',
      verified: true,
      isLive: true,
    ),
    FollowedMinistry(
      id: 'm3',
      name: 'New Life Fellowship',
      handle: '@newlife',
      lastActivity: 'Posted 1 hour ago',
      verified: true,
    ),
    FollowedMinistry(
      id: 'm4',
      name: 'Petra CC',
      handle: '@petracc',
      lastActivity: 'Posted 2 hours ago',
      verified: true,
      notify: NotifyLevel.live,
    ),
    FollowedMinistry(
      id: 'm5',
      name: 'Abundant Ministries Life Assembly',
      handle: '@abundantlife',
      lastActivity: 'Posted 2 hours ago',
      verified: true,
    ),
    FollowedMinistry(
      id: 'm6',
      name: 'The River Church',
      handle: '@theriver',
      lastActivity: 'Posted 3 hours ago',
      verified: true,
      notify: NotifyLevel.none,
    ),
  ];

  /// Offered on the empty feed, under "Ministries to get you started".
  static const suggested = <SuggestedMinistry>[
    SuggestedMinistry(
      id: 's1',
      name: 'Pastor Luke Cage',
      handle: '@lukecage',
      verified: true,
    ),
    SuggestedMinistry(
      id: 's2',
      name: 'CCI International',
      handle: '@cciinternational',
      verified: true,
    ),
    SuggestedMinistry(
      id: 's3',
      name: 'Pastor Luke Cage',
      handle: '@lukecage',
      verified: true,
    ),
  ];
}
