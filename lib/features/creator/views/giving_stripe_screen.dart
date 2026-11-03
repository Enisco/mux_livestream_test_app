import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/giving_repo.dart';
import 'package:test_app/features/creator/views/widgets/giving_parts.dart';
import 'package:test_app/features/creator/views/widgets/giving_sheets.dart';
import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/web_app_origin.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Opens a URL outside the app. Injected so tests never reach the plugin.
typedef StripeLauncher = Future<bool> Function(Uri uri);

/// Stripe's hosted onboarding, which is the one provider setup that really
/// does happen somewhere else.
///
/// Section 7 of the integration guide: *"GospelTube does not collect
/// identity documents, beneficial-owner details, or bank details in its
/// UI."* So this screen collects nothing either. It picks the account
/// ownership the policy allows, mints a one-time onboarding link and hands
/// the creator to a real browser.
///
/// Three rules shape it:
///
/// - **A real browser, never a WebView.** *"use a secure system browser or
///   supported provider SDK flow, not an untrusted WebView"* — and the
///   Flutter row of the same section says Connect.js is unsupported in one.
///   [LaunchMode.inAppBrowserView] is SFSafariViewController and a Chrome
///   Custom Tab; `inAppWebView` is forbidden.
/// - **Coming back proves nothing.** *"Returning to the app is not proof of
///   completion. Poll the application until provider requirements are
///   empty…"* The screen says so and reads the rail again rather than
///   marking anything itself.
/// - **The link is single-use.** Stripe's onboarding links expire, which is
///   what Stripe's own `refreshUrl` exists for, so the screen keeps a way
///   to mint a fresh one instead of leaving a creator on a dead page.
class GivingStripeScreen extends StatefulWidget {
  const GivingStripeScreen({
    super.key,
    required this.creatorId,
    required this.rail,
    this.application,
    this.requirements,
    this.repo,
    this.launcher,
    this.origin,
  });

  final String creatorId;
  final GivingRail rail;
  final GivingApplication? application;
  final RailRequirements? requirements;
  final GivingRepo? repo;

  final StripeLauncher? launcher;

  /// The web origin Stripe returns the browser to. Derived from the API
  /// host when it is not given.
  final String? origin;

  /// Where Stripe sends the browser when onboarding ends, and when its link
  /// has gone stale. Both are web pages on the GospelTube app domain — the
  /// native app is not in this loop and never receives a Stripe callback as
  /// proof of anything.
  static const returnPath = '/earnings/onboarding/return';
  static const refreshPath = '/earnings/onboarding/refresh';

  @override
  State<GivingStripeScreen> createState() => _GivingStripeScreenState();
}

class _GivingStripeScreenState extends State<GivingStripeScreen> {
  late final _repo = widget.repo ?? GivingRepo();
  late final StripeLauncher _launch = widget.launcher ?? _openInSystemBrowser;

  bool _busy = false;
  String? _problem;

  /// Whether the browser has been opened at least once. Only the wording
  /// changes: the creator may need to go back more than once, and nothing
  /// here treats a launch as progress.
  bool _launched = false;

  /// SFSafariViewController on iOS, a Chrome Custom Tab on Android.
  static Future<bool> _openInSystemBrowser(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.inAppBrowserView);

  /// The ownership the active policy allows. Never inferred from the
  /// classification: *"`accountOwnership` must be one of the current case
  /// policy's `allowedAccountOwnership` values."*
  List<String> get _ownerships {
    final allowed = widget.requirements?.policy?.allowedAccountOwnership;
    return allowed == null || allowed.isEmpty
        ? const ['legal_recipient']
        : allowed;
  }

  late String _ownership = _ownerships.first;

  Future<void> _open() async {
    final origin = widget.origin ?? webAppOrigin();
    if (origin == null) {
      setState(() => _problem = AppStrings.givingStripeLinkFailed);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final url = await _repo.stripeOnboardingLink(
        creatorId: widget.creatorId,
        railId: widget.rail.id,
        accountOwnership: _ownership,
        returnUrl: '$origin${GivingStripeScreen.returnPath}',
        refreshUrl: '$origin${GivingStripeScreen.refreshPath}',
      );
      final uri = url == null || url.isEmpty ? null : Uri.tryParse(url);
      if (uri == null) {
        if (mounted) {
          setState(() => _problem = AppStrings.givingStripeLinkFailed);
        }
        return;
      }
      final opened = await _launch(uri);
      if (!mounted) return;
      setState(() {
        _launched = opened;
        _problem = opened ? null : AppStrings.givingStripeOpenFailed;
      });
      if (opened) _say(AppStrings.givingStripeOpened);
    } catch (e) {
      // The error only. The onboarding URL is single-use and carries the
      // creator into an authenticated Stripe session.
      logger.w('Stripe onboarding link failed', error: e);
      if (mounted) {
        setState(
          () =>
              _problem = givingProblem(e) ?? AppStrings.givingStripeLinkFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.rail.provider?.label ?? AppStrings.providerStripe;
    return Scaffold(
      backgroundColor: AppColors.base1,
      appBar: AppBar(
        backgroundColor: AppColors.base1,
        elevation: 0,
        title: Text(
          AppStrings.givingRailTitle(provider),
          style: AppStyles.heading(16),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 40.s),
        children: [
          Text(
            AppStrings.givingDirectNote(provider),
            style: AppStyles.body(
              12,
              color: AppColors.neutral400,
              lineHeight: 17 / 12,
            ),
          ),
          SizedBox(height: 14.s),
          GivingInfoNote(AppStrings.givingStripeNote(provider)),
          SizedBox(height: 22.s),
          const GivingSectionTitle(
            AppStrings.givingStripeSection,
            body: AppStrings.givingStripeSectionBody,
          ),
          if (_ownerships.length > 1)
            GivingSelect(
              key: const ValueKey('stripe-ownership'),
              label: AppStrings.givingKycOwnership,
              value: AppStrings.givingOwnershipLabel(_ownership),
              onTap: () async {
                final picked = await GivingPickerSheet.show<String>(
                  context,
                  title: AppStrings.givingKycOwnership,
                  options: _ownerships,
                  labelOf: AppStrings.givingOwnershipLabel,
                  selected: _ownership,
                );
                if (picked == null || !mounted) return;
                setState(() => _ownership = picked);
              },
            ),
          if (_problem case final message?) ...[
            SizedBox(height: 10.s),
            Text(
              message,
              key: const ValueKey('stripe-problem'),
              style: AppStyles.label(12, color: AppColors.red500),
            ),
          ],
          SizedBox(height: 18.s),
          Text(
            AppStrings.givingStripeReviewNote,
            style: AppStyles.label(
              10,
              color: AppColors.neutral500,
              lineHeight: 14 / 10,
            ),
          ),
          SizedBox(height: 18.s),
          // Before the first launch there is one thing to do. Afterwards
          // the creator is somewhere else, and the two things they may
          // want are a fresh link — the old one is spent — and a way back
          // to the rail, which re-reads the truth from the server.
          if (!_launched)
            PrimaryButton(
              key: const ValueKey('stripe-open'),
              label: AppStrings.givingStripeOpen,
              loading: _busy,
              onPressed: () => unawaited(_open()),
            )
          else ...[
            GivingOutlineButton(
              key: const ValueKey('stripe-reopen'),
              label: AppStrings.givingStripeReopen,
              outlined: true,
              loading: _busy,
              onTap: _busy ? null : () => unawaited(_open()),
            ),
            SizedBox(height: 12.s),
            PrimaryButton(
              key: const ValueKey('stripe-done'),
              label: AppStrings.givingStripeDone,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ],
      ),
    );
  }
}
