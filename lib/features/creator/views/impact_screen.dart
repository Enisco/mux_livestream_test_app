import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/creator_dashboard_repo.dart';
import 'package:test_app/features/creator/repo/impact_repo.dart';
import 'package:test_app/features/creator/views/widgets/impact_parts.dart';
import 'package:test_app/features/creator/views/widgets/impact_sheets.dart';
import 'package:test_app/features/creator/views/widgets/studio_parts.dart';
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/models/creator_models/impact_models.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// What the congregation is sending: prayers, testimonies and comments.
///
/// Three inboxes behind one screen, each on its own creator-side route. Two
/// things shape how this is wired:
///
/// - **The filters are server-side.** Changing one refetches rather than
///   narrowing what is already loaded, because each tab's status filter is a
///   query parameter and the list is paged.
/// - **A decision can take a row out of its list**, and that is the point
///   rather than a bug: keeping a comment public removes it from the
///   moderation queue, and approving a testimony moves it out of Pending.
///   The card goes immediately and the summary is refetched so the tab
///   counts cannot disagree with what is on screen. A failed write puts the
///   row back and says so.
///
/// The Comments tab is **not** a comment feed — see [ImpactQueueNote].
class ImpactScreen extends StatefulWidget {
  const ImpactScreen({super.key, this.repo, this.dashboard, this.context});

  /// Defaults to the real thing; a test supplies its own.
  final ImpactRepo? repo;
  final CreatorDashboardRepo? dashboard;

