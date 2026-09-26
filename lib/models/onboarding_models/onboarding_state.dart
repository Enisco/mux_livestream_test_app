/// The coarse funnel state, as `PATCH /v1/user/me/onboarding-state` types it.
///
/// The contract declares every one of these fields as a bare
/// `{"type": "object"}`, so the allowed values are invisible in the schema.
/// They are not invisible to the validator, which names them on refusal —
/// these four lists were read off staging that way on 2026-09-26:
///
/// ```
/// status      must be one of: not_started, in_progress, completed, skipped
/// intent      must be one of: watch, creator
/// step        must be one of: platform_intent, viewer_preferences,
///                            creator_profile_type, creator_profile_form,
///                            subscription_plan
/// creatorType must be one of: individual, organization
/// ```
///
/// One trap worth keeping: the app's own word for the creator intent is
/// "ministry", which the API refuses. Everything user-facing may say
/// ministry; everything on the wire says `creator`.
library;

enum OnboardingStatus {
  notStarted('not_started'),
  inProgress('in_progress'),
  completed('completed'),
  skipped('skipped');

  const OnboardingStatus(this.slug);

  final String slug;

  static OnboardingStatus? parse(String? raw) =>
      values.where((v) => v.slug == raw).firstOrNull;
}

/// What the reader came to do. The API has two answers, not three.
enum OnboardingIntentState {
  watch('watch'),
  creator('creator');

  const OnboardingIntentState(this.slug);

  final String slug;

  static OnboardingIntentState? parse(String? raw) =>
      values.where((v) => v.slug == raw).firstOrNull;
}

/// How far along the funnel this reader is.
enum OnboardingStep {
  platformIntent('platform_intent'),
  viewerPreferences('viewer_preferences'),
  creatorProfileType('creator_profile_type'),
  creatorProfileForm('creator_profile_form'),
  subscriptionPlan('subscription_plan');

  const OnboardingStep(this.slug);

  final String slug;

  static OnboardingStep? parse(String? raw) =>
      values.where((v) => v.slug == raw).firstOrNull;
}

/// American here, and **British** in `billingSubject` on the plans route.
/// Both spellings are real; neither is a bug. See `BillingSubject`.
enum OnboardingCreatorType {
  individual('individual'),
  organization('organization');

  const OnboardingCreatorType(this.slug);

  final String slug;

  static OnboardingCreatorType? parse(String? raw) =>
      values.where((v) => v.slug == raw).firstOrNull;
}
