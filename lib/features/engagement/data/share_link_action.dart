import 'package:flutter/services.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';

/// Mint a share link for one target and put it on the clipboard.
///
/// **Minting is not sharing.** The share counter moves on an
/// `interactionType: "share"` interaction and nothing here posts one: a
/// viewer who opens a sheet and changes their mind has not shared anything,
/// and counting the mint would inflate every creator's share count by every
/// abandoned sheet.
///
/// Returns the URL that was copied, or null when the target refuses. A
/// refusal is final — a private playlist, an unpublished post or a cancelled
/// event answers 404 and will keep answering 404 until its creator changes
/// the content's visibility — so callers report it rather than retrying.
///
/// Lives here rather than in the one sheet that first needed it because the
/// feed needs the same four steps, and a second copy is how the two drift.
Future<String?> copyShareLink({
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
    await Clipboard.setData(ClipboardData(text: url));
    return url;
  } catch (e) {
    logger.w('Share link refused', error: e);
    return null;
  }
}