  /// Fetched once by the shell and shared by every tab, for the header.
  final DashboardContext? context;

  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> {
  late final _repo = widget.repo ?? ImpactRepo();

  int _tab = 0;
  bool _loading = true;
  bool _failed = false;
  bool _loadingMore = false;

  PrayerFilter _prayerFilter = PrayerFilter.open;
  TestimonyFilter _testimonyFilter = TestimonyFilter.pending;
  CommentFilter _commentFilter = CommentFilter.both;

  List<PrayerRequest> _prayers = const [];
  List<CreatorTestimony> _testimonies = const [];
  List<ImpactComment> _comments = const [];

  /// Keyset for prayers, page numbers for the other two.
  String? _prayerCursor;
  int? _testimonyNextPage;
  int? _commentNextPage;

  PrayerSummary? _prayerSummary;
  TestimonySummary? _testimonySummary;

  /// The queue has no summary route of its own, so the count beside the tab
  /// is `meta.total` from the page it last read.
  int? _commentCount;

  List<ImpactPerson> _assignees = const [];

  String? get _creatorId => widget.context?.creatorId ?? LocalStorage.creatorId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// Load the tab in view. Only the one on screen is fetched — the other two
  /// load when they are opened, so switching studios does not fire six reads.
  Future<void> _load() async {
    final creatorId = _creatorId;
    if (creatorId == null || creatorId.isEmpty) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      switch (_tab) {
        case 0:
          final page = await _repo.fetchPrayers(
            creatorId,
            status: _prayerFilter,
          );
          if (!mounted) return;
          setState(() {
            _prayers = page.items;
            _prayerCursor = page.nextCursor;
          });
          unawaited(_refreshPrayerSummary(creatorId));
          unawaited(_loadAssignees(creatorId));
        case 1:
          final page = await _repo.fetchTestimonies(
            creatorId,
            status: _testimonyFilter,
          );
          if (!mounted) return;
          setState(() {
            _testimonies = page.items;
            _testimonyNextPage = page.nextPage;
          });
          unawaited(_refreshTestimonySummary(creatorId));
        default:
          final page = await _repo.fetchComments(
            creatorId,
            filter: _commentFilter,
          );
          if (!mounted) return;
          setState(() {
            _comments = page.items;
            _commentNextPage = page.nextPage;
            _commentCount = page.total ?? page.items.length;
          });
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      logger.w('Impact could not be loaded', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// The next page of whichever tab is in view.
  Future<void> _loadMore() async {
    final creatorId = _creatorId;
    if (creatorId == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      switch (_tab) {
        case 0:
          if (_prayerCursor case final cursor?) {
            final page = await _repo.fetchPrayers(
              creatorId,
              status: _prayerFilter,
              cursor: cursor,
            );
            if (!mounted) return;
            setState(() {
              _prayers = [..._prayers, ...page.items];
              _prayerCursor = page.nextCursor;
            });
          }
        case 1:
          if (_testimonyNextPage case final page?) {
            final next = await _repo.fetchTestimonies(
              creatorId,
              status: _testimonyFilter,
              page: page,
            );
            if (!mounted) return;
            setState(() {
              _testimonies = [..._testimonies, ...next.items];
              _testimonyNextPage = next.nextPage;
            });
          }
        default:
          if (_commentNextPage case final page?) {
            final next = await _repo.fetchComments(
              creatorId,
              filter: _commentFilter,
              page: page,
            );
            if (!mounted) return;
            setState(() {
              _comments = [..._comments, ...next.items];
              _commentNextPage = next.nextPage;
              _commentCount = next.total ?? _comments.length;
            });
          }
      }
    } catch (e) {
      logger.w('Impact could not page', error: e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ---- Counts -----------------------------------------------------------

  /// Summaries are refetched after every decision so the tab counts and the
  /// cards cannot disagree. Losing one must not lose the list, so each is
  /// swallowed on failure and the pill simply shows no number.
  Future<void> _refreshPrayerSummary(String creatorId) async {
    try {
      final summary = await _repo.fetchPrayerSummary(creatorId);
      if (mounted) setState(() => _prayerSummary = summary);
    } catch (e) {
      logger.w('Prayer summary unavailable', error: e);
    }
  }

  Future<void> _refreshTestimonySummary(String creatorId) async {
    try {
      final summary = await _repo.fetchTestimonySummary(creatorId);
      if (mounted) setState(() => _testimonySummary = summary);
    } catch (e) {
      logger.w('Testimony summary unavailable', error: e);
    }
  }

  Future<void> _loadAssignees(String creatorId) async {
    if (_assignees.isNotEmpty) return;
    try {
      final people = await _repo.fetchAssignees(creatorId);
      if (mounted) setState(() => _assignees = people);
    } catch (e) {
      logger.w('Assignees unavailable', error: e);
    }
  }

  /// The number beside each tab. Null where nothing has counted it yet — a
  /// pill shows its label alone rather than a zero it cannot stand behind.
  List<int?> get _counts => [
    _prayerSummary?.open,
    _testimonySummary?.pending,
    _commentCount,
  ];

  // ---- Saying what happened ---------------------------------------------

  void _say(String message, {String? detail, VoidCallback? undo}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          action: undo == null
              ? null
              : SnackBarAction(
                  label: AppStrings.impactUndo,
                  textColor: AppColors.brandPrimary,
                  onPressed: undo,
                ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: AppStyles.body(13)),
              if (detail case final line?) ...[
                SizedBox(height: 2.s),
                Text(
                  line,
                  style: AppStyles.body(11, color: AppColors.neutral400),
                ),
              ],
            ],
          ),
          backgroundColor: AppColors.neutral900,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16.s, 0, 16.s, 96.s),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.s),
          ),
        ),
      );
  }

  // ---- Prayers ----------------------------------------------------------

  /// Apply [change] to the list at once, send [write], and put the old list
  /// back if the write fails. Every decision on this screen goes through here
  /// so none of them can leave the screen disagreeing with the server.
  Future<void> _decide({
    required VoidCallback change,
    required Future<void> Function() write,
    required String said,
    String? detail,
    VoidCallback? undo,
    required VoidCallback rollback,
  }) async {
    change();
    try {
      await write();
      _say(said, detail: detail, undo: undo);
    } catch (e) {
      logger.w('Impact write failed', error: e);
      if (!mounted) return;
      rollback();
      _say(AppStrings.impactActionFailed);
    }
  }

  void _replacePrayer(PrayerRequest before, PrayerRequest? after) {
    setState(() {
      _prayers = [
        for (final p in _prayers)
          if (p.id != before.id) p else ?after,
      ];
    });
  }

