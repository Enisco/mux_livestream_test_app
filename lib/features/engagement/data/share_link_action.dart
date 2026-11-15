import 'package:flutter/services.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';

/// Mint a share link for one target and put it on the clipboard.
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
