import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/creator_dashboard_repo.dart';
import 'package:test_app/features/creator/views/widgets/studio_parts.dart';
import 'package:test_app/features/creator/views/go_live_setup_screen.dart';
import 'package:test_app/features/creator/views/new_article_screen.dart';
import 'package:test_app/features/creator/views/new_event_screen.dart';
import 'package:test_app/features/creator/views/new_media_screen.dart';
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
  const StudioScreen({super.key, this.onLeaveStudio});

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
  }

  Future<void> _load() async {
    final creatorId = LocalStorage.creatorId;
    if (creatorId == null) {
      setState(() => _loading = false);
      return;
    }

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

  void _todo(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$what is not built yet', style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openStudios() async {
    final current = _context;
    if (current == null) return;
    final choice = await StudiosSheet.show(context, current: current);
    if (!mounted || choice == null) return;
    switch (choice) {
      case StudiosChoice.switchStudio:
        // No route returns the studios a user belongs to yet; the backend
        // will publish one. See OPEN_ISSUES 14.
        _say(AppStrings.studiosNotImplemented);
      case StudiosChoice.settings:
        _todo(AppStrings.studiosSettings);
      case StudiosChoice.backToWatching:
        widget.onLeaveStudio?.call();
    }
  }

  Future<void> _openCreate() async {
    final current = _context;
    final allowed = [
      for (final kind in CreateKind.values)
        if (current == null || current.can(kind.capability)) kind,
    ];
    final picked = await CreateSheet.show(context, kinds: allowed);
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
    _todo(picked.title);
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
                  GettingStartedCard(
                    steps: _steps,
                    onStep: (step) => _todo(
                      AppStrings.studioStepTitles[step.key] ?? step.key,
                    ),
                  ),
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
                      onTap: () => _todo(AppStrings.studioFullAnalytics),
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
                            onTap: () => _todo(item.key),
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
          name: _context?.displayName ?? '',
          onTap: _openStudios,
        ),
      ),
      SizedBox(width: 12.s),
      GestureDetector(
        key: const ValueKey('studio-notifications'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _todo('Notifications'),
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

  Widget _greeting() {
    final name = _context?.firstName ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.isEmpty
                    ? AppStrings.studioWelcomePrefix.replaceAll(',', '')
                    : '${AppStrings.studioWelcomePrefix} $name',
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
            onTap: () => _todo('Studio search'),
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
