/// The coarse funnel state, as `PATCH /v1/user/me/onboarding-state` types it.
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
