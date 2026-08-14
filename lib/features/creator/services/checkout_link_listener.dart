import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/shared/services/pending_checkout_store.dart';

/// Catches the checkout return link and hands off to the status screen.
///
/// The link is navigation only. It proves nothing about the payment — the
/// session id is matched against the attempt this device actually started, and
/// everything else comes from an authenticated read on the status screen.
class CheckoutLinkWatcher extends StatefulWidget {
  const CheckoutLinkWatcher({super.key, required this.child, this.store});

  static const returnPath = '/mobile/payments/return';

  final Widget child;
  final PendingCheckoutStore? store;

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

    final pending = await _store.sessionId;
    if (pending == null || pending != incoming) {
      // Somebody else's link, or a stale one. Never act on it.
      logger.w('Ignoring checkout return for an unknown session');
      return;
    }

    // Dismissing the browser is cosmetic, and the call never completes when
    // there is none open — so it must not gate the handoff.
    unawaited(closeInAppWebView().catchError((Object _) {}));

    appRouter.push(AppRouter.checkoutStatus, extra: incoming);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
