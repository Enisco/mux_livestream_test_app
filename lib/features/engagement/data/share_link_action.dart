import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';

/// What came of a Share.
enum ShareLinkOutcome {
  /// The device's sheet opened and the reader sent it somewhere. Where is
  /// the OS's business, not ours.
  shared,

  /// The sheet opened and the reader backed out. Nothing to report: they
  /// already know what they did.
  dismissed,

  /// There is no link. Either the mint was refused — the target is not
  /// public, or not visible to this reader — or the device has no sheet.
  unavailable,
}

/// Opens the device's share sheet. Swapped out in tests, where there is no
/// platform channel behind it.
typedef ShareSheet =
    Future<ShareResultStatus> Function(String url, String? subject, Rect? from);

Future<ShareResultStatus> _systemShareSheet(
  String url,
  String? subject,
  Rect? from,
) async {
  final result = await SharePlus.instance.share(
    ShareParams(
      uri: Uri.parse(url),
      subject: subject,
      // iPad draws the sheet as a popover and needs something to point it
      // at; without this it throws rather than opening.
      sharePositionOrigin: from,
    ),
  );
  return result.status;
}

ShareSheet _openShareSheet = _systemShareSheet;

/// A test's stand-in for the platform sheet. Pass null to put the real one
/// back.
@visibleForTesting
set shareSheetForTesting(ShareSheet? sheet) =>
    _openShareSheet = sheet ?? _systemShareSheet;

/// Mint a share link for one target and hand it to the device's share
/// sheet, so the reader picks where it goes.
///
/// This used to copy the link to the clipboard and say so in a snackbar,
/// which is not what a control labelled Share means anywhere else on the
/// phone. Copying is still available — it is one of the rows the system
/// sheet offers — and [copyShareLink] remains for the buttons that say
/// Copy link outright.
///
/// [from] anchors the popover on iPad, where it is required rather than
/// optional — [shareOriginOf] works it out from the widget that was
/// tapped and always returns something usable.
Future<ShareLinkOutcome> shareLink({
  required EngagementRepo engagement,
  required String targetType,
  required String targetId,
  String? subject,
  Rect? from,
}) async {
  final url = await _mint(
    engagement: engagement,
    targetType: targetType,
    targetId: targetId,
  );
  if (url == null) return ShareLinkOutcome.unavailable;
  try {
    final status = await _openShareSheet(url, subject, from);
    return switch (status) {
      ShareResultStatus.dismissed => ShareLinkOutcome.dismissed,
      // `unavailable` means the platform could not say what the reader
      // chose, not that nothing happened — Android reports it routinely.
      // Treating it as a failure would put an error under a share that
      // worked.
      _ => ShareLinkOutcome.shared,
    };
  } catch (e) {
    logger.w('Share sheet failed', error: e);
    return ShareLinkOutcome.unavailable;
  }
}

/// Where on screen the sheet should appear to come from.
///
/// This is not decoration. iPad draws the share sheet as a popover, and
/// `FPPSharePlusPlugin` **refuses outright** — a `FlutterError`, no sheet
/// — when the origin is missing or empty there. The app ships for iPad
/// (`TARGETED_DEVICE_FAMILY = "1,2"`), so a null here would be a Share
/// that quietly reported "that can't be shared" on every iPad.
///
/// Hence a fallback rather than a null: the middle of the screen is not
/// where the tap was, but a popover in the wrong place beats no popover.
Rect shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize && !box.size.isEmpty) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  final screen = MediaQuery.sizeOf(context);
  return Rect.fromCenter(
    center: Offset(screen.width / 2, screen.height / 2),
    width: 1,
    height: 1,
  );
}

/// Mint a share link for one target and put it on the clipboard. For the
/// controls that say Copy link; Share uses [shareLink].
Future<String?> copyShareLink({
  required EngagementRepo engagement,
  required String targetType,
  required String targetId,
}) async {
  final url = await _mint(
    engagement: engagement,
    targetType: targetType,
    targetId: targetId,
  );
  if (url == null) return null;
  await Clipboard.setData(ClipboardData(text: url));
  return url;
}

Future<String?> _mint({
  required EngagementRepo engagement,
  required String targetType,
  required String targetId,
}) async {
  try {
    final url = await engagement.mintShareLink(
      targetType: targetType,
      targetId: targetId,
    );
    if (url == null || url.isEmpty) return null;
    return url;
  } catch (e) {
    logger.w('Share link refused', error: e);
    return null;
  }
}
