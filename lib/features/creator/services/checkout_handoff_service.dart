import 'dart:ui' show PlatformDispatcher;

import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/mobile_checkout_repo.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/services/pending_checkout_store.dart';
import 'package:test_app/shared/services/pending_giving_store.dart';

/// Opens a URL outside the app. Injected so tests never touch the plugin.
typedef UrlOpener = Future<bool> Function(Uri uri);

enum HandoffOutcome {
  /// The web checkout is open. Nothing is decided yet — reconcile on return.
  launched,

  /// The storefront may not sell this product. Hide the purchase action.
  unavailable,

  /// A previous attempt is still live and could not be resumed.
  alreadyActive,

  failed,
}

class HandoffResult {
  const HandoffResult(this.outcome, {this.sessionId, this.reason});

  final HandoffOutcome outcome;
  final String? sessionId;
  final String? reason;
}

/// Starts the mobile→web handoff, for a subscription or for a gift.
class CheckoutHandoffService {
  CheckoutHandoffService({
    MobileCheckoutRepo? repo,
    PendingCheckoutStore? store,
    PendingGivingStore? givingStore,
    UrlOpener? opener,
  }) : _repo = repo ?? MobileCheckoutRepo(),
       _store = store ?? PendingCheckoutStore(),
       _givingStore = givingStore ?? PendingGivingStore(),
       _open = opener ?? _openInSystemBrowser;

  static const _uuid = Uuid();

  final MobileCheckoutRepo _repo;
  final PendingCheckoutStore _store;
  final PendingGivingStore _givingStore;
  final UrlOpener _open;

  /// SFSafariViewController on iOS, a Chrome Custom Tab on Android. Never a
  /// WebView: the guide forbids it and the PSPs require a real browser.
  static Future<bool> _openInSystemBrowser(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.inAppBrowserView);

  /// ISO 3166-1 **alpha-2**, as the guide's `storefrontCountry=NG` examples
  /// show. Taken from the device region, which is the closest thing the app
  /// has to a storefront without querying the store itself.
  static String resolveStorefrontCountry() {
    final code = PlatformDispatcher.instance.locale.countryCode;
    if (code != null && RegExp(r'^[A-Za-z]{2}$').hasMatch(code)) {
      return code.toUpperCase();
    }
    return 'US';
  }

  static String newAttemptKey(String creatorId) =>
      'subscription:creator:$creatorId:attempt:${_uuid.v4()}';

  /// A fresh key for every gift. Two gifts to the same ministry are two
  /// separate intentions, and sharing a key would make the second one resume
  /// the first.
  static String newGivingKey(String creatorId) =>
      'giving:creator:$creatorId:attempt:${_uuid.v4()}';

  /// Whether this storefront may sell a subscription at all.
  Future<bool> canPurchaseSubscription() async {
    try {
      final caps = await _repo.fetchCapabilities(
        storefrontCountry: resolveStorefrontCountry(),
      );
      return caps.subscriptionAvailable;
    } catch (e) {
      logger.w('Capabilities check failed', error: e);
      return false;
    }
  }

  /// Whether this storefront may take gifts at all.
  Future<bool> canGive() async {
    try {
      final caps = await _repo.fetchCapabilities(
        storefrontCountry: resolveStorefrontCountry(),
      );
      return caps.givingAvailable;
    } catch (e) {
      logger.w('Capabilities check failed', error: e);
      return false;
    }
  }

  /// Creates the durable session and opens it in a system browser.
  Future<HandoffResult> start({
    required String creatorId,
    String? planTier,
  }) async {
    final storefront = resolveStorefrontCountry();

    try {
      final caps = await _repo.fetchCapabilities(storefrontCountry: storefront);
      if (!caps.subscriptionAvailable) {
        logger.w('Subscriptions unavailable: ${caps.subscriptionReason}');
        return HandoffResult(
          HandoffOutcome.unavailable,
          reason: caps.subscriptionReason,
        );
      }
    } catch (e) {
      logger.e('Capabilities check failed', error: e);
      return const HandoffResult(HandoffOutcome.failed);
    }

    // Reuse the stored key so a retry resumes rather than colliding with 409.
    final attemptKey = await _store.attemptKey ?? newAttemptKey(creatorId);

    try {
      final handoff = await _repo.createSession(
        creatorId: creatorId,
        storefrontCountry: storefront,
        idempotencyKey: attemptKey,
      );
      await _store.save(
        sessionId: handoff.session.id,
        attemptKey: attemptKey,
        planTier: planTier,
      );
      return _launch(handoff.session.id, handoff.launch);
    } on CheckoutAlreadyActive catch (e) {
      return _resume(e.sessionId, attemptKey, planTier);
    } catch (e) {
      logger.e('Could not create checkout session', error: e);
      return const HandoffResult(HandoffOutcome.failed);
    }
  }