  /// Move a prayer to [to]. The row leaves the list, because the list is
  /// filtered to one state — so the toast carries the design's **Undo**,
  /// which writes the old status back and puts the card where it was.
  Future<void> _movePrayer(
    PrayerRequest prayer,
    PrayerFilter to,
    String said,
  ) async {
    final index = _prayers.indexWhere((p) => p.id == prayer.id);
    await _decide(
      change: () => _replacePrayer(prayer, null),
      write: () => _repo.updatePrayer(prayer.id, status: to),
      said: said,
      undo: () => _undoPrayer(prayer, index),
      rollback: () => _restorePrayer(prayer, index),
    );
    if (_creatorId case final id?) unawaited(_refreshPrayerSummary(id));
  }

  /// Put a prayer back where it was. Undoing is a write of its own, so it
  /// can fail on its own, and its toast offers no second Undo.
  Future<void> _undoPrayer(PrayerRequest prayer, int index) async {
    try {
      await _repo.updatePrayer(prayer.id, status: prayer.state);
      if (!mounted) return;
      _restorePrayer(prayer, index);
      _say(AppStrings.prayerUndone);
    } catch (e) {
      logger.w('Impact undo failed', error: e);
      if (mounted) _say(AppStrings.impactActionFailed);
    }
    if (_creatorId case final id?) unawaited(_refreshPrayerSummary(id));
  }

  /// Open → prayed for → closed, one step per tap.
  Future<void> _advancePrayer(PrayerRequest prayer) async {
    final next = prayer.nextState;
    if (next == null) return;
    await _movePrayer(
      prayer,
      next,
      next == PrayerFilter.closed
          ? AppStrings.prayerMarkedResolved
          : AppStrings.prayerMarkedPrayed,
    );
  }

  void _restorePrayer(PrayerRequest prayer, int index) {
    setState(() {
      final rows = [..._prayers];
      rows.insert(index.clamp(0, rows.length), prayer);
      _prayers = rows;
    });
  }

  Future<void> _prayerMenu(PrayerRequest prayer) async {
    final action = await showPrayerActionsSheet(context, prayer: prayer);
    if (action == null || !mounted) return;
    switch (action) {
      case PrayerAction.assign:
        await _assign(prayer);
      case PrayerAction.reopen:
        await _movePrayer(prayer, PrayerFilter.open, AppStrings.prayerReopened);
      case PrayerAction.resolve:
        await _movePrayer(
          prayer,
          PrayerFilter.closed,
          AppStrings.prayerMarkedResolved,
        );
    }
  }

  Future<void> _assign(PrayerRequest prayer) async {
    final picked = await showAssignPrayerSheet(
      context,
      members: _assignees,
      selectedId: prayer.assignedToUserId,
    );
    if (picked == null || !mounted) return;

    // A row with no userId is the sheet's "remove assignment", which must go
    // as an explicit null — omitting the field would keep the stale assignee.
    final clearing = picked.userId == null;
    await _decide(
      change: () => _replacePrayer(prayer, prayer.copyWith(assignee: picked)),
      write: () => _repo.updatePrayer(
        prayer.id,
        assignedToUserId: clearing ? null : picked.userId,
        unassign: clearing,
      ),
      said: clearing
          ? AppStrings.prayerUnassigned
          : AppStrings.prayerAssignedToast(picked.displayName),
      rollback: () => _replacePrayer(prayer, prayer),
    );
    if (_creatorId case final id?) unawaited(_refreshPrayerSummary(id));
  }

  // ---- Testimonies ------------------------------------------------------

  Future<void> _judgeTestimony(
    CreatorTestimony testimony,
    TestimonyFilter to,
  ) async {
    final index = _testimonies.indexWhere((t) => t.id == testimony.id);
    await _decide(
      change: () => setState(() {
        _testimonies = [
          for (final t in _testimonies)
            if (t.id != testimony.id) t,
        ];
      }),
      write: () => _repo.moderateTestimony(testimony.id, to),
      said: switch (to) {
        TestimonyFilter.approved => AppStrings.testimonyApprovedToast,
        TestimonyFilter.rejected => AppStrings.testimonyRejectedToast,
        TestimonyFilter.pending => AppStrings.testimonyRestoredToast,
      },
      detail: to == TestimonyFilter.approved
          ? AppStrings.testimonyNowLive
          : null,
      rollback: () => setState(() {
        final rows = [..._testimonies];
        rows.insert(index.clamp(0, rows.length), testimony);
        _testimonies = rows;
      }),
    );
    if (_creatorId case final id?) unawaited(_refreshTestimonySummary(id));
  }

