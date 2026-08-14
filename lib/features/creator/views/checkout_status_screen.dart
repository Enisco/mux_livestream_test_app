import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/mobile_checkout_repo.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/pending_checkout_store.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Watches a checkout attempt to its conclusion.
///
/// The creator pays in a system browser, so this screen has no way to observe
/// the payment itself. It polls the canonical session instead, and treats
/// nothing as complete until the server reports both `succeeded` and
/// entitlements in place.
class CheckoutStatusScreen extends StatefulWidget {
  const CheckoutStatusScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  State<CheckoutStatusScreen> createState() => _CheckoutStatusScreenState();
}

class _CheckoutStatusScreenState extends State<CheckoutStatusScreen>
    with WidgetsBindingObserver {
  /// Backoff between reads. The webhook usually lands inside a few seconds; the
  /// tail is there so a slow one is not reported as a failure.
  static const _delays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 8),
    Duration(seconds: 13),
  ];

  final _repo = MobileCheckoutRepo();
  final _store = PendingCheckoutStore();

  MobileCheckoutSession? _session;
  bool _polling = false;
  bool _exhausted = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _begin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The return link is not guaranteed — a creator can dismiss the browser by
  /// hand — so coming back to the app is itself a reason to re-read.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _begin();
  }

  Future<void> _begin() async {
    if (_polling) return;
    final id = widget.sessionId ?? _sessionId ?? await _store.sessionId;
    if (id == null || id.isEmpty) {
      if (mounted) setState(() => _exhausted = true);
      return;
    }
    _sessionId = id;
    await _poll(id);
  }

  Future<void> _poll(String id) async {
    setState(() {
      _polling = true;
      _exhausted = false;
    });

    for (final delay in _delays) {
      if (!mounted) return;
      try {
        final session = await _repo.fetchSession(id);
        if (!mounted) return;
        setState(() => _session = session);
        if (session.isSettled || session.isTerminal) {
          await _finish(session);
          return;
        }
      } catch (e) {
        logger.w('Checkout status read failed', error: e);
      }
      await Future<void>.delayed(delay);
    }

    if (!mounted) return;
    setState(() {
      _polling = false;
      _exhausted = true;
    });
  }

  Future<void> _finish(MobileCheckoutSession session) async {
    if (session.isTerminal) await _store.clear();
    if (mounted) setState(() => _polling = false);
  }

  Future<void> _dismiss() async {
    await _store.clear();
    if (mounted) context.go(AppRouter.home);
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_polling)
                  const CircularProgressIndicator(
                    color: AppColors.brandPrimary,
                  ),
                if (_polling) const SizedBox(height: 24),
                Text(
                  AppStrings.checkoutTitle,
                  style: AppStyles.heading(20, letterSpacing: -0.8),
                ),
                const SizedBox(height: 12),
                Text(
                  _message,
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
    );
  }

  String get _message {
    if (_polling) return AppStrings.checkoutConfirming;
    final session = _session;
    if (session == null) return AppStrings.checkoutInBrowser;
    if (session.isSettled) return AppStrings.checkoutConfirmed;
    return switch (session.status) {
      MobileCheckoutStatus.failed => AppStrings.checkoutFailed,
      MobileCheckoutStatus.canceled => AppStrings.checkoutCanceled,
      MobileCheckoutStatus.expired => AppStrings.checkoutExpired,
      MobileCheckoutStatus.succeeded => AppStrings.checkoutPending,
      MobileCheckoutStatus.processing => AppStrings.checkoutStillProcessing,
      _ => AppStrings.checkoutInBrowser,
    };
  }

  List<Widget> _actions() {
    if (_polling) return const [];
    final settled = _session?.isSettled ?? false;
    return [
      PrimaryButton(
        label: settled ? AppStrings.continueLabel : AppStrings.checkAgain,
        height: 54,
        onPressed: settled ? _dismiss : _begin,
      ),
      if (!settled) const SizedBox(height: 12),
      if (!settled)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismiss,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              AppStrings.notNow,
              style: AppStyles.body(14, color: AppColors.brandPrimary),
            ),
          ),
        ),
      if (_exhausted) const SizedBox(height: 8),
    ];
  }
}
