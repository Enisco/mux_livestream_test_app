import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/mobile_checkout_repo.dart';
import 'package:test_app/features/creator/services/checkout_handoff_service.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/components/busy_barrier.dart';
import 'package:test_app/shared/services/pending_giving_store.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Watches a gift to its conclusion.
///
/// The giver pays in a system browser, so this screen cannot observe the
/// payment. It polls the canonical session and believes nothing else — not the
/// return link, not a provider's query parameters, not the fact that the
/// browser closed.
///
/// Two things it says carefully:
///
/// - **"Your gift has gone through" is not "the ministry has the money."**
///   `succeeded` is the payment; settlement to the ministry follows on its own
///   schedule and, on a provider-held rail, after a hold window. The giver is
///   thanked for the gift, and no transfer is claimed.
/// - **An unfinished gift is not a failed one.** A session the giver walked
///   away from can still be paid, so it offers the browser back rather than
///   reporting a failure that has not happened.
class GivingStatusScreen extends StatefulWidget {
  const GivingStatusScreen({super.key, this.sessionId, this.repo, this.store});

  final String? sessionId;
  final MobileCheckoutRepo? repo;

  /// Defaults to the real thing; a test supplies its own, because secure
  /// storage has no platform channel in one.
  final PendingGivingStore? store;

  @override
  State<GivingStatusScreen> createState() => _GivingStatusScreenState();
}

class _GivingStatusScreenState extends State<GivingStatusScreen>
    with WidgetsBindingObserver {
  /// The guide's own schedule: immediately, then 2, 5, 10 and 15 seconds,
  /// capped at roughly two minutes. A gift's webhook is usually in within
  /// seconds; the long tail is there so a slow one is not called a failure.
  static const _delays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 15),
    Duration(seconds: 15),
    Duration(seconds: 15),
    Duration(seconds: 15),
    Duration(seconds: 15),
    Duration(seconds: 15),
  ];

  late final MobileCheckoutRepo _repo = widget.repo ?? MobileCheckoutRepo();
  late final PendingGivingStore _store = widget.store ?? PendingGivingStore();

  MobileCheckoutSession? _session;
  bool _polling = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_begin());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The return link is not guaranteed — the giver can dismiss the browser by
  /// hand — so coming back to the app is itself a reason to re-read.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_begin());
  }

  Future<void> _begin() async {
    if (_polling) return;
    final id = widget.sessionId ?? _sessionId;
    if (id == null || id.isEmpty) return;
    _sessionId = id;
    await _poll(id);
  }

  Future<void> _poll(String id) async {
    if (!mounted) return;
    setState(() => _polling = true);

    for (final delay in [Duration.zero, ..._delays]) {
      if (!mounted) return;
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (!mounted) return;
      try {
        final session = await _repo.fetchSession(id);
        if (!mounted) return;
        setState(() => _session = session);
        if (session.isSettled || session.isTerminal) {
          // Nothing more will change, so the id is no longer worth matching a
          // return link against.
          await _store.forget(id);
          if (mounted) setState(() => _polling = false);
          return;
        }
      } catch (e) {
        logger.w('Gift status read failed', error: e);
      }
    }

    if (mounted) setState(() => _polling = false);
  }

  Future<void> _resume() async {
    final id = _sessionId;
    if (id == null) return;
    // A fresh ticket is a round trip before the browser opens, and this
    // button is the one thing on the screen: without a barrier it reads as
    // a tap that did nothing.
    await runBusy(
      context,
      () => getIt<CheckoutHandoffService>().resumeGiving(id),
      message: AppStrings.giveOpening,
    );
  }

  Future<void> _dismiss() async {
    final id = _sessionId;
    final settled = _session?.isSettled ?? false;
    // Leaving an unfinished gift abandons the attempt. A session whose
    // payment already started stays processing on the server regardless, so
    // this cannot turn a real payment into a cancellation.
    if (id != null && !settled && !(_session?.isTerminal ?? false)) {
      // Cancelling is a round trip too, and the barrier also keeps a second
      // tap from firing a second cancel and a second pop.
      await runBusy(
        context,
        () => getIt<CheckoutHandoffService>().cancelGiving(id),
        message: AppStrings.givingWorking,
      );
    } else if (id != null) {
      await _store.forget(id);
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.brandSecondary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_polling) ...[
                      const CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      AppStrings.giftStatusTitle,
                      style: AppStyles.heading(20, letterSpacing: -0.8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _message,
                      key: const ValueKey('giving-status-message'),
                      textAlign: TextAlign.center,
                      style: AppStyles.body(14, color: AppColors.neutral300),
                    ),
                    const SizedBox(height: 32),
                    ..._actions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _message {
    if (_polling) return AppStrings.giftConfirming;
    final session = _session;
    if (session == null) return AppStrings.giftInBrowser;
    if (session.isSettled) {
      // The server formats the money; the app prints what it is handed and
      // falls back to thanking without a figure rather than composing one.
      final amount = session.giving?.chargeLabel;
      return amount == null || amount.isEmpty
          ? AppStrings.giftConfirmed
          : AppStrings.giftConfirmedAmount(amount);
    }
    return switch (session.status) {
      MobileCheckoutStatus.failed => AppStrings.giftDeclined,
      MobileCheckoutStatus.canceled => AppStrings.giftCanceled,
      MobileCheckoutStatus.expired => AppStrings.giftExpired,
      MobileCheckoutStatus.processing => AppStrings.giftPending,
      _ => AppStrings.giftInBrowser,
    };
  }

  List<Widget> _actions() {
    if (_polling) return const [];
    final session = _session;
    final settled = session?.isSettled ?? false;
    final terminal = session?.isTerminal ?? false;

    // Only a gift that is neither finished nor dead can be carried on with.
    final resumable = !settled && !terminal;

    return [
      PrimaryButton(
        key: const ValueKey('giving-status-primary'),
        label: settled || terminal
            ? AppStrings.giftDone
            : AppStrings.giftResume,
        height: 54,
        onPressed: settled || terminal
            ? () => unawaited(_dismiss())
            : () => unawaited(_resume()),
      ),
      if (!settled) ...[
        const SizedBox(height: 12),
        GestureDetector(
          key: const ValueKey('giving-status-secondary'),
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(resumable ? _dismiss() : _begin()),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              resumable ? AppStrings.notNow : AppStrings.checkAgain,
              style: AppStyles.body(14, color: AppColors.brandPrimary),
            ),
          ),
        ),
      ],
    ];
  }
}
