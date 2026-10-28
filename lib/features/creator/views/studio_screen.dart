import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/core/locator.dart';
import 'package:test_app/features/notifications/data/notification_store.dart';
import 'package:test_app/features/notifications/views/notifications_screen.dart';
import 'package:test_app/features/creator/repo/creator_dashboard_repo.dart';
import 'package:test_app/features/creator/views/go_live_setup_screen.dart';
import 'package:test_app/features/creator/views/new_article_screen.dart';
import 'package:test_app/features/creator/views/new_event_screen.dart';
import 'package:test_app/features/creator/views/new_media_screen.dart';
import 'package:test_app/features/creator/views/studio_shell.dart'
    show OpenStudioTab;
import 'package:test_app/features/creator/views/widgets/studio_parts.dart';
import 'package:test_app/features/creator/views/widgets/studio_sheets.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount;
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The Studio tab: what the studio is doing today, and what it needs.
///
/// Two states of one screen. A studio with steps left shows the numbered card
/// and "Your studio is ready"; one that is under way shows a count of what
/// needs attention, a search and a Create button. Both show TODAY.
///
/// Every section loads separately — a studio with no payment set up makes the
/// giving figure fail, which must not empty the rest of the screen.
class StudioScreen extends StatefulWidget {
  const StudioScreen({
    super.key,
    this.onLeaveStudio,
    this.studios = const [],
    this.onSwitchStudio,
    this.onOpenTab,
  });

  /// Sends the reader to another tab of the shell.
  ///
  /// Most of what this screen points at — the attention feed, the giving
  /// step, the search icon — already exists as a sibling tab, so it asks the
  /// shell to switch rather than pushing a second copy over itself.
  final OpenStudioTab? onOpenTab;

  /// Every studio the reader can work in. The shell owns the list so all
  /// four tabs show the same switcher.
  final List<StudioMembership> studios;

  /// Re-points the shell at another studio.
  final Future<void> Function(String creatorId)? onSwitchStudio;

  /// "Back to watching" — handed in so the shell decides where that goes.
  final VoidCallback? onLeaveStudio;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final _repo = CreatorDashboardRepo();