  // ---- Comment moderation queue -----------------------------------------

  Future<void> _moderateComment(
    ImpactComment comment,
    CommentModeration to,
  ) async {
    final index = _comments.indexWhere((c) => c.id == comment.id);
    // Keeping a comment public takes it out of the queue; hiding one keeps
    // it here under the other filter unless the list is narrowed to flagged.
    final leaves =
        to == CommentModeration.visible ||
        _commentFilter == CommentFilter.flagged;
    await _decide(
      change: () => setState(() {
        _comments = [
          for (final c in _comments)
            if (c.id != comment.id)
              c
            else if (!leaves)
              c.copyWith(status: to.slug),
        ];
        if (leaves && _commentCount != null) _commentCount = _commentCount! - 1;
      }),
      write: () => _repo.moderateComment(comment.id, to),
      // Both decisions write `visible`, but they are different acts: one
      // clears a report, the other puts back something the team took down.
      said: switch ((to, comment.isHidden)) {
        (CommentModeration.hidden, _) => AppStrings.commentHidden,
        (_, true) => AppStrings.commentUnhidden,
        _ => AppStrings.commentKeptPublic,
      },
      detail: to == CommentModeration.visible
          ? AppStrings.commentLeavesQueue
          : null,
      rollback: () => setState(() {
        final rows = [
          for (final c in _comments)
            if (c.id != comment.id) c,
        ];
        rows.insert(index.clamp(0, rows.length), comment);
        _comments = rows;
        if (leaves && _commentCount != null) _commentCount = _commentCount! + 1;
      }),
    );
  }

  Future<void> _report(ImpactComment comment) async {
    final outcome = await showReportSheet(context);
    if (outcome == null || !mounted) return;
    // `POST /v1/engagement/reports` is live and takes `comment` as a target
    // type. What it cannot do is tell the creator what happened next — there
    // is no escalation workflow, so the design's "with our team for review"
    // banner is deliberately not built. See docs/OPEN_ISSUES.md.
    _say(AppStrings.commentReported);
  }

  // ---- Filters ----------------------------------------------------------

  Future<void> _pickFilter() async {
    switch (_tab) {
      case 0:
        final picked = await showPrayerStateSheet(
          context,
          selected: _prayerFilter,
        );
        if (picked != null && picked != _prayerFilter && mounted) {
          setState(() => _prayerFilter = picked);
          unawaited(_load());
        }
      case 1:
        final picked = await showTestimonyStateSheet(
          context,
          selected: _testimonyFilter,
        );
        if (picked != null && picked != _testimonyFilter && mounted) {
          setState(() => _testimonyFilter = picked);
          unawaited(_load());
        }
      default:
        final picked = await showCommentStateSheet(
          context,
          selected: _commentFilter,
        );
        if (picked != null && picked != _commentFilter && mounted) {
          setState(() => _commentFilter = picked);
          unawaited(_load());
        }
    }
  }

  void _switchTab(int index) {
    if (index == _tab) return;
    setState(() => _tab = index);
    unawaited(_load());
  }

  String get _viewing => switch (_tab) {
    0 => AppStrings.impactViewingPrayers,
    1 => AppStrings.impactViewingTestimonies,
    _ => AppStrings.impactViewingComments,
  };

