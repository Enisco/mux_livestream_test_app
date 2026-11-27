import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:test_app/features/engagement/data/engagement_store.dart';

/// Takes a screen off the stack once the thing it is showing has been
/// hidden under it.
///
/// Blocking a ministry from the sheet on that ministry's own profile — or
/// on one of its videos — changed nothing the reader could see. The lists
/// behind filter themselves now, but the page in front went on showing
/// exactly what had just been objected to, with the block button sitting
/// there looking inert.
///
/// Watches [EngagementStore.hiddenChanges] rather than the store, so a
/// like on the page does not run the check.
class LeaveWhenHidden {
  LeaveWhenHidden({
    required this.store,
    required this.isHidden,
    required this.leave,
  });

  final EngagementStore store;

  /// Read fresh each time: a detail screen usually does not know whose
  /// content it is until its fetch lands.
  final bool Function() isHidden;

  final VoidCallback leave;

  void attach() => store.hiddenChanges.addListener(_check);

  void detach() => store.hiddenChanges.removeListener(_check);

  void _check() {
    if (!isHidden()) return;
    // A microtask, not this instant and not a post-frame callback.
    //
    // Not this instant: the store is part-way through handing the change
    // to its other listeners, and tearing a route down underneath that
    // is not worth the risk.
    //
    // Not `addPostFrameCallback`: registering one does **not** schedule a
    // frame, so an idle app can sit on it indefinitely. A microtask
    // always runs, and runs after the current call finishes.
    scheduleMicrotask(leave);
  }
}