  DashboardContext? _context;
  List<GettingStartedStep> _steps = const [];
  List<AttentionItem> _attention = const [];
  DashboardPerformance _performance = DashboardPerformance.empty;
  int? _subscribers;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(_notifications.refresh());
    _notifications.addListener(_onNotifications);
  }

  final _notifications = getIt<NotificationStore>();

  void _onNotifications() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notifications.removeListener(_onNotifications);
    super.dispose();
  }

  /// What is left of the plan's upload allowance, so the + Create sheet can
  /// say so before a file is picked rather than after it is uploaded.
  PlanUsage? _usage;

  Future<void> _loadUsage(String creatorId) async {
    final usage = await CreatorDashboardRepo().fetchPlanUsage(creatorId);
    if (mounted) setState(() => _usage = usage);
  }

  Future<void> _load() async {
    final creatorId = LocalStorage.creatorId;
    if (creatorId == null) {
      setState(() => _loading = false);
      return;
    }
    unawaited(_loadUsage(creatorId));

    final context = await _repo.fetchContext(creatorId);
    if (!mounted) return;
    setState(() => _context = context);

    final results = await Future.wait([
      _repo.fetchGettingStarted(creatorId),
      _repo.fetchAttention(creatorId),
      _repo.fetchPerformance(creatorId),
      _repo.fetchSubscriberCount(creatorId),
    ]);
    if (!mounted) return;

    setState(() {
      _steps = (results[0] as List<GettingStartedStep>)
          // A step that does not apply to this studio is not a step.
          .where((s) => s.applicable)
          .toList(growable: false);
      _attention = results[1] as List<AttentionItem>;
      _performance = results[2] as DashboardPerformance;
      _subscribers = results[3] as int?;
      _loading = false;
    });
  }

  /// A studio still finding its feet leads with the steps rather than with
  /// numbers that are all dashes.
  ///
  /// Only meaningful once loaded: before that the screen knows nothing, and
  /// guessing "established" would show a full dashboard of dashes with a
  /// Full analytics link behind them.
  bool get _isNew => _steps.any((s) => !s.complete);

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// The shell's tab order, named so the call sites read as destinations
  /// rather than as magic numbers.
  static const _contentTab = 1;
  static const _impactTab = 2;
  static const _givingTab = 3;

  /// Open the Impact inbox a "needs you" row belongs to.
  ///
  /// The three keys the dashboard actually sends are `open_prayers`,
  /// `pending_testimonies` and `flagged_comments`; anything else lands on
  /// Impact's first tab rather than nowhere.
  void _openAttention(String key) => widget.onOpenTab?.call(
    _impactTab,
    impactTab: switch (key) {
      'pending_testimonies' => 1,
      'flagged_comments' => 2,
      _ => 0,
    },
  );

  /// Every studio the reader can work in, since 2026-10-26.
  ///
  /// Switching re-points the cached `creatorId` and reloads: per-studio
  /// permissions are resolved by `dashboard/context`, which is read again for
  /// whichever one is picked, so nothing else has to be invalidated by hand.
  Future<void> _openStudios() async {
    // Not `_context` alone: a studio whose dashboard refuses this reader has
    // none, and that is the reader who most needs the way out.
    final current = openStudio(_context, widget.studios);
    if (current == null) return;
    final choice = await StudiosSheet.show(
      context,
      current: current,
      studios: widget.studios,
    );
    if (!mounted || choice == null) return;
    if (choice.leave) {
      widget.onLeaveStudio?.call();
      return;
    }
    if (choice.switchTo case final creatorId?) {
      await widget.onSwitchStudio?.call(creatorId);
      if (mounted) await _load();
      return;
    }
    // Not "not built yet": studio settings are a web-studio screen and say
    // so on the row that offers them, so the answer names the reason.
    _say(AppStrings.studiosSettingsNote);
  }

  /// Where a getting-started step actually leads.
  ///
  /// Every row used to answer "not built yet", which was wrong twice over:
  /// the destinations exist, and a checklist whose steps cannot be started
  /// is worse than no checklist. A completed step still leads somewhere —
  /// "Complete your profile" is how a creator goes back and changes the
  /// photo they already set.
  Future<void> _openStep(GettingStartedStep step) async {
    switch (step.key) {
      case 'complete_profile':
        // The polish chain: photo → banner → bio → links, which ends by
        // returning here, so the checklist is re-read on the way back.
        context.go(AppRouter.creatorPhoto);
      case 'publish_first_content':
        // The same sheet Quick upload opens. The step is about *content*,
        // not specifically media, so the full choice is the right one.
        await _openCreate();
      case 'go_live':
        final went = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const GoLiveSetupScreen()),
        );
        if ((went ?? false) && mounted) await _load();
      case 'setup_giving':
        // Giving is a tab of this shell now. It used to be sent to the web
        // with team roles, which was true before the Giving tab existed and
        // has been wrong since.
        widget.onOpenTab?.call(_givingTab);
      case 'invite_team':
        // Team roles really are web-studio work, like events and promotions
        // — which the card at the bottom of this screen already says.
        _say(AppStrings.studioStepOnWeb);
      default:
        // A step the backend has added that this release has no destination
        // for. Naming it is better than a key, and better than silence.
        _say(AppStrings.studioStepOnWeb);
    }
  }

  Future<void> _openCreate() async {
    final current = _context;
    final allowed = [
      for (final kind in CreateKind.values)
        if (current == null || current.can(kind.capability)) kind,
    ];
    final picked = await CreateSheet.show(
      context,
      kinds: allowed,
      usage: _usage,
    );
    if (!mounted || picked == null) return;
    // Video and audio are the same screen; everything else is not built.
    final kind = switch (picked) {
      CreateKind.video => MediaUploadKind.video,
      CreateKind.audio => MediaUploadKind.music,
      _ => null,
    };
    if (picked == CreateKind.livestream) {
      // Going live is not an upload: it opens the camera, not a picker.
      final went = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const GoLiveSetupScreen()),
      );
      if ((went ?? false) && mounted) await _load();
      return;
    }
    if (picked == CreateKind.blog) {
      final made = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const NewArticleScreen()),
      );
      if ((made ?? false) && mounted) await _load();
      return;
    }
    if (picked == CreateKind.event) {
      final made = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const NewEventScreen()),
      );
      if ((made ?? false) && mounted) await _load();
      return;
    }
    if (kind != null) {
      final made = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => NewMediaScreen(kind: kind)),
      );
      // A first upload changes the getting-started checklist and the
      // counts, so the tab should not still be showing the old ones.
      if ((made ?? false) && mounted) await _load();
      return;
    }
    // Unreachable today — every CreateKind above returns — but a kind added
    // later would otherwise fall out of this sheet silently.
    _say(AppStrings.studioStepOnWeb);
  }

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
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.s, 8.s, 16.s, 120.s),
            children: [
              _topRow(),
              SizedBox(height: 16.s),
              _greeting(),
              SizedBox(height: 20.s),
              if (_loading) ...[
                SizedBox(height: 60.s),
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandPrimary,
                  ),
                ),
              ] else ...[
                if (_isNew) ...[
                  GettingStartedCard(steps: _steps, onStep: _openStep),
                  SizedBox(height: 22.s),
                ],
                const StudioSectionLabel(AppStrings.studioToday),
                _statsRow(),
                if (!_isNew) ...[
                  SizedBox(height: 10.s),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // Per-item analytics live on the web studio: the
                      // mobile dashboard has today's four figures and no
                      // breakdown behind them (OPEN_ISSUES 18).
                      onTap: () => _say(AppStrings.studioWebAnalyticsNote),
                      child: Text(
                        AppStrings.studioFullAnalytics,
                        style: AppStyles.label(
                          12,
                          weight: AppStyles.bold,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 22.s),
                if (_attention.isNotEmpty) ...[
                  const StudioSectionLabel(AppStrings.studioNeedsYou),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.fieldBg,
                      borderRadius: BorderRadius.circular(12.s),
                    ),
                    child: Column(
                      children: [
                        for (final (i, item) in _attention.indexed)
                          AttentionRow(
                            item: item,
                            last: i == _attention.length - 1,
                            // Each key names one of the three Impact
                            // inboxes, so the row opens that tab. The note
                            // this replaces said there was no creator-side
                            // inbox to open; there is, and has been since
                            // Impact shipped.
                            onTap: () => _openAttention(item.key),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 22.s),
                ],
                if (_isNew) ...[
                  const StudioSectionLabel(AppStrings.studioCreateCaption),
                  _quickUpload(),
                  SizedBox(height: 22.s),
                ],
                const WebStudioNote(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _topRow() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: StudioPill(
          key: const ValueKey('studio-pill'),
          // Named off the membership row when the dashboard refused a
          // context, so the pill is not a blank, dead control.
          name: openStudio(_context, widget.studios)?.displayName ?? '',
          onTap: _openStudios,
        ),
      ),
      SizedBox(width: 12.s),
      GestureDetector(
        key: const ValueKey('studio-notifications'),
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const NotificationsScreen(),
            ),
          );
          if (mounted) setState(() {});
        },
        child: Container(
          width: 38.s,
          height: 38.s,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.fieldBg,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedNotification01,
                color: AppColors.textPrimary,
                size: 18.s,
              ),
              // The same store the member bell reads, so the two cannot
              // disagree about how many things are waiting.
              if (_notifications.hasUnread)
                Positioned(
                  right: -2.s,
                  top: -2.s,
                  child: Container(
                    width: 8.s,
                    height: 8.s,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _greeting() {
    // final name = _context?.firstName ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.studioWelcomeBack,
                // name.isEmpty
                //     ? AppStrings.studioWelcomePrefix.replaceAll(',', '')
                //     : '${AppStrings.studioWelcomePrefix} $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.heading(22, letterSpacing: -0.6),
              ),
              SizedBox(height: 4.s),
              Text(
                switch ((_loading, _isNew, _attention.length)) {
                  (true, _, _) => '',
                  (_, true, _) => AppStrings.studioReady,
                  (_, _, 0) => AppStrings.studioAllClear,
                  (_, _, final n) => AppStrings.studioNeedsYouCount(n),
                },
                style: AppStyles.body(
                  12,
                  color: AppColors.neutral400,
                  lineHeight: 16 / 12,
                ),
              ),
            ],
          ),
        ),
        // Search and Create belong to a studio that has something in it.
        if (!_isNew && !_loading) ...[
          SizedBox(width: 10.s),
          GestureDetector(
            key: const ValueKey('studio-search'),
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onOpenTab?.call(_contentTab, openSearch: true),
            child: Padding(
              padding: EdgeInsets.all(4.s),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                color: AppColors.textPrimary,
                size: 20.s,
              ),
            ),
          ),
          SizedBox(width: 10.s),
          GestureDetector(
            key: const ValueKey('studio-create'),
            behavior: HitTestBehavior.opaque,
            onTap: _openCreate,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 8.s),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999.s),
                border: Border.all(color: AppColors.brandPrimary),
              ),
              child: Text(
                AppStrings.studioCreate,
                style: AppStyles.label(
                  13,
                  weight: AppStyles.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _statsRow() {
    final views = _performance.views;
    final subs = _performance.subscribersGained;

    return Row(
      children: [
        Expanded(
          child: StudioStatCard(
            label: AppStrings.studioViews,
            value: _figure(views.value),
            change: _percent(views.changePercent),
          ),
        ),
        SizedBox(width: 10.s),
        Expanded(
          child: StudioStatCard(
            label: AppStrings.studioSubscribers,
            // The total, with the day's gain beside it — the gain alone
            // would read as "0 subscribers" on a studio that has plenty.
            value: _subscribers == null
                ? AppStrings.studioNoFigure
                : formatCount(_subscribers!),
            change: _plus(subs.value),
          ),
        ),
        SizedBox(width: 10.s),
        Expanded(
          child: StudioStatCard(
            // Nothing in the spec returns a giving figure for a studio with
            // no payment setup — `earnings/summary` answers 500 — so it shows
            // a dash until Giving is wired.
            label: AppStrings.studioGiving,
            value: AppStrings.studioNoFigure,
          ),
        ),
      ],
    );
  }

  static String _figure(double value) =>
      value <= 0 ? AppStrings.studioNoFigure : formatCount(value.round());

  static String? _percent(double? change) {
    if (change == null || change == 0) return null;
    final rounded = change.round();
    return '${rounded > 0 ? '+' : ''}$rounded%';
  }

  static String? _plus(double? delta) {
    if (delta == null || delta == 0) return null;
    final rounded = delta.round();
    return '${rounded > 0 ? '+' : ''}$rounded';
  }

  Widget _quickUpload() => GestureDetector(
    key: const ValueKey('studio-quick-upload'),
    behavior: HitTestBehavior.opaque,
    onTap: _openCreate,
    child: Container(
      height: 96.s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(12.s),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCloudUpload,
            color: AppColors.brandPrimary,
            size: 22.s,
          ),
          SizedBox(height: 8.s),
          Text(
            AppStrings.studioQuickUpload,
            style: AppStyles.label(14, weight: AppStyles.bold),
          ),
        ],
      ),
    ),
  );
}