  String get _stateLabel => switch (_tab) {
    0 => switch (_prayerFilter) {
      PrayerFilter.open => AppStrings.prayerViewingOpen,
      PrayerFilter.prayedFor => AppStrings.prayerViewingPrayed,
      PrayerFilter.closed => AppStrings.prayerViewingResolved,
    },
    1 => switch (_testimonyFilter) {
      TestimonyFilter.pending => AppStrings.testimonyStatePending,
      TestimonyFilter.approved => AppStrings.testimonyStateApproved,
      TestimonyFilter.rejected => AppStrings.testimonyStateRejected,
    },
    _ => switch (_commentFilter) {
      CommentFilter.both => AppStrings.commentStateAll,
      CommentFilter.flagged => AppStrings.commentStateFlagged,
      CommentFilter.hidden => AppStrings.commentStateHidden,
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.brandPrimary,
          backgroundColor: AppColors.base1,
          onRefresh: _load,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final metrics = notification.metrics;
              if (metrics.axis == Axis.vertical &&
                  metrics.extentAfter < 400 &&
                  _hasMore) {
                unawaited(_loadMore());
              }
              return false;
            },
            child: ListView(
              // Without this an empty tab is too short to scroll, and a
              // creator waiting on their first prayer cannot pull to refresh.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.s, 8.s, 16.s, 120.s),
              children: [
                _header(),
                SizedBox(height: 16.s),
                Text(
                  AppStrings.impactTitle,
                  style: AppStyles.heading(28, letterSpacing: -0.8),
                ),
                SizedBox(height: 4.s),
                Text(
                  AppStrings.impactSubtitle,
                  style: AppStyles.body(13, color: AppColors.neutral400),
                ),
                SizedBox(height: 18.s),
                ImpactTabs(index: _tab, counts: _counts, onChanged: _switchTab),
                if (_tab == 2) const ImpactQueueNote(),
                SizedBox(height: 22.s),
                ImpactFilterRow(
                  viewing: _viewing,
                  state: _stateLabel,
                  onTapState: _pickFilter,
                ),
                SizedBox(height: 6.s),
                if (_loading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 60.s),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  )
                else if (_failed)
                  ErrorStateView(onRetry: _load)
                else ...[
                  ..._body(),
                  if (_loadingMore)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.s),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasMore => switch (_tab) {
    0 => _prayerCursor != null,
    1 => _testimonyNextPage != null,
    _ => _commentNextPage != null,
  };

  /// The studio pill and the bell, as the Studio and Content tabs draw them.
  Widget _header() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: StudioPill(
          name: widget.context?.displayName ?? '',
          onTap: () => _say(AppStrings.studiosSwitch),
        ),
      ),
      SizedBox(width: 12.s),
      GestureDetector(
        key: const ValueKey('impact-notifications'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _say(AppStrings.impactAwaitingApi),
        child: Container(
          width: 38.s,
          height: 38.s,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.fieldBg,
          ),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedNotification01,
            color: AppColors.textPrimary,
            size: 18.s,
          ),
        ),
      ),
    ],
  );

  List<Widget> _body() => switch (_tab) {
    0 => _prayerList(),
    1 => _testimonyList(),
    _ => _commentList(),
  };

  List<Widget> _prayerList() {
    if (_prayers.isEmpty) {
      return const [
        ImpactEmpty(
          title: AppStrings.impactNoPrayers,
          body: AppStrings.impactNoPrayersBody,
        ),
      ];
    }
    return [
      for (final (i, prayer) in _prayers.indexed) ...[
        if (i > 0) const _Divider(),
        PrayerRequestCard(
          prayer: prayer,
          onAdvance: () => _advancePrayer(prayer),
          onMore: () => _prayerMenu(prayer),
        ),
      ],
    ];
  }

  List<Widget> _testimonyList() {
    if (_testimonies.isEmpty) {
      return const [
        ImpactEmpty(
          title: AppStrings.impactNoTestimonies,
          body: AppStrings.impactNoTestimoniesBody,
        ),
      ];
    }
    return [
      for (final (i, testimony) in _testimonies.indexed) ...[
        if (i > 0) const _Divider(),
        TestimonyCard(
          testimony: testimony,
          onApprove: () => _judgeTestimony(
            testimony,
            // "Restore" puts a turned-down story back in the queue; it does
            // not publish it.
            testimony.isRejected
                ? TestimonyFilter.pending
                : TestimonyFilter.approved,
          ),
          onReject: () => _judgeTestimony(testimony, TestimonyFilter.rejected),
        ),
      ],
    ];
  }

  List<Widget> _commentList() {
    if (_comments.isEmpty) {
      return const [
        ImpactEmpty(
          title: AppStrings.impactNoComments,
          body: AppStrings.impactNoCommentsBody,
        ),
      ];
    }
    return [
      for (final (i, comment) in _comments.indexed) ...[
        if (i > 0) const _Divider(),
        ImpactCommentCard(
          comment: comment,
          onKeepPublic: () =>
              _moderateComment(comment, CommentModeration.visible),
          onHide: () => _moderateComment(comment, CommentModeration.hidden),
          onReport: () => _report(comment),
        ),
      ],
    ];
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.neutral900);
}
