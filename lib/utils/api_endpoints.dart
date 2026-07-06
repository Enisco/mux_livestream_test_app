abstract final class ApiEndpoints {
  static const _auth = '/v1/auth';
  static const _creator = '/v1/creator';
  static const _media = '/v1/media';
  static const _public = '/v1/public';

  // Auth
  static const register = '$_auth/register';
  static const login = '$_auth/login';
  static const refresh = '$_auth/sessions/refresh';
  static const logout = '$_auth/logout';

  // Creator
  static const onboardCreator = '$_creator/onboard';
  static const creatorProfile = '$_creator/profile';

  // Livestream — creatorId injected at call time
  static String provisionLivestream(String creatorId) =>
      '$_media/live/creator/$creatorId/provision';

  static String startLivestream(String creatorId) =>
      '$_media/live/creator/$creatorId/start';

  static String endLivestream(String mediaId) =>
      '$_media/live/streams/$mediaId/end';

  // Public — no auth required
  static String creatorLiveStatus(String creatorId) =>
      '$_public/live/creator/$creatorId/status';

  static String livestreamPlaybackToken(String mediaId) =>
      '$_media/live/streams/$mediaId/playback-token';

  // Engagement
  static const interactions = '/v1/engagement/interactions';
  static const publicComments = '/v1/public/engagement/comments';

  // Analytics
  static const beaconsAuth = '/v1/analytics/beacons/auth';

  // Discovery
  static const webFeed = '/v1/discovery/web-feed';
  static const verticalFeed = '/v1/discovery/vertical-feed';
  static String mediaDetail(String id) => '/v1/discovery/media/$id/detail';
  static String mediaPlaybackInfo(String id) => '/v1/media/$id/playback-info';
}
