import 'dart:async';

import 'package:flutter/material.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/services/checkout_handoff_service.dart';
import 'package:test_app/features/giving/data/giving_capability_store.dart';
import 'package:test_app/features/giving/repo/donor_giving_repo.dart';
import 'package:test_app/features/giving/views/give_fund_sheet.dart';
import 'package:test_app/models/library_models/give_flow_models.dart';
import 'package:test_app/shared/components/busy_barrier.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Offering a gift, from wherever the giver happened to be.
Future<bool> startGive(
  BuildContext context, {
  required String creatorId,
  required String ministryName,
  String? sourceMediaId,
  String? fundSlug,
  bool Function(String feature)? requireAccount,
  GivingCapabilityStore? capabilities,
  DonorGivingRepo? repo,
  CheckoutHandoffService? handoff,
}) async {
  if (creatorId.isEmpty) return false;
  if (requireAccount != null && !requireAccount('give to this ministry')) {
    return false;
  }
  // Two taps would be two gifts.
  if (_inFlight.contains(creatorId)) return false;
  _inFlight.add(creatorId);

  final store = capabilities ?? getIt<GivingCapabilityStore>();
  final giving = repo ?? getIt<DonorGivingRepo>();
  final service = handoff ?? getIt<CheckoutHandoffService>();

  void say(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.base2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  try {
    // Three round trips stand between the tap and the browser — capability,
    // funds, then the session — and on a real device that was thirteen
    // seconds of a button that looked broken.
    final capable = await runBusy(
      context,
      () => store.ensure(creatorId),
      message: AppStrings.giveOpening,
    );
    if (!capable) {
      say(AppStrings.giveUnavailable);
      return false;
    }

    // A funds read that fails is not a reason to refuse the gift: the web
    // surface selects `general` on its own when no slug is sent.
    var slug = fundSlug;
    if (slug == null) {
      // Gone from the screen before the capability came back: no gift to
      // start, and nothing to tell anyone.
      if (!context.mounted) return false;
      final funds = await runBusy(
        context,
        message: AppStrings.giveOpening,
        () async {
          try {
            return await giving.fetchFunds(creatorId);
          } catch (e) {
            logger.w(
              'Giving funds unavailable; handing off without one',
              error: e,
            );
            return const <GivingFundOption>[];
          }
        },
      );
      if (funds.length > 1) {
        if (!context.mounted) return false;
        slug = await GiveFundSheet.show(
          context,
          ministry: ministryName,
          funds: funds,
        );
        // Backing out of the picker is backing out of the gift.
        if (slug == null) return false;
      } else if (funds.length == 1) {
        slug = funds.single.slug;
      }
    }

    if (!context.mounted) return false;
    final result = await runBusy(
      context,
      message: AppStrings.giveOpening,
      () => service.startGiving(
        creatorId: creatorId,
        fundSlug: slug,
        sourceMediaId: sourceMediaId,
      ),
    );

    switch (result.outcome) {
      case HandoffOutcome.launched:
        // The browser is open; the gift is decided there and read back from
        // the session when the return link arrives.
        return true;
      case HandoffOutcome.unavailable:
        say(AppStrings.giveUnavailableHere);
      case HandoffOutcome.alreadyActive:
        // Giving sessions coexist, so this is not reachable for a gift
        // today.
        final id = result.sessionId;
        if (id != null && context.mounted) {
          appRouter.push(AppRouter.givingStatus, extra: id);
        } else {
          say(AppStrings.giveFailed);
        }
      case HandoffOutcome.failed:
        say(AppStrings.giveFailed);
    }
    return false;
  } finally {
    _inFlight.remove(creatorId);
  }
}

/// Ministries with a gift being prepared right now.
final _inFlight = <String>{};

/// Forgets every gift in flight.
@visibleForTesting
void resetGiveGuard() => _inFlight.clear();
