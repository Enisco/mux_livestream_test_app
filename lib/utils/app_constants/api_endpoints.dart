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
  static const publicComments = '/v1/public/engagement/comments';

  static const beacons = '/v1/analytics/beacons';
  static const beaconsAuth = '/v1/analytics/beacons/auth';

  static const webFeed = '/v1/discovery/web-feed';
  static const verticalFeed = '/v1/discovery/vertical-feed';
  static String mediaDetail(String id) => '/v1/discovery/media/$id/detail';
  static String mediaPlaybackInfo(String id) => '/v1/media/$id/playback-info';
  static String publicMediaPlaybackInfo(String id) =>
      '/v1/public/media/$id/playback-info';
}
