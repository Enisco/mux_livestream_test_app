import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/studio_content_repo.dart';
import 'package:test_app/features/creator/views/go_live_setup_screen.dart';
import 'package:test_app/features/creator/views/new_article_screen.dart';
import 'package:test_app/features/creator/views/new_event_screen.dart';
import 'package:test_app/features/creator/views/new_media_screen.dart';
import 'package:test_app/features/creator/views/studio_content_detail_screen.dart';
import 'package:test_app/features/creator/views/widgets/studio_content_parts.dart';
import 'package:test_app/features/creator/views/widgets/studio_parts.dart';
import 'package:test_app/features/creator/views/widgets/studio_sheets.dart';
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/models/creator_models/studio_content_models.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Everything the creator has made, in one list.
///
/// Three services hold it — media, posts and calendar events — and the chips
/// pick between them. "All" asks all three and interleaves by recency, which
/// is the only way to span them: no single route does.
///
/// Rows are real; see [StudioContentRepo] for the filter dialect.
class StudioContentScreen extends StatefulWidget {
  const StudioContentScreen({super.key, this.context});

  /// The studio being worked in. Supplied by the shell so the Create sheet
  /// can be gated on the same capabilities the Studio tab uses.
  final DashboardContext? context;

  @override
  State<StudioContentScreen> createState() => _StudioContentScreenState();
}

class _StudioContentScreenState extends State<StudioContentScreen> {
  final _repo = StudioContentRepo();
  final _searchController = TextEditingController();

  StudioContentKind? _kind;
  StudioContentPage _page = StudioContentPage.empty;
  bool _loading = true;
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final creatorId = LocalStorage.creatorId;
    if (creatorId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final page = await _repo.fetch(creatorId: creatorId, kind: _kind);
    if (!mounted) return;
    setState(() {
      _page = page;
      _loading = false;
    });
  }

  /// Typing narrows what has already been fetched. The dashboard has a search
  /// route (`/dashboard/search`) but it spans the whole studio rather than
  /// this list, so it is not what the chips filter.
  List<StudioContentItem> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _page.items;
    return _page.items
        .where((i) => i.title.toLowerCase().contains(q))
        .toList(growable: false);
  }

  void _report(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openCreate() async {
    final studio = widget.context;
    final allowed = [
      for (final kind in CreateKind.values)
        if (studio == null || studio.can(kind.capability)) kind,
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
      if (went ?? false) await _load();
      return;
    }
    if (picked == CreateKind.blog) {
      final made = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const NewArticleScreen()),
      );
      if (made ?? false) await _load();
      return;
    }
    if (picked == CreateKind.event) {
      final made = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const NewEventScreen()),
      );
      if (made ?? false) await _load();
      return;
    }
    if (kind != null) {
      final made = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => NewMediaScreen(kind: kind)),
      );
      if (made ?? false) await _load();
      return;
    }
    _report('${picked.title} is not built yet');
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    final narrowed = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.s, 8.s, 16.s, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: StudioPill(
                          name: widget.context?.displayName ?? '',
                          onTap: () => _report(AppStrings.studiosSwitch),
                        ),
                      ),
                      SizedBox(width: 12.s),
                      _RoundButton(
                        buttonKey: const ValueKey('content-notifications'),
                        icon: HugeIcons.strokeRoundedNotification01,
                        onTap: () => _report('Notifications'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.s),
                  _titleRow(),
                  if (_searching) ...[
                    SizedBox(height: 12.s),
                    LibrarySearchField(
                      controller: _searchController,
                      hint: AppStrings.contentSearchHint,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ],
                  SizedBox(height: 14.s),
                  StudioContentChips(
                    selected: _kind,
                    onSelected: (kind) {
                      setState(() => _kind = kind);
                      _load();
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 6.s),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : items.isEmpty
                  ? _empty(narrowed)
                  : RefreshIndicator(
                      color: AppColors.brandPrimary,
                      backgroundColor: AppColors.base1,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(16.s, 6.s, 16.s, 120.s),
                        itemCount: items.length,
                        itemBuilder: (context, i) => StudioContentRow(
                          item: items[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  StudioContentDetailScreen(item: items[i]),
                            ),
                          ),
                          onAction: () => _report(
                            items[i].isDraft
                                ? AppStrings.contentEdit
                                : AppStrings.contentShare,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleRow() => Row(
    children: [
      Expanded(
        child: Text(
          AppStrings.studioTabContent,
          style: AppStyles.heading(22, letterSpacing: -0.6),
        ),
      ),
      _RoundButton(
        buttonKey: const ValueKey('content-search'),
        icon: HugeIcons.strokeRoundedSearch01,
        bare: true,
        onTap: () => setState(() {
          _searching = !_searching;
          if (!_searching) {
            _searchController.clear();
            _query = '';
          }
        }),
      ),
      SizedBox(width: 6.s),
      GestureDetector(
        key: const ValueKey('content-create'),
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
  );

  Widget _empty(bool narrowed) => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: Column(
      children: [
        LibraryEmptyState(
          icon: HugeIcons.strokeRoundedLayers01,
          title: narrowed
              ? AppStrings.libraryNoMatchTitle
              : AppStrings.contentEmptyTitle,
          body: narrowed
              ? AppStrings.libraryNoMatchBody
              : AppStrings.contentEmptyBody,
        ),
        if (!narrowed)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 60.s),
            child: PrimaryButton(
              label: AppStrings.contentCreate,
              height: 48,
              onPressed: _openCreate,
            ),
          ),
      ],
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.buttonKey,
    required this.icon,
    required this.onTap,
    this.bare = false,
  });

  final Key buttonKey;
  final List<List<dynamic>> icon;
  final VoidCallback onTap;

  /// The search glyph sits bare beside the title; the bell sits on a disc.
  final bool bare;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: buttonKey,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: bare ? 34.s : 38.s,
      height: bare ? 34.s : 38.s,
      alignment: Alignment.center,
      decoration: bare
          ? null
          : const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.fieldBg,
            ),
      child: HugeIcon(
        icon: icon,
        color: AppColors.textPrimary,
        size: bare ? 20.s : 18.s,
      ),
    ),
  );
}
