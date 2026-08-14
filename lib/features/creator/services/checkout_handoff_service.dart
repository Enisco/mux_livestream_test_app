import 'dart:ui' show PlatformDispatcher;

import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/mobile_checkout_repo.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/services/pending_checkout_store.dart';

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

/// Starts the mobile→web subscription handoff.
///
/// The app's only job is to create the durable session and open the launch URL
/// in a system browser. Plan, provider and payment all live on the web surface,
/// and the outcome is read back from the session — never from the browser.
class CheckoutHandoffService {
  CheckoutHandoffService({
    MobileCheckoutRepo? repo,
    PendingCheckoutStore? store,
    UrlOpener? opener,
  }) : _repo = repo ?? MobileCheckoutRepo(),
       _store = store ?? PendingCheckoutStore(),
       _open = opener ?? _openInSystemBrowser;

  static const _uuid = Uuid();

  final MobileCheckoutRepo _repo;
  final PendingCheckoutStore _store;
  final UrlOpener _open;

  /// SFSafariViewController on iOS, a Chrome Custom Tab on Android. Never a
  /// WebView: the guide forbids it and the PSPs require a real browser.
  static Future<bool> _openInSystemBrowser(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.inAppBrowserView);

  /// TODO(payments): confirm with the backend what `storefrontCountry` should
  /// be. Apple's storefront is alpha-3 and Play's is separate again, so device
  /// region is a stand-in until then.
  static String resolveStorefrontCountry() {
    final code = PlatformDispatcher.instance.locale.countryCode;
    if (code != null && RegExp(r'^[A-Za-z]{2}$').hasMatch(code)) {
      return code.toUpperCase();
    }
    return 'US';
  }

  static String newAttemptKey(String creatorId) =>
      'subscription:creator:$creatorId:attempt:${_uuid.v4()}';

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
