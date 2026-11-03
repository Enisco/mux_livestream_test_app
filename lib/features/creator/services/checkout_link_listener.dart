import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/shared/services/pending_checkout_store.dart';
import 'package:test_app/shared/services/pending_giving_store.dart';

/// Catches the checkout return link and hands off to the right status screen.
///
/// The link is navigation only. It proves nothing about the payment — the
/// session id is matched against an attempt this device actually started, and
/// everything else comes from an authenticated read on the status screen.
///
/// One path serves both products, so the id decides which: a subscription has
/// exactly one live attempt, a gift may be one of several. Matching the gift
/// list *after* the subscription slot keeps the common case a single read.
class CheckoutLinkWatcher extends StatefulWidget {
  const CheckoutLinkWatcher({
    super.key,
    required this.child,
    this.store,
    this.givingStore,
  });

  static const returnPath = '/mobile/payments/return';

  final Widget child;
  final PendingCheckoutStore? store;
  final PendingGivingStore? givingStore;

  /// The session id carried by [uri], or null when this is not a checkout
  /// return. Kept pure so the matching rules are testable.
  @visibleForTesting
  static String? sessionIdFrom(Uri uri) {
    if (uri.scheme != 'https') return null;
    if (uri.path != returnPath) return null;
    final id = uri.queryParameters['session'];
    return (id == null || id.isEmpty) ? null : id;
  }

  @override
  State<CheckoutLinkWatcher> createState() => _CheckoutLinkWatcherState();
}

class _CheckoutLinkWatcherState extends State<CheckoutLinkWatcher> {
  late final PendingCheckoutStore _store =
      widget.store ?? PendingCheckoutStore();
  late final PendingGivingStore _givingStore =
      widget.givingStore ?? PendingGivingStore();
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    // uriLinkStream replays the launch link, so a cold start is covered too.
    _subscription = AppLinks().uriLinkStream.listen(
      _handle,
      onError: (Object e) => logger.w('App link stream error', error: e),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handle(Uri uri) async {
    final incoming = CheckoutLinkWatcher.sessionIdFrom(uri);
    if (incoming == null) return;

    final route = await _routeFor(incoming);
    if (route == null) {
      // Somebody else's link, or a stale one. Never act on it.
      logger.w('Ignoring checkout return for an unknown session');
      return;
    }

    // Dismissing the browser is cosmetic, and the call never completes when
    // there is none open — so it must not gate the handoff.
    unawaited(closeInAppWebView().catchError((Object _) {}));

    appRouter.push(route, extra: incoming);
  }

  /// Which status screen this return belongs to, or null when the id matches
  /// nothing this device started.
  Future<String?> _routeFor(String sessionId) async {
    if (await _store.sessionId == sessionId) return AppRouter.checkoutStatus;
    if (await _givingStore.has(sessionId)) return AppRouter.givingStatus;
    return null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
