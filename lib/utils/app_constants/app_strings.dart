abstract final class AppStrings {
  static const appTitle = 'GTube';

  static const brandName = 'GospelTube';

  static const splashTagline = 'Streaming the good news';

  static const welcomeTitle = 'Welcome to GospelTube';
  static const welcomeSubtitle = "Sign up to join GospelTube, it's free";
  static const continueWithGoogle = 'Continue with Google';
  static const continueWithApple = 'Continue with Apple';
  static const continueWithEmail = 'Continue with Email';
  static const alreadyHere = 'Already here?';
  static const justBrowse = 'Just browse for now';

  static const signInLink = 'Sign in';

  static const createAccountTitle = 'Create your account';
  static const createAccountSubtitle =
      'One account for watching, giving, and any ministry you serve.';
  static const fieldFirstName = 'First name';
  static const fieldLastName = 'Last name';
  static const fieldPhone = 'Phone number';
  static const fieldGenderOptional = 'Gender (optional)';
  static const selectACountry = 'Select your country';
  static const searchCountryHint = 'Search country or code';
  static const noCountriesFound = 'No matching country';
  static const fieldEmail = 'Email';
  static const fieldPassword = 'Password';
  static const show = 'Show';
  static const hide = 'Hide';
  static const termsPrefix = 'By continuing, you agree to our ';
  static const terms = 'Terms';

  static const termsAmpersand = '\n & ';
  static const privacyPolicy = 'Privacy Policy';

  static const checkYourMail = 'Check your mail';
  static const otpSentPrefix = 'We sent a 6-digit code to ';
  static const otpSentSuffix = ". Enter it below to confirm it's you.";
  static const didntGetIt = "Didn't get it? ";
  static const sendAgain = 'Send again ';
  static const verify = 'Verify';

  static const welcomeNoteGreeting = 'Hello ';
  static const welcomeNoteWelcome = 'Welcome to ';

  static const roleQuestionPrefix = 'Welcome ';
  static const roleQuestionSuffix = 'how will you use GospelTube?';
  static const roleSubtitle =
      'This just helps us set things up, you can do both later.';
  static const roleWatch = 'I’m here to watch & follow';
  static const roleMinistry = 'I’m here to share my ministry';

  static const discoveryTitle = 'One last thing, how did you find us?';
  static const discoverySubtitle =
      'It helps us reach more people. Totally optional.';
  static const discoveryFriend = 'A friend or family';
  static const discoveryChurch = 'My church';
  static const discoverySocial = 'Social media';
  static const discoveryYoutube = 'Youtube';
  static const discoveryGoogle = 'A Google search';
  static const discoveryPodcast = 'A podcast or event';
  static const typeHere = 'Type here';
  static const continueLabel = 'Continue';

  static const interestsTitle = 'What would you like to see?';
  static const interestsSubtitle = 'This helps us customize your experience';
  static const interestsHint = 'Pick 3 or more for the best feed.';
  static const skip = 'Skip';
  // The interest chips are labelled by `GET /v1/user/categories` now, so the
  // app holds no copy of the taxonomy to drift out of step with it.

  static const creatorSetupTitle = 'Create your ministry';
  static const creatorSetupSubtitle = 'This sets up your studio';
  static const creatorSetupProceed = 'Proceed';
  static const creatorSetupFailed =
      'Your channel could not be created. Please try again.';
  static const creatorNameRequired = 'Your channel needs a name';

  // Categories: the server caps the list at 8, the form insists on at least
  // one. Both match the web client.
  static const creatorCategoryMax = 8;
  static const creatorCategoryMin1 = 'Choose at least one category';
  static const creatorCategoryTooMany = 'Choose no more than 8 categories';

  // The organisation block. `POST /v1/creator/onboard` refuses an
  // organisation without these six; postal code and website are optional.
  static const orgEmailLabel = 'Organization email';
  static const orgEmailHint = 'hello@gracechurch.org';
  static const orgEmailInvalid = 'Enter a valid email address';
  static const orgPhoneLabel = 'Organization phone';
  static const orgPhoneHint = '+1 555 012 3456';
  static const orgAboutLabel = 'About';
  static const orgAboutHint = 'Tell viewers about your ministry';
  static const orgCountryLabel = 'Country';
  static const orgCountryHint = 'Select country';
  static const orgStateLabel = 'State / Province';
  static const orgStateHint = 'e.g Lagos';
  static const orgCityLabel = 'City';
  static const orgCityHint = 'e.g Ikeja';
  static const orgPostalLabel = 'Postal code';
  static const orgPostalHint = 'e.g 37203';
  static const orgWebsiteLabel = 'Website';
  static const orgWebsiteOptional = 'optional';
  static const orgWebsiteHint = 'https://gracechurch.org';
  static const orgFieldsRequired =
      'Fill in the organisation details before continuing';

  static const channelName = 'Channel name';
  static const channelNameHint = 'e.g Pastor Cece Winans';
  static const handleLabel = 'Handle';
  static const handlePrefix = '@';
  static const mostlyShare = 'What do you mostly share?';
  static const mostlyShareHint = 'e.g Preaching';
  static const handleAvailable = 'Available — gospeltube.tv/@';
  static const handleTaken = 'That handle is taken';
  static const handleInvalid = 'That handle is not valid';

  // "Start creating" — who the channel is for.
  static const creatorTypeTitle = 'Start creating';
  static const creatorTypeSubtitle = 'Who is this channel for?';
  static const creatorTypeIndividual = 'Just me';
  static const creatorTypeIndividualBody =
      'A pastor, teacher, worship leader or speaker sharing under your own '
      'name.';
  static const creatorTypeOrganization = 'A ministry or church';
  static const creatorTypeOrganizationBody =
      'An organisation with a team you become the Owner and can invite '
      'members with roles.';
  static const creatorTypeFootnote =
      "You keep watching as yourself either way, this adds a studio, it "
      "doesn't replace your account.";

  static const orgNameLabel = 'Organization name';
  static const orgNameHint = 'e.g CCI international';
  static const addSelection = 'Add Selection';

  // Once the plan is settled: the channel exists, now make it look like one.
  static const creatorLiveTitlePrefix = "You're in,";
  static const creatorLiveBodyPrefix = 'Your channel is live on';
  static const creatorLiveBodyBrand = 'GospelTube';
  static const creatorLiveBodySuffix = ". Let's make it yours.";
  static const creatorLiveSetUp = 'Set up your profile';
  static const creatorDoThisLater = "I'll do this later";

  static const creatorPhotoTitle = 'Add your ministry photo';
  static const creatorPhotoSubtitle =
      'It appears beside everything you '
      'publish.';
  static const creatorPhotoCaption = 'This is what viewers see on your page';

  static const creatorBannerTitle = 'Add a banner';
  static const creatorBannerSubtitle =
      'It appears beside everything you '
      'publish.';
  static const creatorBannerTapToAdd = 'Tap to add';

  static const creatorBioTitlePrefix = 'What is';
  static const creatorBioTitleSuffix = 'about?';
  static const creatorBioSubtitle =
      'One or two sentences on your channel '
      'page.';
  static const creatorBioHint =
      'Spirit-led worship and teaching, sharing the hope of the gospel with '
      'our city and beyond.';

  /// The design's ceiling. Staging's own is 500, so this is the stricter of
  /// the two and the one the counter shows.
  static const creatorBioLimit = 300;
  static const creatorBioSaving = 'Saving...';

  static const creatorLinksTitle = 'Where else do people find you?';
  static const creatorLinksSubtitle =
      'Website and socials, shown on your '
      'page.';
  static const creatorLinksLabel = 'Website & social links';
  static const creatorLinksOptional = 'optional';
  static const creatorLinksWebsiteHint = 'yourchurch.org';
  static const creatorLinksInstagramHint = 'Instagram URL';
  static const creatorLinksYoutubeHint = 'Youtube URL';
  static const creatorLinksAddAnother = 'Add another link';
  static const creatorLinksMoreHint = 'Another URL';

  static const creatorImageTooLarge =
      'That image is over 8 MB. Pick a smaller one.';
  static const creatorImageUnreadable = 'That image could not be opened.';
  static const creatorImageUnsupported =
      'That image format is not supported. Try a JPG or PNG.';
  static const creatorImageChange = 'Change';
  static const creatorImageUploading = 'Uploading...';
  static const creatorImageUploadFailed =
      'That upload did not go through. Try again.';
  static const creatorImageOffline =
      'No connection. Your image will need re-picking once you are back.';

  static const creatorTopicsTitle = 'Your topics';
  static const creatorTopicsSubtitle = 'Choose what you would mostly share';
  static const creatorTopicsLabel = 'Topics';
  static const creatorTopicsDone = 'Done';

  static const yourPlan = 'Your plan';
  static const planHandoffSubtitle = 'Start free, or upgrade any time.';
  static const planChoose = 'See paid plans';
  static const planFreeHeading = 'Free';
  static const planHandoffNote =
      'Paid plans open in a secure browser, where you pick the plan, currency '
      'and payment method. You will come straight back here when you are '
      'done.';

  /// Shown both when the storefront genuinely may not sell and when the
  /// capability check fails, which cannot be told apart from the client — so
  /// it states the effect rather than guessing at a reason.
  static const planUnavailableHere =
      "Paid plans aren't available on this device right now. Everything "
      'below is yours on Free.';
  static const compareEverything = 'Compare everything';
  static const continueWithFree = 'Continue with Free';

  static const planFreeTagline = 'Start sharing today';

  static const loginTitle = 'Log in to GospelTube';
  static const noAccount = 'Don’t have an account';
  static const signUpLink = 'Sign up';
  static const orDivider = 'Or';
  static const logIn = 'Log in';
  static const forgotPasswordLink = 'Forgot password?';

  static const forgotPasswordTitle = 'Forgot Password';
  static const forgotPasswordSubtitle =
      'No worries, we’ll send you a reset link';
  static const emailHint = 'e.g name@mail.com';
  static const resetPassword = 'Reset Password';
  static const resetLinkSent = 'Check your inbox for the reset link.';

  /// Finishing the reset, once the email has arrived.
  static const setNewPasswordTitle = 'Set a new password';
  static const setNewPasswordSubtitle =
      'Paste the code from your reset email, then choose a new password.';
  static const resetCodeHint = 'Reset code';
  static const newPasswordHint = 'New password';
  static const confirmPasswordHint = 'Confirm new password';
  static const saveNewPassword = 'Save new password';
  static const haveResetCode = 'I have a reset code';
  static const passwordResetDone =
      'Your password has been changed. Sign in with it now.';
  static const backToSignIn = 'Back to sign in';
  static const resetCodeRequired = 'Paste the code from your reset email';
  static const passwordRequired = 'Password is required';
  static const passwordTooShort = 'Minimum 8 characters';
  static const passwordTooLong = 'Maximum 128 characters';
  static const passwordsDoNotMatch = 'Both passwords must match';
  static const resetTokenRejected =
      'That reset code is invalid or has expired. Request a new link.';

  static const followingLabel = 'Following';
  static const share = 'Share';
  static const descriptionLabel = 'Description';
  static const showMore = 'Show more';
  static const addAComment = 'Add a comment';
  static const reply = 'Reply';
  static const showReplies = 'Show replies';
  static const hideReplies = 'Hide';
  static const repliesWord = 'replies';
  static const replyWord = 'reply';
  static const replyingTo = 'Replying to';
  static const creatorBadge = 'Creator';
  static const someone = 'Someone';
  static const noCommentsYet = 'No comments yet';
  static const beTheFirstToComment =
      'Be the first to share what this meant to you.';
  static const commentFeature = 'comment';
  static const commentFailed = 'Your comment did not send. Try again.';
  static const loading = 'Loading…';
  static const showLess = 'Show less';
  static const comments = 'Comments';
  static const upNext = 'Up next';

  static const tabLatest = 'Latest';
  static const tabLibrary = 'Library';
  static const summaryLabel = 'Summary';
  static const daysInDevotion = 'Days in devotion';
  static const viewsLabel = 'Views';

  static const sectionSeries = 'Series';
  static const sectionVideos = 'Videos';
  static const sectionAudios = 'Audios';
  static const sectionDevotions = 'Devotions';
  static const sectionArticles = 'Articles';
  static const sectionEvents = 'Events';

  static const typeVideo = 'Video';
  static const typeAudio = 'Audio';
  static const typeArticle = 'Article';
  static const typeEvent = 'Event';
  static const typeDevotional = 'Devotional';
  static const typeSeries = 'Series';
  static const viewsLower = 'views';
  static const viewLower = 'view';

  static const tabTestimonies = 'Testimonies';
  static const tabAbout = 'About';

  static const unfollow = 'Unfollow';
  static const giveNow = 'Give Now';
  static const subscribers = 'Subscribers';
  static const subscribeFollow = 'Subscribe/follow';
  static const notifyMeWhenLive = 'Notify me when live';
  static const shareYourTestimony = 'Share your testimony';

  static const creatorEmptyLatestTitle = 'Nothing posted yet';
  static const creatorEmptyLatestBody =
      "When a sermon, song, or content is shared, it'll show up here first.";
  static const creatorEmptyLibraryTitle = 'The library is empty for now';
  static const creatorEmptyLibraryBody =
      'Videos, audios, series, and devotionals will be collected here as this '
      'ministry shares them.';
  static const creatorEmptyLiveTitle = 'Not live right now';
  static const creatorEmptyLiveBody =
      "When this ministry goes live, you'll be able to watch and join the "
      'conversation here.';
  static const creatorEmptyTestimoniesTitle = 'No testimonies yet';
  static const creatorEmptyTestimoniesBody =
      'This is where the community shares what God has done. Be the first to '
      'share your story.';

  static const aboutLabel = 'About';
  static const detailsLabel = 'Details';
  static const reachLabel = 'Reach & Stewardship';
  static const typeLabel = 'Type';
  static const onGospelTube = 'On GospelTube';
  static const sincePrefix = 'Since ';
  static const totalViewsLabel = 'Total views';
  static const notAvailable = 'N/A';
  static const anonymousTestimony = 'Shared anonymously';
  static const creatorTypeOrganisationValue = 'Organisation';
  static const creatorTypeIndividualValue = 'Individual';

  static const checkoutTitle = 'Your subscription';
  static const checkoutOpening = 'Opening secure checkout…';
  static const checkoutInBrowser =
      'Finish your payment in the browser, then come back here.';
  static const checkoutConfirming = 'Confirming your payment…';
  static const checkoutConfirmed = 'Payment confirmed. Welcome aboard.';
  static const checkoutPending =
      "Payment received. We're still confirming it — your plan will update "
      'shortly.';
  static const checkoutFailed = 'That payment did not go through.';
  static const checkoutCanceled = 'Checkout was cancelled.';
  static const checkoutExpired =
      'That checkout attempt expired. Start a new one when you are ready.';
  static const checkoutUnavailable =
      'Subscriptions are not available in your region yet.';
  static const checkoutStillProcessing =
      "Your previous attempt is still processing. We'll update your plan as "
      'soon as it settles.';
  static const checkAgain = 'Check again';
  static const tryAgain = 'Try again';
  static const notNow = 'Not now';
  static const cancel = 'Cancel';
  static const justNow = 'just now';

  static const selectAGender = 'Select a gender';
  static const genderMale = 'Male';
  static const genderFemale = 'Female';
  static const genderOther = 'Others';

  static const featureAudioBible = 'The Audio Bible';
  static const featureLiveService = 'Sunday service • 2.1k watching';
  static const featureDevotional = 'Daily devotional';
  static const featureWorship = 'Worship at midnight';
  static const featureVerse = '"Come to me, all who are weary..."';
  static const liveBadge = 'LIVE';

  static const sponsored = 'Sponsored';
  static const rsvp = 'RSVP';
  static const readMore = 'Read more';

  /// A run of videos and tracks a creator arranged in order.
  static const seriesTitle = 'Series';
  static const inThisSeries = 'In this series';
  static const seriesEmpty = 'Nothing has been added to this series yet.';
  static String seriesEpisode(int n) => 'Episode $n';

  static const startDevotion = 'Start Devotion';

  /// The same plan, once this reader has begun it.
  static const continueDevotion = 'Continue';

  /// The overlay across a devotional cover, e.g. "14-day devotional plan".
  static String devotionalPlanLabel(int days) => '$days-day devotional plan';
  static const follow = 'Follow';
  static const following = 'Following';
  static const viewChannel = 'View Channel';

  static const offline = 'No internet connection';
  static const done = 'Done';

  static const navHome = 'Home';
  static const navExplore = 'Explore';
  static const navFollowing = 'Following';
  static const navYou = 'You';

  // Settings — the account menu.
  static const settingsTitle = 'Account';
  static const settingsProfile = 'PROFILE';
  static const settingsPreferences = 'PREFERENCES';
  static const settingsSecurity = 'SECURITY';
  static const settingsEdit = 'Edit';
  static const settingsChange = 'Change';
  static const settingsDisplayNamePhoto = 'Display name & photo';
  static const settingsEmail = 'Email';
  static const settingsPhone = 'Phone number';
  static const settingsPassword = 'Password';
  static const settingsLanguage = 'Language';
  static const settingsLanguageValue = 'English';
  static const settingsTopics = 'Your topics';
  static const settingsEventReminders = 'Event reminders';
  static const settingsTwoFactor = 'Two-factor authentication';
  static const settingsLogOutAll = 'Log out all devices';
  static const settingsLogOutAllSub = 'Ends every active session';
  static const settingsDeactivate = 'Deactivate account';
  static const settingsNotSet = 'Not set';
  static const accountFallbackName = 'User';

  // Settings forms — the screens each account row leads to.
  static const settingsUpdate = 'Update';
  static const settingsProfileInfo = 'Profile info';
  static const settingsChangePhoto = 'Change photo';
  static const settingsDisplayName = 'Display name';
  static const settingsFirstNameHint = 'First name';
  static const settingsLastNameHint = 'Last name';
  static const settingsChangeEmailTitle = 'Change email address';
  static const settingsEmailNotice =
      "We'll send a verification link to your new address. Your email "
      'changes once you confirm it.';
  static const settingsCurrentEmail = 'Current email';
  static const settingsNewEmail = 'New email';
  static const settingsChangePhoneTitle = 'Phone number';
  static const settingsPhoneNotice =
      "We'll send a verification code to your new number. Your number "
      'changes once you confirm it.';
  static const settingsCurrentPhone = 'Current phone number';
  static const settingsNewPhone = 'New phone number';
  static const settingsChangePasswordTitle = 'Change password';
  static const settingsCurrentPassword = 'Current password';
  static const settingsNewPassword = 'New password';
  static const settingsConfirmPassword = 'Confirm new password';
  static const settingsPasswordRule =
      'At least 8 characters, with a number and a letter.';
  static const settingsConfirmEmailTitle = 'Check your mail';
  static const settingsConfirmPhoneTitle = 'Check your messages';
  static const settingsOtpNotWired =
      'Confirming this change is not wired to the API yet.';
  static const settingsOtpResendNotWired =
      'Sending another code is not wired to the API yet.';
  static const settingsShow = 'Show';
  static const settingsHide = 'Hide';

  // Settings forms — what goes wrong.
  static const settingsNameRequired = 'Enter your first and last name.';
  static const settingsEmailRequired = 'Enter your new email address.';
  static const settingsEmailInvalid =
      'That does not look like an email address.';
  static const settingsEmailUnchanged = 'That is already your email address.';
  static const settingsPhoneRequired = 'Enter your new phone number.';
  static const settingsPhoneInvalid =
      'Enter a phone number with at least 7 digits.';
  static const settingsPhoneUnchanged = 'That is already your phone number.';
  static const settingsPasswordRequired = 'Enter your current password.';
  static const settingsPasswordWeak = AppStrings.settingsPasswordRule;
  static const settingsPasswordMismatch = 'Those passwords do not match.';
  static const settingsPasswordSame =
      'Your new password must differ from the current one.';

  // Two-factor authentication — the enrolment flow.
  static const twoFactorTitle = 'Two-factor authentication';
  static const twoFactorHeading = 'Add a second lock';
  static const twoFactorBody =
      "When you sign in, you'll also enter a 6-digit code from an "
      'authenticator app on your phone.';
  static const twoFactorApps =
      'Works with Google Authenticator, Authy, 1Password or any TOTP app. '
      'No SMS needed.';
  static const twoFactorSetup = 'Setup';
  static const twoFactorScanTitle = 'Scan this code';
  static const twoFactorScanBody =
      'Open your authenticator app and scan — or add the key by hand.';
  static const twoFactorAdded = "I've added it";
  static const twoFactorKeyCopied = 'Key copied';
  static const twoFactorCodeTitle = 'Enter the code';
  static const twoFactorCodeBody =
      'Type the 6-digit code your app shows right now, so we know '
      "it's connected.";
  static const twoFactorTurnOn = 'Turn on 2FA';
  static const twoFactorOn = '2FA is on';
  static const twoFactorOff = '2FA is off';
  static const twoFactorOffSub = 'Not set up on this account yet';
  static const twoFactorRescan = 'Rescan / new device';
  static const twoFactorRescanSub = 'Re-enroll with a fresh code';
  static const twoFactorBeginSetup = 'Begin Setup';
  static const twoFactorLostPhoneLead = 'Lose your phone?';
  static const twoFactorLostPhoneBody =
      ' Reset your password by email to get back in, that signs out every '
      'device.';
  static const twoFactorNotWired =
      'Turning on 2FA is not wired to the API yet.';
  static const twoFactorResendNotWired =
      'There is no route to issue a fresh secret yet.';

  // Event reminders, topics, and the two destructive account actions.
  static const remindersTitle = 'Event reminders';
  static const remindersToggle = 'Remind me before events';
  static const remindersToggleSub = "For events you've said you're going to";
  static const remindersWhen = 'WHEN';
  static const remindersDefault = 'Default';
  static const remindersNote =
      'Reminders arrive as push and in-app notifications. Virtual events '
      'include the meeting link; in-person ones include the venue.';
  static const remindersNotWired =
      'Saving your reminder choice is not wired to the API yet.';

  static const topicsTitle = 'Edit your topics';
  static const topicsSubtitle =
      'Choose what shows on your feed. Drag to reorder.';
  static const topicsCaption = 'Topics';
  static const topicsDone = 'Done';
  static const topicsNotWired =
      'Saving your topics is not wired to the API yet.';

  static const logOutAllTitle = 'Log out of all devices?';
  static const logOutAllBody =
      "You'll be signed out everywhere, including this one. You'll need to "
      'log in again with your password.';
  static const logOutAllNote =
      'Useful if you lost a device or suspect someone else has access.';
  static const logOutAllConfirm = 'Log out of all';
  static const logOutAllNotWired =
      'Logging out every device is not wired to the API yet.';

  static const deactivateTitle = 'Deactivate your account?';
  static const deactivateBody =
      "Your profile and activity will be hidden, and you'll be logged out.";
  static const deactivateKeeps =
      'Your content and giving records are preserved';
  static const deactivateReturn =
      'You can reactivate anytime by logging back in';
  static const deactivateHidden =
      "Others won't see your profile while deactivated";
  static const deactivateConfirm = 'Deactivate';
  static const deactivateNotWired =
      'Deactivating an account is not wired to the API yet.';

  static const commonCancel = 'Cancel';

  // Liked and Saved — two libraries built on the History skeleton.
  static const likedTitle = 'Liked';
  static const likedSearchHint = 'Search...';
  static const likedCountSuffix = "things you've appreciated";
  static const likedEmptyTitle = 'Nothing liked yet';
  static const likedEmptyBody =
      "Tap the heart on a sermon, song, or message you appreciate, and it'll "
      'gather here.';
  static const likedClearTitle = 'Clear everything you have liked?';
  static const likedClearBody =
      'This empties the list. It does not unlike anything on the content '
      'itself.';

  static const savedTitle = 'Save';
  static const savedCountSuffix = 'contents saved';
  static const savedEmptyTitle = 'Nothing saved yet';
  static const savedEmptyBody =
      'Tap the bookmark on any sermon, song, article, devotional, or event '
      'to keep it here for later.';
  static const savedClearTitle = 'Clear everything you have saved?';
  static const savedClearBody =
      'This empties the list. It does not unsave anything on the content '
      'itself.';

  static const libraryFilterAll = 'All';
  static const libraryFilterVideo = 'Video';
  static const libraryFilterAudio = 'Audio';
  static const libraryFilterDevotionals = 'Devotionals';
  static const libraryFilterArticles = 'Articles/Blog';
  static const libraryNoMatchTitle = 'Nothing matched';
  static const libraryNoMatchBody =
      'Try a different word, or clear the search to see everything.';

  // My events, prayer requests and testimonies.
  static const myEventsTitle = 'My events';
  static const myEventsSort = 'Recent';
  static const myEventsCountSuffix = 'events';
  static const myEventsUpcoming = 'UPCOMING';
  static const myEventsPast = 'PAST';
  static const myEventsRsvp = 'RSVP';
  static const myEventsGoing = 'Going';
  static const myEventsAddToCalendar = 'Add to calendar';
  static const myEventsEmptyTitle = 'No events yet';
  static const myEventsEmptyBody =
      "When you RSVP to a service, conference, or gathering, it'll show up "
      "here with a reminder so you don't miss it.";

  static const prayerTitle = 'My prayer requests';
  static const prayerAboutPrefix = 'About:';
  static const prayerGeneral = 'General';
  static const prayerSharedPrefix = 'Shared';
  static const prayerStatusOpen = 'Open';
  static const prayerStatusPrayedFor = 'Prayed for';
  static const prayerStatusClosed = 'Closed';
  static const prayerFilterAll = 'All';
  static const prayerFilterOpen = 'Open';
  static const prayerFilterAudio = 'Audio';
  static const prayerFilterPrayedFor = 'Prayed for';
  static const prayerFilterClosed = 'Closed';
  static const prayerActionEdit = 'Edit';
  static const prayerActionPrayAgain = 'Pray again';
  static const prayerActionGoToContent = 'Go to content';
  static const prayerActionDelete = 'Delete';
  static const prayerEmptyTitle = 'No request yet';
  static const prayerEmptyBody =
      "When something weighs on you, any ministry's page has a place to ask, "
      'and what you send shows up here, between you and them.';

  static const testimoniesTitle = 'Testimonies';
  static const testimoniesSubmittedPrefix = 'Submitted';
  static const testimonyPending = 'Pending review';
  static const testimonyApproved = 'Approved';
  static const testimonyRejected = 'Not approved';
  static const testimonyPendingNote =
      'A Leader at Grace chapel will review this before it appears on their '
      'testimony wall';
  static const testimonyLivePrefix = 'Live on';
  static const testimonyLiveSuffix = "'s wall";
  static const testimonyRejectedNote =
      "This wasn't published to the wall. You can edit and resubmit, or reach "
      'the ministry if you have questions.';
  static const testimonyActionView = 'View on wall';
  static const testimonyActionRemove = 'Remove testimony';
  static const testimoniesEmptyTitle = 'No testimonies yet';
  static const testimoniesEmptyBody =
      'When you share what God has done with a ministry, your testimonies and '
      'their status will be kept here. Each one is reviewed before it appears '
      'on a wall.';

  // Playlists — the reader's own running orders.
  static const playlistsTitle = 'Playlists';
  static const playlistsNew = 'New playlist';
  static const playlistsSearchHint = 'Search playlist...';
  static const playlistsItemsSuffix = 'items';
  static const playlistsUpdatedPrefix = 'Updated';
  static const playlistsVideosSuffix = 'Videos';
  static const playlistsEmptyTitle = 'You have no playlist';
  static const playlistsEmptyBody =
      'Save sermons and worship into playlists to line them up and play them '
      'back to back.';
  static const playlistEditCover = 'Edit Cover Photo';
  static const playlistItemsLabel = 'Items';
  static const playlistRecommended = 'Recommended for you';
  static const playlistEmptyTitle = 'This playlist is empty';
  static const playlistEmptyBody =
      'The videos, messages, and devotionals you watch and read will show up '
      'here.';

  // What a playlist's overflow offers.
  static const playlistPlayAll = 'Play all';
  static const playlistUpdateCover = 'Update cover photo';
  static const playlistEditDetail = 'Edit playlist detail';
  static const playlistDelete = 'Delete this playlist';

  // The new/edit playlist form.
  static const playlistNewTitle = 'New playlist';
  static const playlistEditTitle = 'Edit playlist';
  static const playlistNameLabel = 'Name of the playlist';
  static const playlistNameHint = 'Encouragement for hard days';
  static const playlistVisibilityLabel = 'Playlist visibility';
  static const playlistPrivate = 'Private';
  static const playlistPublic = 'Public';
  static const playlistCreate = 'Create new playlist';
  static const playlistUpdate = 'Update';

  // Adding content to a playlist.
  static const playlistAddTitle = 'Recommended contents';
  static const playlistAddToPrefix = 'Add to';
  static const playlistAddToSuffix = 'playlist';
  static const playlistAdd = 'Add';
  static const playlistAddSelection = 'Add selection';

  // What one row inside a playlist offers.
  static const playlistItemPlay = 'Play';
  static const playlistItemRemove = 'Remove from playlist';
  static const playlistItemAdd = 'Add to this playlist';

  // Deleting one.
  static const playlistDeleteTitle = 'Delete this playlist';
  static const playlistDeleteConfirm = 'DELETE';
  static String playlistDeleteBody(String name, int items) =>
      '"$name" and its $items items will be removed from your playlists. The '
      'content itself stays on GospelTube.';

  // Giving — what the reader has sent to ministries.
  static const givingGivenThisYear = 'Given this year';
  static const givingTotalSuffix = 'total';
  static const givingGiftsSuffix = 'gifts';
  static const givingAcrossPrefix = 'Across';
  static const givingMinistriesSuffix = 'ministries';
  static const givingDownloadStatement = 'Download yearly statement';
  static const givingReceipt = 'Receipt';
  static const givingInvoice = 'Invoice';
  static const givingVoucher = 'Voucher';
  static const givingEmptyTitle = 'No givings yet';
  static const givingEmptyBody =
      'When you give to a ministry, your gifts and receipts will be kept here '
      'for your records.';

  // Subscriptions — the ministries the reader follows.
  static const followingTitle = 'Following';
  static const followingManage = 'Manage';
  static const followingSeeLatest = 'See latest content';
  static const followingSearchHint = 'Search ministries...';
  static const followingLive = 'LIVE';
  static const followingUnfollowPrefix = 'Unfollow';
  static const followingNoMatchTitle = 'No ministry matched';
  static const followingNoMatchBody =
      'Try a different name, or clear the search to see everyone you follow.';
  static const followingFillTitle = 'Follow ministries to fill this feed';
  static const followingFillBody =
      'When you subscribe to a church or creator, their newest videos, '
      'messages, and livestreams show up here, all in one place.';
  static const followingStarterTitle = 'Ministries to get you started';
  static const followingShowMore = 'Show more';

  // How much a ministry is allowed to notify.
  static const notifyAll = 'All';
  static const notifyAllBody = 'Get notified on all things';
  static const notifyPersonalized = 'Personalized';
  static const notifyPersonalizedBody =
      'Every new video, post, livestream and event';
  static const notifyLive = 'Live & events';
  static const notifyLiveBody = 'Streams and event reminders, nothing else';
  static const notifyNone = 'None';
  static const notifyNoneBody = 'Stay subscribed, no notifications';

  // The creator studio dashboard.
  static const profileOpenStudio = 'Open studio';
  static const profileOpenStudioNote = 'Your dashboard and content';

  static const studioTab = 'Studio';
  static const studioTabContent = 'Content';
  static const studioTabImpact = 'Impact';
  static const studioTabGiving = 'Giving';

  static const studioWelcomePrefix = 'Welcome,';
  static const studioReady = "Your studio is ready. Here's how to start.";
  static String studioNeedsYouCount(int n) =>
      '$n thing${n == 1 ? '' : 's'} need your attention today.';
  static const studioAllClear = 'Nothing needs you today.';

  // The Content tab.
  static const contentChipAll = 'All';
  static const contentSearchHint = 'Search your content...';
  static const contentEmptyTitle = 'Nothing shared yet';
  static const contentEmptyBody =
      'Your first sermon, song or word is the beginning of your channel. '
      'Everything you publish will live here.';
  static const contentCreate = 'Create';
  static const contentShare = 'Share content';
  static const contentEdit = 'Edit';
  static const contentProcessing = 'Processing';
  static const contentDraft = 'Draft';
  static const contentScheduled = 'Scheduled';

  /// States the API returns that the design does not draw. Left unnamed,
  /// a failed upload read as "Public · 2d".
  static const contentFailed = 'Upload failed';
  static const contentInReview = 'In review';
  static const contentBlocked = 'Blocked';
  static const contentArchived = 'Archived';
  static const contentCancelled = 'Cancelled';
  static const contentLiveNow = 'Live now';

  /// The recording a broadcast left behind — a video row pointing back at
  /// the session. It is not an upload, and it is not the session either.
  static const contentReplay = 'Replay';

  /// The broadcast itself, once it is over.
  static const contentEnded = 'Ended';
  static const contentEdited = 'edited';
  static const contentJustNow = 'just now';
  static const contentPublic = 'Public';
  static const contentUnlisted = 'Unlisted';
  static const contentPrivate = 'Private';
  static const contentViews = 'views';
  static const contentPlays = 'plays';
  static const contentReads = 'reads';
  static const contentGoing = 'going';
  static const contentWatchedLive = 'watched live';

  // Uploading a video or a piece of audio. The two are one screen; a
  // livestream is a different thing entirely and has its own.
  static const newVideoTitle = 'New video';
  static const newVideoSubtitle =
      'Share a sermon, message, or worship video with your community.';

  /// The audio design repeats the video frame's subtitle word for word,
  /// down to "worship video". On the audio screen that is simply wrong, so
  /// this names a song instead.
  static const newAudioTitle = 'New audio';
  static const newAudioSubtitle =
      'Share a sermon, message, or worship song with your community.';

  /// The ceilings are staging's own `constraints.maxSizeBytes`: 5 GB for a
  /// video ticket, 1 GB for a music one. The design says 4 GB on the video
  /// frame and repeats "MP4 or MOV, up to 4GB" on the audio frame, which
  /// names neither the right containers nor the right ceiling.
  static const newVideoPickHint = 'MP4 or MOV, up to 5GB';
  static const newAudioPickHint = 'MP3, M4A or WAV, up to 1GB';
  static const newVideoSelect = 'Select video';
  static const newAudioSelect = 'Select audio';

  static const newMediaUploading = 'Uploading';
  static const newMediaUploaded = 'Ready to publish';
  static const newMediaUploadFailed = 'Upload failed';
  static const newMediaThumbnail = 'Thumbnail';
  static const newMediaRequired = 'required';
  static const newMediaThumbnailCta = 'Upload thumbnail (1280×720)';
  static const newMediaThumbnailChange = 'Change thumbnail';
  static const newMediaTitleLabel = 'Title';
  static const newMediaTitleHint = 'e.g Walking by faith';
  static const newMediaDescriptionLabel = 'Description';
  static const newMediaDescriptionHint =
      'A message on trusting God through uncertain seasons.';
  static const newMediaCategoryLabel = 'Category';
  static const newMediaCategoryHint = 'e.g Sermons';
  static const newMediaPublish = 'Upload & publish';
  static const newMediaSaveDraft = 'Save as draft instead';

  // A calendar event. Nothing here is uploaded or transcoded; an event
  // lives in the content service, not the media one.
  static const newEventTitle = 'New event';
  static const newEventSubtitle =
      'Invite your community to a service or gathering';
  static const newEventCover = 'Cover art';
  static const newEventTitleLabel = 'Event title';
  static const newEventTitleHint = 'e.g Encounter Conference 2026';
  static const newEventType = 'Event type';
  static const newEventPhysical = 'In Person';
  static const newEventPhysicalBody = 'A physical location for the event';
  static const newEventVirtual = 'Virtual';
  static const newEventVirtualBody = 'A virtual meeting link';
  static const newEventHybrid = 'Hybrid';
  static const newEventHybridBody =
      'A combination of physical event and virtual event';
  static const newEventStartDate = 'Start Date';
  static const newEventEndDate = 'End Date';
  static const newEventNoEndDate = 'Leave blank if no end date';
  static const newEventTime = 'Time';
  static const newEventLocation = 'Location (in person)';
  static const newEventLocationHint = 'Lekki Conference Centre';

  /// The design collects one free-text venue name. Publishing needs a
  /// street address **and** a city — "Add a street address and city before
  /// publishing this event" — so both are asked for.
  static const newEventAddress = 'Street address';
  static const newEventAddressHint = 'e.g 1 Admiralty Way';
  static const newEventCity = 'City';
  static const newEventCityHint = 'e.g Lagos';

  /// The design has no field for this at all, though it offers Virtual and
  /// Hybrid — neither of which can be published without one.
  static const newEventMeetingUrl = 'Meeting link';
  static const newEventMeetingUrlHint = 'https://…';

  static const newEventRsvp = 'Allow RSVP';
  static const newEventRsvpBody =
      'Let people register interest & get reminders';
  static const newEventCapacity = 'Capacity';
  static const newEventCapacityHint = '500';
  static const newEventVisibility = 'Visibility';
  static const newEventPublish = 'Publish event';
  static const newEventLiveTitle = 'Your event is live';
  static const newEventLiveBody =
      "It's now on your channel for your community to book.";
  static const newEventDraftBody =
      "It's in your content, ready whenever you are.";

  // What can go wrong.
  static const newEventNeedsDescription =
      'Add a description before publishing this event.';
  static const newEventNeedsAddress =
      'Add a street address and city before publishing this event.';
  static const newEventNeedsMeetingUrl =
      'Add a meeting link before publishing this event.';
  static const newEventBadSchedule =
      'That end date falls before the start. Check the dates.';
  static const newEventCapacityFloor = 'Capacity has to be at least 1.';
  static const newEventCoverTooLarge = 'That image is larger than 8 MB.';

  // Writing an article. Markdown and images in the content service.
  static const newArticleTitle = 'New article';
  static const newArticleSubtitle =
      'Share an update or article with your community.';
  static const articleWrite = 'Write';
  static const articlePreview = 'Preview';
  static const articleCover = 'Cover image';
  static const articleAddCover = 'Add a cover';
  static const articleTitleHint = 'Why we still gather';

  /// The design says the headline is "optional, but it helps people find
  /// your post". The API refuses the post without one, so this says so.
  static const articleTitleNote = 'Your headline — readers find the post by it';

  static const articleBodyHint =
      'Every year our church sets aside twenty-one days before Easter.';
  static const articlePublish = 'Publish';
  static const articlePreviewNote = 'This is exactly how readers will see it';
  static const articleReadSuffix = 'min read';
  static const articleDraftBadge = 'Not published yet';
  static const articleLinkTitle = 'Link address';
  static const articleLinkHint = 'https://';

  // What each toolbar button drops when nothing is selected.
  static const articleBoldPlaceholder = 'bold text';
  static const articleItalicPlaceholder = 'italic text';
  static const articleHeadingPlaceholder = 'Heading';
  static const articleBulletPlaceholder = 'List item';
  static const articleLinkPlaceholder = 'link text';

  static const newArticleLiveTitle = 'Your article is live';
  static const newArticleLiveBody =
      "It's now on your channel for your community to read.";
  static const newArticleScheduledTitle = 'Your article is scheduled';

  // What can go wrong.
  static const articleNeedsTitle = 'Give the article a headline.';
  static const articleNeedsBody = 'Write something before publishing.';
  static const articleTitleTooLong = 'Headlines are capped at 500 characters.';

  // Going live. Not an upload: the camera pushes RTMP to Mux, and the API
  // refuses to let a livestream be created as ordinary media.
  static const goLiveTitle = 'Go Live';
  static const goLiveSubtitle = 'Go live with your community in real time.';
  static const goLiveCoverLabel = 'Live cover art';
  static const goLiveDescriptionLabel = 'Description';
  static const goLiveDescriptionHint = "What's this service about?";
  static const goLiveTitleLabel = 'Title';
  static const goLiveTitleHint = 'e.g Walking by faith';
  static const goLiveCategoryLabel = 'Category';
  static const goLiveStart = 'Go Live and notify subscribers';

  static const goLiveConnecting = 'Connecting…';
  static const goLiveConnectingBody =
      'Your stream is starting.\nStay on this screen.';
  static const goLiveLivePill = 'LIVE';
  static const goLiveEnd = 'End';
  static const goLiveNoGiving = '—';

  /// The design runs viewer chat along the foot of the broadcast. Nothing
  /// in the livestream contract carries live messages (OPEN_ISSUES 23).
  static const goLiveChatUnavailable = 'Live chat is not available yet';

  // Ending it.
  static const goLiveEndTitle = 'End your livestream';
  static const goLiveEndReplay =
      'Your recording will be saved and published as a replay automatically.';
  static const goLiveEndReplayPrivate =
      'Your recording will be saved privately.';
  static const goLiveEndReplayNone = 'No recording will be kept.';
  static const goLiveKeepStreaming = 'Keep streaming';
  static const goLiveEndStream = 'End stream';

  // What can go wrong.
  static const goLiveNeedsCamera =
      'GospelTube needs the camera and microphone to broadcast.';
  static const goLiveConflict =
      'Another broadcast is already running on this channel.';
  static const goLiveNotArmed =
      'The connection window closed. Start again to reopen it.';
  static const goLiveRejected = 'The broadcast could not start. Please retry.';

  // "When should this go live".
  static const goLiveSheetTitle = 'When should this go live';
  static const goLiveSheetSubtitle =
      'Choose when this content is visible to viewers';
  static const goLiveSheetQuestion = 'When should this go live?';
  static const goLiveNow = 'Publish now';
  static const goLiveNowBody = 'Goes live immediately';
  static const goLiveLater = 'Schedule for later';
  static const goLiveLaterBody = 'Auto-publishes at the time you pick';
  static const goLiveDate = 'Date';
  static const goLiveTime = 'Time';
  static const goLiveCancel = 'Cancel';
  static const goLiveSchedule = 'Schedule';

  /// The API refuses a schedule in the past outright.
  static const goLivePastMoment = 'Pick a date and time still to come.';

  // How it ended. The audio design reuses the video card verbatim, down to
  // "Your video is live"; each kind says its own name here.
  static const newVideoLiveTitle = 'Your video is live';
  static const newVideoLiveBody =
      "It's now on your channel for your community to watch.";
  static const newAudioLiveTitle = 'Your audio is live';
  static const newAudioLiveBody =
      "It's now on your channel for your community to listen to.";
  static const newVideoScheduledTitle = 'Your video is scheduled';
  static const newAudioScheduledTitle = 'Your audio is scheduled';
  static const newMediaDraftTitle = 'Saved as draft';
  static const newMediaDraftBody =
      "It's in your content, ready whenever you are.";
  static const newMediaDone = 'Done';

  // What can go wrong.
  static const newVideoTooLarge = 'That video is larger than 5 GB.';
  static const newAudioTooLarge = 'That track is larger than 1 GB.';
  static const newVideoBadFormat =
      "That file isn't supported. Choose an MP4 or MOV.";
  static const newAudioBadFormat =
      "That file isn't supported. Choose an MP3, M4A or WAV.";
  static const newMediaNetwork =
      'The upload could not finish. Check your connection and try again.';
  static const newMediaRejected = 'That upload was refused. Please try again.';
  static const newMediaExpired =
      'That upload expired before it was published. Choose the video again.';
  static const newMediaSchedulePast =
      'That moment has passed. Pick a time still to come.';
  static const newMediaThumbTooLarge = 'That image is larger than 10 MB.';
  static const newMediaThumbUnreadable = "That image could not be read.";
  static const newMediaNeedsFile = 'Choose a file first.';
  static const newMediaTitleTooLong = 'Titles are capped at 180 characters.';
  static const newMediaDescriptionTooLong =
      'Descriptions are capped at 5,000 characters.';
  static const newMediaCategoryMax = 'Choose up to 8 categories.';

  // One piece of content, opened from the list.
  static const contentKindVideo = 'Video';
  static const contentKindLivestream = 'Livestream';
  static const contentKindAudio = 'Audio';
  static const contentKindPost = 'Articles/Blogs';
  static const contentKindEvent = 'Events';
  static const contentPerformance = 'PERFORMANCE';
  static const contentViewContent = 'View content';
  static const contentPublished = 'Published';
  static const contentPlaysLabel = 'Plays';
  static const contentWatchedLiveLabel = 'Watched live';
  static const contentReadsLabel = 'Reads';
  static const contentLikes = 'Likes';
  static const contentComments = 'Comments';
  static const contentGoingLabel = 'Going';
  static const contentCopyLink = 'Copy link';
  static const contentEditOnWeb = 'Edit on web';
  static const contentManageOnWeb = 'Manage on web';
  static const contentWebStudioNote =
      'Title, description, visibility and series are edited on the web '
      'studio.';
  static const contentWebOnlyAction =
      'Open the web studio to edit this content.';
  static const contentNoPublicLink = 'A shareable link is not available yet.';
  static const contentAnalyticsPro = 'Detailed analytics need the Pro plan.';
  static const studioCreate = '+ Create';
  static const studioToday = 'TODAY';
  static const studioNeedsYou = 'NEEDS YOU';
  static const studioCreateCaption = 'CREATE';
  static const studioQuickUpload = 'Quick upload';
  static const studioFullAnalytics = 'Full analytics';
  static const studioWebNote =
      'Events, devotionals, promotions and your team are managed on the web '
      'studio.';

  static const studioViews = 'Views';
  static const studioSubscribers = 'Subscribers';
  static const studioGiving = 'Giving';
  static const studioNoFigure = '—';

  /// The server sends step keys without copy, so the words live here. A key
  /// it sends that is not in this map is skipped rather than shown raw.
  static const studioStepTitles = <String, String>{
    'complete_profile': 'Complete your profile',
    'publish_first_content': 'Upload your first sermon',
    'invite_team': 'Invite your team',
    'setup_giving': 'Set up giving',
    'go_live': 'Go live on Sunday',
  };
  static const studioStepBodies = <String, String>{
    'complete_profile': 'A photo, a banner and a line about you',
    'publish_first_content': 'Video or audio, from your phone',
    'invite_team': 'Add leaders and give them roles',
    'setup_giving': 'Verify and connect your bank',
    'go_live': 'Straight from your camera',
  };

  /// Likewise for the "needs you" rows.
  static const studioAttentionTitles = <String, String>{
    'prayer_requests': 'Prayer request',
    'prayers': 'Prayer request',
    'testimonies': 'Testimonies',
    'comments': 'Comments',
  };
  static String studioAttentionNew(int n) => '$n New';
  static String studioAttentionWaiting(int n) => '$n waiting';

  // The studio switcher.
  static const studiosSheetTitle = 'YOUR STUDIOS';
  static const studiosPersonal = 'Personal';
  static const studiosSwitch = 'Switch studio';
  static const studiosSwitchNote = 'Work in another ministry you belong to';
  static const studiosNotImplemented =
      "Switching studios isn't yet implemented";
  static const studiosSettings = 'Studio Settings';
  static const studiosSettingsNote = 'Settings are managed on the web';
  static const studiosBackToWatching = 'Back to watching';
  static const studiosBackToWatchingNote = 'Return to your feed';

  // The "+ Create" sheet.
  static const createSheetTitle = 'WHAT ARE YOU SHARING';
  static const createLivestream = 'Livestream';
  static const createLivestreamBody =
      'Go live now or set up an upcoming stream.';
  static const createVideo = 'Video';
  static const createVideoBody = 'Upload a sermon, message, or worship video.';
  static const createAudio = 'Audio';
  static const createAudioBody = 'Upload a sermon audio, song, or podcast';
  static const createEvent = 'Event';
  static const createEventBody = 'Schedule a service or gathering with RSVP.';
  static const createBlog = 'Blog Post';
  static const createBlogBody =
      'A written update — announcements, short teachings';

  // History — what the reader has watched and read.
  static const historyTitle = 'History';
  static const historyClearAll = 'Clear all';
  static const historySearchHint = 'Search history...';
  static const historyResume = 'Continue watching';
  static const historyEmptyTitle = 'Nothing here yet';
  static const historyEmptyBody =
      'The videos, messages, and devotionals you watch and read will show '
      'up here.';
  static const historyNoMatchTitle = 'Nothing matched';
  static const historyNoMatchBody =
      'Try a different word, or clear the search to see everything.';
  static const historyClearTitle = 'Clear your history?';
  static const historyClearBody =
      'This removes everything you have watched and read. It cannot be '
      'undone.';
  static const historyClearConfirm = 'Clear all';

  // You — the reader's own profile and its menu.
  static const profileAccountInfo = 'Account info';
  static const profileContinueWatching = 'CONTINUE WATCHING';
  static const profileStudio = 'STUDIO';
  static const profileYou = 'YOU';
  static const profileAccount = 'ACCOUNT';
  static const profileBecomeCreator = 'Become a creator';
  static const profileStartChannel = 'Start your channel';
  static const profileStreamerTag = 'Streamer';
  static const profileHistory = 'History';
  static const profilePlaylist = 'Playlist';
  static const profileLiked = 'Liked';
  static const profileSaved = 'Saved';
  static const profileMyEvents = 'My events';
  static const profilePrayerRequests = 'My prayer requests';
  static const profileTestimonies = 'My testimonies';
  static const profileGiving = 'My giving';
  static const profileSettings = 'Settings';
  static const profileSignOut = 'Sign out';
  static const profileSignOutTitle = 'Sign out?';
  static const profileSignOutBody =
      'You will need to sign in again to follow, save or go live.';
  static const profileRemainingSuffix = 'remaining';
  static const profileUpcomingSuffix = 'Upcoming';

  // Search — the three states of the Explore search field.
  static const searchFieldHint = 'Search...';
  static const searchRecent = 'RECENT';
  static const searchClearRecent = 'clear';
  static const searchBrowse = 'BROWSE';
  static const searchGroupMinistries = 'MINISTRIES';
  static const searchGroupVideos = 'VIDEOS';
  static const searchGroupAudio = 'AUDIO';
  static const searchGroupDevotionals = 'DEVOTIONALS';
  static const searchGroupBlogs = 'BLOGS';
  static const searchGroupSeries = 'SERIES';
  static const searchGroupEvents = 'EVENTS';
  static const searchFollow = 'Follow';
  static const searchFollowing = 'Following';
  static const searchRsvp = 'RSVP';
  static const searchKindVideo = 'Video';
  static const searchKindAudio = 'Audio';
  static const searchKindDevotional = 'Devotional';
  static const searchKindBlog = 'Blog';
  static const searchKindSeries = 'Series';
  static const searchViewsSuffix = 'views';

  // Explore tab — section headers and the copy on its hero.
  static const exploreSearchHint = 'Search ministries, sermon, series...';
  static const exploreLive = 'Live';
  static const exploreContinueWatching = 'Continue watching';
  static const exploreTrendingToday = 'Trending today';
  static const exploreDevotionals = 'Devotionals';
  static const exploreArticles = 'Articles this week';
  static const exploreMinistries = 'Ministries to follow';
  static const exploreUpcomingEvent = 'Upcoming event';
  static const exploreBrowse = 'Browse';
  static const exploreWatch = 'Watch';
  static const exploreAddToPlaylist = 'Add to playlist';
  static const exploreSponsored = 'Sponsored';
  static const exploreLiveBadge = 'LIVE';
  static const exploreSubscribers = 'Subscribers';

  static const tabFollowing = 'Following';
  static const tabLive = 'Live';
  static const topicAll = 'All';
  static const editTopics = 'Edit topics';
  static const feedErrorTitle = "That didn't load";
  static const feedErrorBody =
      'Something went wrong on our side. Give it another try.';
  static const offlineTitle = "You're offline";
  static const offlineBody =
      'Check your connection and try again — your feed is waiting.';

  static const feedEmptyTitle = 'Nothing here yet';
  static const feedEmptyBody =
      'New messages, worship and live services will\nshow up here.';
  static const followingEmptyTitle = "You're not following anyone yet";
  static const followingEmptyBody =
      'Follow ministries and their latest videos, posts and livestreams show '
      'up here.';
  static const ministriesToFollow = 'Ministries to follow';
  static const alreadyKnowWhatYouLike = 'Already know what you like? ';
  static const editYourTopics = 'Edit your topics';

  static const liveEmptyTitle = "No one's live right now";
  static const liveEmptyBody =
      "Live services will appear here. Here's what's coming up";
  static const upcomingEvents = 'Upcoming events';

  static const feedFollowingGuestTitle = 'Follow your favourites';
  static const feedFollowingGuestBody =
      'Create an account to follow creators and build\nyour own feed.';
  static const feedRetry = 'Try again';

  static const addVideos = 'Add Video';
  static const noVideosTitle = 'No videos found';
  static const noVideosSubtitle =
      'No video files were found.\nTap + to open a specific file.';

  static const scanningVideos = 'Scanning for videos…';

  static const permissionTitle = 'Media Access Required';
  static const permissionBody =
      'Allow GTube to scan your device for video files,\njust like VLC or MX Player.';
  static const permissionDeniedBody =
      'Permission was denied. Open Settings to enable\nmedia access for GTube.';
  static const grantAccess = 'Grant Access';
  static const openSettings = 'Open Settings';

  static const loadingVideo = 'Loading video…';
  static const failedToLoad = 'Failed to load video';
  static const streamNotLive = 'Stream is not live yet';
  static const streamNotLiveDesc =
      'The stream hasn\'t started. Try again in a moment.';
  static const goBack = 'Go Back';
  static const subscribersLabel = 'Subscribers';

  /// An event's location, and getting there.
  static const eventDirections = 'Directions';
  static const eventJoinOnline = 'Join online';
  static const eventNoMapApp = 'No map app could open that address';

  /// Swiping into the short-video feed from a video or a ministry's library.
  static const watchInFeed = 'Swipe feed';
  static const watchLibraryInFeed = 'Play as feed';

  /// The player's settings sheet.
  static const playbackSpeed = 'Playback speed';
  static const videoQuality = 'Quality';
  static const speedNormal = 'Normal';

  /// Manage following — what a ministry was last doing.
  static const followingLiveNow = 'Live now';
  static const followingNoPostsYet = 'No posts yet';
  static String followingPostedAgo(String ago) => 'Posted $ago ago';
  static const followingLoadFailed = "Couldn't load who you follow";
  static const followingUnfollowFailed = "Couldn't unfollow — try again";
  static const followingNotifyFailed = "Couldn't save that — try again";
  static const tooltipVolume = 'Volume';
  static const tooltipFullscreen = 'Fullscreen (F)';
  static const tooltipExitFullscreen = 'Exit fullscreen (F)';

  static const landingSubtitle = 'Choose how to watch';
  static const featureGallery = 'My Videos';
  static const featureGalleryDesc = 'Browse videos stored on your device';
  static const featureStartLiveDesc = 'Stream your camera live via Mux';
  static const featureJoinLiveDesc = 'Watch an ongoing Mux livestream';

  static const signIn = 'Sign In';
  static const createAccount = 'Create Account';
  static const email = 'Email';
  static const password = 'Password';

  static const cameraPermNeeded = 'Camera & Microphone Access Required';
  static const cameraPermBody =
      'GTube needs camera and microphone access\nto stream live video.';
  static const cameraPermDeniedBody =
      'Camera access was denied. Open Settings to\nenable camera for GTube.';
  static const creatingStream = 'Creating stream…';
  static const goLive = 'Go Live';
  static const rtmpUrl = 'RTMP URL';
  static const streamKey = 'Stream Key';
  static const streamId = 'Stream ID';
  static const playbackUrl = 'Playback URL';
  static const watchStream = 'Watch Your Stream';
  static const endStream = 'End Stream';
  static const copied = 'Copied!';
  static const startStreaming = 'Start Streaming';
  static const stopStreaming = 'Stop Streaming';
  static const endingStream = 'Ending stream…';
  static const streamStatus = 'Stream Status';
  static const statusIdle = 'Idle';
  static const statusActive = 'Active';
  static const showStreamKey = 'Show';
  static const hideStreamKey = 'Hide';

  static const joinStream = 'Join Stream';
  static const streamIdHint = 'Enter Creator ID…';
  static const streamIdInvalid = 'Please enter a Creator ID';
  static const notLiveError = 'This creator is not live right now';
  static const fetchingUrl = 'Fetching…';
  static const noMediaIdError = 'Stream not ready — playback token unavailable';

  static const discover = 'Discover';
  static const featureDiscoverDesc = 'Browse videos, music and live content';
  static const watchNow = 'Watch Now';

  static const shortVideos = 'Short Videos';
  static const featureShortVideosDesc = 'Full-screen vertical video feed';

  /// The You tab before anyone has signed in.
  static const authWallTitle = 'Watch. Follow. Create.';
  static const authWallSubtitle =
      'Sign in to follow your favourite creators,\nsave content, and broadcast live.';
  static const authWallFollow = 'Follow creators you love';
  static const authWallSave = 'Save videos to your library';
  static const authWallRecommend = 'Personalised recommendations';
  static const authWallGoLive = 'Go live and stream your content';

  static String filesCount(int n) => '$n file${n == 1 ? '' : 's'}';
}
