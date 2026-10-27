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

  /// What a creator has made. Three sources, because media, written posts
  /// and calendar events are three services.
  static String creatorMediaSearch(String creatorId) =>
      '$_media/creator/$creatorId/search';

  static String creatorPostsSearch(String creatorId) =>
      '/v1/content/posts/creator/$creatorId/search';

  static String creatorEventsSearch(String creatorId) =>
      '/v1/content/calendar/events/creator/$creatorId/search';

  /// Uploading a video or a piece of audio. Three calls, in this order:
  /// a ticket, the bytes straight to Mux as a **PUT**, then the row.
  /// A livestream uses none of these — see the live provision routes.
  static const mediaRequestUpload = '$_media/request-upload';
  static const mediaThumbnailUploadUrl = '$_media/thumbnail/upload-url';
  static const createMedia = _media;

  static String mediaById(String mediaId) => '$_media/$mediaId';

  /// Takes `{visibility}` and nothing else. It may be called while the
  /// upload is still processing: the backend publishes once Mux is ready.
  static String publishMedia(String mediaId) => '$_media/$mediaId/publish';

  /// Calendar events. They live in the content service, not the media one,
  /// and nothing about them is uploaded or transcoded.
  static const calendarEvents = '/v1/content/calendar/events';

  static String calendarEventById(String eventId) => '$calendarEvents/$eventId';

  /// Takes no body. Refuses the event unless a description is set, plus an
  /// address for anything physical and a meeting link for anything virtual.
  static String publishCalendarEvent(String eventId) =>
      '$calendarEvents/$eventId/publish';

  /// Articles. Markdown and images in the content service; nothing is
  /// transcoded. `scheduledAt` goes on with a PATCH, never on create.
  static const contentPosts = '/v1/content/posts';

  static String contentPostById(String postId) => '$contentPosts/$postId';

  static String publishContentPost(String postId) =>
      '$contentPosts/$postId/publish';

  /// Resolves each `![alt](file:{id})` in a body to a picture, or says why
  /// it cannot yet.
  static const contentPostBodyEmbeds = '$contentPosts/body-embeds/resolve';

  /// A cover image for a post or an event: `{creatorId, category, filename,
  /// mimeType, size}` where `category` is `cover` or `body_image`.
  static const contentAssetUploadUrl = '/v1/content/assets/upload-url';

  static String creatorHandleAvailability(String handle) =>
      '$_creator/handle/$handle/availability';

  /// Every studio the reader can work in — owned and joined. A user with
  /// none gets `{items: [], total: 0}`, not an error.
  static const creatorMemberships = '/v1/creator/me/memberships';

  /// Plan and usage together. **Not** on `dashboard/context`, where the
  /// upload quota was first looked for.
  static String creatorPlan(String creatorId) =>
      '/v1/creator/$creatorId/settings/plan';

  // ---- Hiding creators (gap responses §1.3, §1.4) ------------------------

  static const mutedCreators = '/v1/discovery/muted-creators';
  static String mutedCreator(String creatorId) => '$mutedCreators/$creatorId';

  /// The list is **not optional**: a blocked creator is hidden from every
  /// surface a viewer could rediscover them on, so without it the delete is
  /// unreachable and a block can never be undone.
  static const blockedCreators = '/v1/discovery/blocked-creators';
  static String blockedCreator(String creatorId) =>
      '$blockedCreators/$creatorId';

  /// Minting a link to paste. **Not** `/v1/media/live/streams/:id/share-link`,
  /// which mints an access token for an unlisted livestream.
  static const shareLinks = '/v1/engagement/share-links';

  /// Eight target types: `media`, `post`, `devotional`, `devotional_entry`,
  /// `event`, `testimony`, `verse_of_day`, `comment` — plus `user_playlist`,
  /// which is a **report** target only and not an engagement target.
  /// A session is required; a signed-out reader must sign in first.
  static const engagementReports = '/v1/engagement/reports';

  static const userCategories = '/v1/user/categories';
  static const userProfile = '/v1/user/profile';

  /// The account's own record. Probed on 2026-10-07: it takes `firstName`,
  /// `lastName`, `phone`, `gender` and `countryCode`, and **refuses**
  /// `email`, `password`, `language` and `avatarFileId` — a photo goes
  /// through the two avatar routes instead.
  static String user(String id) => '/v1/user/$id';

  // ---- Notifications ----------------------------------------------------

  /// Prisma-style advanced search: `{filters, sort}` in the body, `page` and
  /// `limit` as **query parameters** — the body refuses both.
  static const notificationSearch = '/v1/notification/search';
  static const notificationMarkRead = '/v1/notification/mark-read';
  static const notificationMarkAllRead = '/v1/notification/mark-all-read';
  static const notificationPreferences = '/v1/notification/preferences';
  static const notificationDeviceToken = '/v1/notification/device-token';

  // ---- Account credentials (backend gap responses §3.1, §3.2, §3.5) ------

  /// Signed-in email change. **Not** the signed-out forgot/reset pair: the
  /// code goes to the *new* address, because receiving it is the proof.
  static const emailChange = '/v1/user/me/email-change';
  static String emailChangeResend(String challengeId) =>
      '$emailChange/$challengeId/resend';
  static String emailChangeVerify(String challengeId) =>
      '$emailChange/$challengeId/verify';

  /// Signed-in password change. Takes the native `refreshToken` so the
  /// calling session survives; omit it and every session goes.
  static const passwordChange = '/v1/user/me/password';

  /// Per-account email 2FA. Enabling takes no password — the emailed code is
  /// the proof. Disabling takes one, because it is the direction an attacker
  /// on a stolen session wants.
  static const twoFactorEnable = '/v1/user/me/two-factor/enable';
  static String twoFactorEnableResend(String challengeId) =>
      '$twoFactorEnable/$challengeId/resend';
  static String twoFactorEnableVerify(String challengeId) =>
      '$twoFactorEnable/$challengeId/verify';
  static const twoFactorDisable = '/v1/user/me/two-factor/disable';

  static const userAvatarUploadUrl = '/v1/user/avatar/upload-url';
  static const userAvatarConfirm = '/v1/user/avatar/confirm';
  static const viewerPreferences = '/v1/user/me/viewer-preferences';
  static const onboardingState = '/v1/user/me/onboarding-state';

  static String creatorByHandle(String handle) => '/v1/creator/handle/$handle';

  static String creatorFeed(String creatorId) =>
      '/v1/discovery/creator/$creatorId/feed';

  static String creatorLibrary(String creatorId, String section) =>
      '/v1/discovery/creator/$creatorId/library/$section';

  static String publicPost(String id) => '/v1/public/content/posts/$id';

  /// A **media series** is not a media: `/v1/discovery/media/{id}/detail`
  /// answers 404 for one. This is the route that knows about them, and it
  /// carries `orderedMediaIds`, which is the series' running order.
  static String publicMediaSeries(String id) => '/v1/public/media/series/$id';

  static String publicDevotionalSeries(String id) =>
      '/v1/public/content/devotionals/series/$id';

  /// Marks a day read. Optional auth on the read routes, required here.
  static String devotionalEntryProgress(String entryId) =>
      '/v1/public/content/devotionals/entries/$entryId/progress';

  static String publicEvent(String id) => '/v1/public/content/events/$id';

  static const contentSuggestions = '/v1/discovery/content-suggestions';

  static const publicTestimonies = '/v1/public/engagement/testimonies';

  /// The creator's Impact inbox — prayers, testimonies and the comment
  /// moderation queue.
  ///
  /// The reads hang off the creator; **the writes do not.** A `PATCH` takes
  /// the row's own id and carries no creator segment, which is why these are
  /// two families rather than one builder.
  static String creatorPrayers(String creatorId) =>
      '/v1/creator/$creatorId/engagement/prayers';
  static String creatorPrayerSummary(String creatorId) =>
      '/v1/creator/$creatorId/engagement/prayers/summary';
  static String creatorPrayerAssignees(String creatorId) =>
      '/v1/creator/$creatorId/engagement/prayers/assignees';
  static String creatorPrayerUpdate(String prayerId) =>
      '/v1/creator/engagement/prayers/$prayerId';

  static String creatorTestimonies(String creatorId) =>
      '/v1/creator/$creatorId/engagement/testimonies';
  static String creatorTestimonySummary(String creatorId) =>
      '/v1/creator/$creatorId/engagement/testimonies/summary';
  static String creatorTestimonyModerate(String testimonyId) =>
      '/v1/creator/engagement/testimonies/$testimonyId/moderate';

  static String creatorComments(String creatorId) =>
      '/v1/creator/$creatorId/engagement/comments';
  static String creatorCommentModerate(String commentId) =>
      '/v1/creator/engagement/comments/$commentId/moderate';

  static const recommendedCreators = '/v1/discovery/recommended-creators';

  /// Everyone this reader follows, with `latestContentAt` and the four
  /// `notifyOn*` flags the notification sheet sets.
  static const followingCreators = '/v1/discovery/following-creators';
  static const upcomingEvents = '/v1/discovery/upcoming-events';

  static String creatorSubscribe(String creatorId) =>
      '/v1/creator/$creatorId/subscribe';

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

  /// A broadcast session, with its title, categories and replay policy.
  /// This is what the design's Go Live form fills in — the creator-scoped
  /// `start` above carries none of it.
  static String createLiveSession(String creatorId) =>
      '$_media/live/creator/$creatorId/sessions';

  /// Opens the window in which Mux will accept the encoder. Ingest is
  /// disabled the rest of the time, because a durable Mux livestream bills
  /// for it whenever it accepts data.
  static String armLiveIngest(String mediaId) =>
      '$_media/live/streams/$mediaId/ingest/arm';

  static String disableLiveIngest(String mediaId) =>
      '$_media/live/streams/$mediaId/ingest/disable';

  static String startLiveSession(String mediaId) =>
      '$_media/live/streams/$mediaId/start';

  static String cancelLiveSession(String mediaId) =>
      '$_media/live/streams/$mediaId/cancel';

  /// The prayer **bodies** for a broadcast, not a count.
  ///
  /// On the live namespace rather than a `streamId` filter on the creator
  /// inbox: the inbox is authorised for `owner | admin | editor`, but the
  /// studio is also held by a `streamer` — filtering it would have shipped a
  /// list the person actually broadcasting cannot open. Do **not** fall back
  /// to the inbox on a refusal; it will refuse too, for another reason.
  static String livePrayers(String mediaId) =>
      '$_media/live/streams/$mediaId/prayers';

  /// The authoritative snapshot: presence, giving, prayers and the
  /// session's own state.
  static String liveStudio(String mediaId) =>
      '$_media/live/streams/$mediaId/studio';

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

  /// Global discovery across every indexed entity. This is **OpenSearch**,
  /// a different mechanism from the Prisma-backed `SEARCH_*` routes used for
  /// creator-scoped catalogue reads — do not use it to list one creator's
  /// library.
  static const publicSearch = '/v1/search/public/query';

  /// Type-ahead over the same index. **Undocumented** — the integration
  /// guide lists it as not yet client-integrated, so the contract below was
  /// probed against staging on 2026-10-05: `?q=&size=1..20&entityTypes=`,
  /// answering `{hits: [{entityType, entityId, title, subtitle}]}`.
  static const publicSearchAutocomplete = '/v1/search/public/autocomplete';

  static const continueWatching = '/v1/analytics/viewer/continue-watching';

  /// The viewer's own library.
  ///
  /// The two history deletes are **hide-through-an-instant** operations, not
  /// row deletions: each answers with the timestamp history is suppressed up
  /// to, and watching the same thing again brings it back.
  static const viewerHistory = '/v1/discovery/viewer/history';
  static String viewerHistoryItem(String targetType, String targetId) =>
      '/v1/discovery/viewer/history/$targetType/$targetId';
  static const myLiked = '/v1/engagement/interactions/me/liked';

  /// Playlists hold **media only**; posts, events and devotionals use the
  /// `favorite` interaction instead. The list is a Prisma advanced search, so
  /// it pages by number rather than by cursor.
  /// The reader's own records, across every ministry they have dealt with.
  static const myEvents = '/v1/content/calendar/events/mine';
  static String eventRsvp(String id) => '/v1/content/calendar/events/$id/rsvp';
  static String eventRsvpReminder(String id) =>
      '/v1/content/calendar/events/$id/rsvp/reminder';
  static const myPrayers = '/v1/engagement/prayers/mine';
  static const myTestimonies = '/v1/engagement/testimonies/mine';
  static String testimony(String id) => '/v1/engagement/testimonies/$id';
  static const myGivingSummary = '/v1/payment/giving/me/summary';
  static const myGifts = '/v1/payment/giving/me/gifts';

  static const playlists = '/v1/media/playlists';
  static const playlistSearch = '/v1/media/playlists/search';
  static String playlist(String id) => '/v1/media/playlists/$id';
  static String publicPlaylist(String id) => '/v1/public/media/playlists/$id';

  /// A viewer-supplied playlist cover. Its own `playlist_cover` category, so
  /// a viewer cannot name their own avatar's `fileId` as a cover and have the
  /// next replacement delete it out from under their profile.
  static String playlistCoverUploadUrl(String playlistId) =>
      '${playlist(playlistId)}/cover/upload-url';
  static String playlistItems(String id) => '/v1/media/playlists/$id/items';
  static String playlistItem(String id, String mediaId) =>
      '/v1/media/playlists/$id/items/$mediaId';
  static const mySaved = '/v1/engagement/interactions/me/saved';

  static const webFeed = '/v1/discovery/web-feed';
  static const verticalFeed = '/v1/discovery/vertical-feed';
  static String mediaDetail(String id) => '/v1/discovery/media/$id/detail';
  static String mediaPlaybackInfo(String id) => '/v1/media/$id/playback-info';
  static String publicMediaPlaybackInfo(String id) =>
      '/v1/public/media/$id/playback-info';

  // ---- Creator Giving ---------------------------------------------------
  //
  // Two families under one feature. `/payment/earnings/*` is the creator's
  // side — the recipient application, its rails, and what they have earned.
  // `/payment/giving/funds*` is the purposes givers choose between. The
  // donor's own routes (`checkout`, `quote`, `me/gifts`) are elsewhere in
  // this file and are a different reader entirely.
  //
  // Rail enrolment and every configuration change are step-up gated: a code
  // is emailed, and the grant it mints is spent on the very next call.

  static const _earnings = '/v1/payment/earnings';

  /// The legal recipient and the rails under it. `GET` takes `?creatorId=`
  /// and answers `{application: null}` before anything has been applied for.
  static const givingApplication = '$_earnings/application';

  /// The provider / country / currency combinations policy currently allows,
  /// plus the `termsVersion` the application must be created against.
  /// Never cached as permanent capability — re-read before every enrolment.
  static const givingApplicationOptions = '$givingApplication/options';

  /// Rail-scoped, and each requirement says who owns it: the creator, a
  /// reviewer at GospelTube, or the provider.
  static const givingApplicationRequirements =
      '$givingApplication/requirements';

  static const givingEvidenceUploadUrl =
      '$givingApplication/evidence/upload-url';
  static const givingEvidence = '$givingApplication/evidence';
  static const givingApplicationSubmit = '$givingApplication/submit';

  static const givingRails = '$_earnings/rails';
  static String givingRail(String railId) => '$givingRails/$railId';
  static String givingRailHoldingCurrencies(String railId) =>
      '${givingRail(railId)}/holding-currencies';

  /// A versioned change to a live rail's country, currency, destination or
  /// legal recipient. The old configuration stays active through review and
  /// a 48-hour cooling period.
  static const givingChangeRequests = '$_earnings/change-requests';
  static String givingChangeRequest(String id) => '$givingChangeRequests/$id';
  static String givingChangeRequestCancel(String id) =>
      '${givingChangeRequest(id)}/cancel';

  static const khaimeBanks = '$_earnings/khaime/banks';
  static const khaimeKyc = '$_earnings/khaime/kyc';
  static const khaimeKycResubmit = '$khaimeKyc/resubmit';

  static const paystackBanks = '$_earnings/paystack/banks';
  static const paystackBankAccount = '$_earnings/paystack/bank-account';
  static const paystackSubaccount = '$_earnings/paystack/subaccount';

  static const stripeOnboardingLink = '$_earnings/stripe/onboarding-link';
  static const stripeAccountSession = '$_earnings/stripe/account-session';

  /// Provider-reported totals, grouped by settlement currency. Answers
  /// **"Giving application not found"** until an application exists, which
  /// is why the Giving tab reads the application first.
  static const earningsSummary = '$_earnings/summary';
  static const earningsTransactions = '$_earnings/transactions';
  static const earningsSettlements = '$_earnings/settlements';
  static const earningsPayouts = '$_earnings/payouts';

  /// Withdrawing from a provider-held rail's released balance. A direct rail
  /// has no withdrawal: its PSP settles on its own schedule.
  static const earningsPayoutRequest = '$earningsPayouts/request';

  /// The purposes a giver can choose between. `GET` creates the reserved
  /// `general` fund idempotently, so the list is never empty.
  static const givingFunds = '/v1/payment/giving/funds';
  static String givingFund(String fundId) => '$givingFunds/$fundId';

  /// The emailed one-time code that gates rail enrolment and every
  /// configuration change.
  static const stepUpChallenges = '/v1/auth/step-up/challenges';
  static String stepUpVerify(String id) => '$stepUpChallenges/$id/verify';
  static String stepUpResend(String id) => '$stepUpChallenges/$id/resend';
}
