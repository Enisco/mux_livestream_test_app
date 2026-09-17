abstract final class ApiEndpoints {
  static const _auth = '/v1/auth';
  static const _creator = '/v1/creator';
  static const _media = '/v1/media';
  static const _public = '/v1/public';

  static const register = '$_auth/register';
  static const login = '$_auth/login';
  static const refresh = '$_auth/sessions/refresh';
  static const logout = '$_auth/logout';

  static const forgotPassword = '$_auth/password/forgot';
  static const resetPassword = '$_auth/password/reset';

  static const verify2faChallenge = '$_auth/2fa/challenges/verify';
  static const resend2faOtp = '$_auth/2fa/challenges/resend-otp';

  static const onboardCreator = '$_creator/onboard';
  static const creatorProfile = '$_creator/profile';

  static String creatorById(String id) => '$_creator/$id';

  /// `kind` is `avatar` or `banner`. The onboarding-scoped twin
  /// (`/v1/creator/onboard/{kind}/upload-url`) mints a file owned by the
  /// *user*, which `PATCH /v1/creator/{id}` then refuses — so once the
  /// channel exists, this is the one to use.
  static String creatorAssetUploadUrl(String creatorId, String kind) =>
      '$_creator/$creatorId/$kind/upload-url';

  /// The creator dashboard. `section` is one of `context`,
  /// `getting-started`, `attention`, `next-up`, `recent-content`.
  static String creatorDashboard(String creatorId, String section) =>
      '$_creator/$creatorId/dashboard/$section';

  static String creatorDashboardPerformance(String creatorId) =>
      '$_creator/$creatorId/dashboard/performance';

  static String creatorHandleAvailability(String handle) =>
      '$_creator/handle/$handle/availability';

  static const userCategories = '/v1/user/categories';
  static const userProfile = '/v1/user/profile';
  static const viewerPreferences = '/v1/user/me/viewer-preferences';
  static const onboardingState = '/v1/user/me/onboarding-state';

  static String creatorByHandle(String handle) => '/v1/creator/handle/$handle';

  static String creatorFeed(String creatorId) =>
      '/v1/discovery/creator/$creatorId/feed';

  static String creatorLibrary(String creatorId, String section) =>
      '/v1/discovery/creator/$creatorId/library/$section';

  static String publicPost(String id) => '/v1/public/content/posts/$id';

  static String publicDevotionalSeries(String id) =>
      '/v1/public/content/devotionals/series/$id';

  /// Marks a day read. Optional auth on the read routes, required here.
  static String devotionalEntryProgress(String entryId) =>
      '/v1/public/content/devotionals/entries/$entryId/progress';

  static String publicEvent(String id) => '/v1/public/content/events/$id';

  static const contentSuggestions = '/v1/discovery/content-suggestions';

  static const publicTestimonies = '/v1/public/engagement/testimonies';

  static const recommendedCreators = '/v1/discovery/recommended-creators';
  static const upcomingEvents = '/v1/discovery/upcoming-events';

  static String creatorSubscribe(String creatorId) =>
      '/v1/creator/$creatorId/subscribe';

  static const saasPlans = '/v1/payment/saas/plans';
  static const saasCurrencyHint = '/v1/payment/saas/currency-hint';

  static const mobileCheckouts = '/v1/payment/mobile-web-checkouts';
  static const mobileCheckoutCapabilities = '$mobileCheckouts/capabilities';

  static String mobileCheckout(String id) => '$mobileCheckouts/$id';

  static String mobileCheckoutLaunch(String id) =>
      '$mobileCheckouts/$id/launch';

  static String mobileCheckoutCancel(String id) =>
      '$mobileCheckouts/$id/cancel';

  static String provisionLivestream(String creatorId) =>
      '$_media/live/creator/$creatorId/provision';

  static String startLivestream(String creatorId) =>
      '$_media/live/creator/$creatorId/start';

  static String endLivestream(String mediaId) =>
      '$_media/live/streams/$mediaId/end';

  static String creatorLiveStatus(String creatorId) =>
      '$_public/live/creator/$creatorId/status';

  static String livestreamPlaybackToken(String mediaId) =>
      '$_media/live/streams/$mediaId/playback-token';

  static const interactions = '/v1/engagement/interactions';

  /// GET with `targetType` and a comma-separated `targetIds`. The integration
  /// guide lists this as a POST; staging only answers GET.
  static const myInteractionsBatch = '/v1/engagement/interactions/me/batch';
  static const publicComments = '/v1/public/engagement/comments';

  static String publicCommentReplies(String commentId) =>
      '/v1/public/engagement/comments/$commentId/replies';

  /// Writing needs a session; reading does not.
  static const comments = '/v1/engagement/comments';

  static String commentVote(String commentId) =>
      '/v1/engagement/comments/$commentId/vote';

  static String comment(String commentId) =>
      '/v1/engagement/comments/$commentId';

  static const beacons = '/v1/analytics/beacons';
  static const beaconsAuth = '/v1/analytics/beacons/auth';

  static const webFeed = '/v1/discovery/web-feed';
  static const verticalFeed = '/v1/discovery/vertical-feed';
  static String mediaDetail(String id) => '/v1/discovery/media/$id/detail';
  static String mediaPlaybackInfo(String id) => '/v1/media/$id/playback-info';
  static String publicMediaPlaybackInfo(String id) =>
      '/v1/public/media/$id/playback-info';
}