  /// Creates a giving session and opens it in a system browser.
  Future<HandoffResult> startGiving({
    required String creatorId,
    String? fundSlug,
    String? sourceMediaId,
  }) async {
    if (creatorId.isEmpty) return const HandoffResult(HandoffOutcome.failed);
    final storefront = resolveStorefrontCountry();

    try {
      final caps = await _repo.fetchCapabilities(storefrontCountry: storefront);
      if (!caps.givingAvailable) {
        logger.w('Giving unavailable: ${caps.givingReason}');
        return HandoffResult(
          HandoffOutcome.unavailable,
          reason: caps.givingReason,
        );
      }
    } catch (e) {
      logger.e('Capabilities check failed', error: e);
      return const HandoffResult(HandoffOutcome.failed);
    }

    final attemptKey = newGivingKey(creatorId);
    try {
      return await _createAndLaunchGift(
        creatorId: creatorId,
        storefront: storefront,
        attemptKey: attemptKey,
        fundSlug: fundSlug,
        sourceMediaId: sourceMediaId,
      );
    } on GivingSourceRejected {
      // The content could not carry the gift. The ministry still can.
      logger.w('Giving source media refused; offering the gift unattributed');
      try {
        return await _createAndLaunchGift(
          creatorId: creatorId,
          storefront: storefront,
          attemptKey: attemptKey,
          fundSlug: fundSlug,
          sourceMediaId: null,
        );
      } catch (e) {
        logger.e('Could not create giving session', error: e);
        return const HandoffResult(HandoffOutcome.failed);
      }
    } on GivingUnavailable {
      // Cached capability said yes and the server now says no — a rail paused
      // between the two.
      return const HandoffResult(HandoffOutcome.unavailable);
    } catch (e) {
      logger.e('Could not create giving session', error: e);
      return const HandoffResult(HandoffOutcome.failed);
    }
  }

  Future<HandoffResult> _createAndLaunchGift({
    required String creatorId,
    required String storefront,
    required String attemptKey,
    required String? fundSlug,
    required String? sourceMediaId,
  }) async {
    final handoff = await _repo.createSession(
      creatorId: creatorId,
      storefrontCountry: storefront,
      idempotencyKey: attemptKey,
      purpose: MobileCheckoutRepo.givingPurpose,
      preferredFundSlug: fundSlug,
      sourceMediaId: sourceMediaId,
    );
    // Remembered before the browser opens: the return link can arrive while
    // this app is backgrounded, and an id written afterwards may not be
    // there in time to recognise it.
    await _givingStore.remember(handoff.session.id);
    return _launch(handoff.session.id, handoff.launch);
  }

  /// Mints a fresh ticket for a gift already under way and reopens it.
  Future<HandoffResult> resumeGiving(String sessionId) async {
    try {
      return await _launch(sessionId, await _repo.relaunch(sessionId));
    } catch (e) {
      logger.e('Could not resume the gift', error: e);
      return HandoffResult(HandoffOutcome.failed, sessionId: sessionId);
    }
  }

  /// Abandons a gift the giver walked away from.
  Future<void> cancelGiving(String sessionId) async {
    try {
      await _repo.cancel(sessionId);
    } catch (e) {
      logger.w('Could not cancel the gift', error: e);
    } finally {
      await _givingStore.forget(sessionId);
    }
  }

  /// Picks up a session the server says is already live.
  Future<HandoffResult> _resume(
    String? sessionId,
    String attemptKey,
    String? planTier,
  ) async {
    if (sessionId == null) {
      return const HandoffResult(HandoffOutcome.alreadyActive);
    }
    await _store.save(
      sessionId: sessionId,
      attemptKey: attemptKey,
      planTier: planTier,
    );
    try {
      final session = await _repo.fetchSession(sessionId);
      // A started PSP checkout cannot be relaunched; let the caller poll it.
      if (session.status == MobileCheckoutStatus.processing) {
        return HandoffResult(
          HandoffOutcome.alreadyActive,
          sessionId: sessionId,
        );
      }
      return _launch(sessionId, await _repo.relaunch(sessionId));
    } catch (e) {
      logger.e('Could not resume checkout session', error: e);
      return HandoffResult(HandoffOutcome.alreadyActive, sessionId: sessionId);
    }
  }

  Future<HandoffResult> _launch(
    String sessionId,
    MobileCheckoutLaunch launch,
  ) async {
    if (!launch.isUsable) {
      logger.w('Launch ticket missing or already expired');
      return HandoffResult(HandoffOutcome.failed, sessionId: sessionId);
    }
    final uri = Uri.tryParse(launch.launchUrl);
    if (uri == null) {
      return HandoffResult(HandoffOutcome.failed, sessionId: sessionId);
    }
    try {
      final opened = await _open(uri);
      return HandoffResult(
        opened ? HandoffOutcome.launched : HandoffOutcome.failed,
        sessionId: sessionId,
      );
    } catch (e) {
      logger.e('Could not open the checkout browser', error: e);
      return HandoffResult(HandoffOutcome.failed, sessionId: sessionId);
    }
  }
}
