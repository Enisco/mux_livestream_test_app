import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/content_asset_repo.dart';
import 'package:test_app/features/creator/repo/post_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/features/creator/views/widgets/go_live_sheet.dart';
import 'package:test_app/features/creator/views/widgets/markdown_body.dart';
import 'package:test_app/features/creator/views/widgets/new_article_parts.dart';
import 'package:test_app/features/creator/views/widgets/new_event_parts.dart';
import 'package:test_app/features/creator/views/widgets/new_media_parts.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/models/creator_models/post_draft_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Writing an article.
///
/// Markdown in, markdown out: the body is stored as GFM and the Preview tab
/// renders it with [MarkdownBody]. Nothing is uploaded to Mux — the cover
/// and every inline picture go through the content service's own image
/// ticket, and the picture only resolves once a saved post names it, which
/// is why an unsaved draft previews inline images as placeholders.
///
/// Unlike an event, an article **can** be scheduled, so the go-live sheet
/// is offered here exactly as the design shows.
class NewArticleScreen extends StatefulWidget {
  const NewArticleScreen({super.key, this.creatorId, this.posts});

  /// Defaults to the signed-in creator.
  final String? creatorId;

  /// Defaults to the real thing; a test supplies its own.
  final PostRepo? posts;

  @override
  State<NewArticleScreen> createState() => _NewArticleScreenState();
}

class _NewArticleScreenState extends State<NewArticleScreen> {
  late final _repo = widget.posts ?? PostRepo();

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _previewing = false;
  bool _working = false;

  PickedImage? _cover;
  String? _coverFileId;

  /// Pictures the API has confirmed, so the preview can show them.
  List<BodyEmbed> _embeds = const [];
  Timer? _resolveDebounce;

  String? get _creatorId => widget.creatorId ?? LocalStorage.creatorId;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTyped);
    _bodyController.addListener(_onBodyTyped);
  }

  @override
  void dispose() {
    _resolveDebounce?.cancel();
    _titleController.removeListener(_onTyped);
    _bodyController.removeListener(_onBodyTyped);
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onTyped() => setState(() {});

  void _onBodyTyped() {
    setState(() {});
    // Resolving on every keystroke would be one call per letter.
    _resolveDebounce?.cancel();
    _resolveDebounce = Timer(const Duration(milliseconds: 600), _resolve);
  }

  Future<void> _resolve() async {
    final creatorId = _creatorId;
    final body = _bodyController.text;
    if (creatorId == null || !body.contains('file:')) {
      if (_embeds.isNotEmpty && mounted) setState(() => _embeds = const []);
      return;
    }
    final embeds = await _repo.resolveEmbeds(creatorId: creatorId, body: body);
    if (!mounted) return;
    setState(() => _embeds = embeds);
  }

  PostDraft get _draft => PostDraft(
    title: _titleController.text.trim(),
    body: _bodyController.text.trim(),
    coverThumbnailFileId: _coverFileId,
  );

  bool get _canPublish => _draft.publishBlock == null;

  /// A draft needs a headline; the API refuses the post without one.
  bool get _canSave => _titleController.text.trim().isNotEmpty;

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---- pictures ----------------------------------------------------------

  Future<void> _pickCover() async {
    final image = await _pickImage();
    if (image == null) return;
    setState(() {
      _cover = image;
      _coverFileId = null;
    });
  }

  /// An inline picture is uploaded straight away: the markdown token needs
  /// its `fileId`, and there is nowhere else to keep the bytes.
  Future<void> _insertImage() async {
    final creatorId = _creatorId;
    final image = await _pickImage();
    if (image == null || creatorId == null) return;

    setState(() => _working = true);
    try {
      final fileId = await _repo.uploadImage(
        creatorId: creatorId,
        kind: ContentAssetKind.bodyImage,
        image: image,
      );
      if (!mounted) return;
      insertMarkdownImage(_bodyController, fileId: fileId, alt: '');
    } on PostException catch (e) {
      if (mounted) _say(_wording(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<PickedImage?> _pickImage() async {
    final result = await CreatorImagePicker.pick(
      maxBytes: PostRepo.coverMaxBytes,
    );
    if (!mounted || result.isCancelled) return null;

    switch (result.failure) {
      case PickFailure.tooLarge:
        _say(AppStrings.newEventCoverTooLarge);
      case PickFailure.unreadable:
      case PickFailure.unsupported:
        _say(AppStrings.newMediaThumbUnreadable);
      case null:
        return result.image;
    }
    return null;
  }

  Future<void> _onTool(MarkdownTool tool) async {
    if (tool != MarkdownTool.link) {
      applyMarkdownTool(_bodyController, tool);
      return;
    }
    final href = await askForLink(context);
    if (href == null || href.isEmpty || !mounted) return;
    applyMarkdownTool(_bodyController, tool);
    // The tool leaves `[text](https://)`; point it at what was asked for.
    _bodyController.text = _bodyController.text.replaceFirst(
      '](https://)',
      ']($href)',
    );
  }

  // ---- filing it ---------------------------------------------------------

  Future<void> _publish() async {
    final choice = await GoLiveSheet.show(context);
    if (!mounted || choice == null) return;
    await _commit(choice);
  }

  Future<void> _saveDraft() => _commit(const PublishChoice.draft());

  Future<void> _commit(PublishChoice choice) async {
    final creatorId = _creatorId;
    if (creatorId == null) return _say(AppStrings.newMediaRejected);
    if (_titleController.text.trim().length > 500) {
      return _say(AppStrings.articleTitleTooLong);
    }

    setState(() => _working = true);
    try {
      _coverFileId ??= _cover == null
          ? null
          : await _repo.uploadImage(
              creatorId: creatorId,
              kind: ContentAssetKind.cover,
              image: _cover!,
            );

      final id = await _repo.create(creatorId: creatorId, draft: _draft);

      // Scheduling is a PATCH; create refuses `scheduledAt` outright.
      switch (choice.timing) {
        case PublishTiming.now:
          await _repo.publish(id);
        case PublishTiming.schedule:
          await _repo.schedule(postId: id, at: choice.at!);
        case PublishTiming.draft:
          break;
      }

      if (!mounted) return;
      setState(() => _working = false);
      await PublishedCard.show(
        context,
        title: switch (choice.timing) {
          PublishTiming.now => AppStrings.newArticleLiveTitle,
          PublishTiming.schedule => AppStrings.newArticleScheduledTitle,
          PublishTiming.draft => AppStrings.newMediaDraftTitle,
        },
        body: switch (choice.timing) {
          PublishTiming.now => AppStrings.newArticleLiveBody,
          PublishTiming.schedule =>
            'It goes live on ${formatSheetDate(choice.at!)} '
                'at ${formatSheetTime(choice.at!)}.',
          PublishTiming.draft => AppStrings.newMediaDraftBody,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      _say(_wording(e));
    }
  }

  static String _wording(PostException e) => switch (e.failure) {
    PostFailure.needsTitle => AppStrings.articleNeedsTitle,
    PostFailure.needsBody => AppStrings.articleNeedsBody,
    PostFailure.scheduleInPast => AppStrings.newMediaSchedulePast,
    PostFailure.network => AppStrings.newMediaNetwork,
    PostFailure.rejected => e.message ?? AppStrings.newMediaRejected,
  };

  // ---- the screen --------------------------------------------------------

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.base1,
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.s, 8.s, 20.s, 0),
            child: const CreatorFlowHeader(
              title: AppStrings.newArticleTitle,
              subtitle: AppStrings.newArticleSubtitle,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.s, 14.s, 20.s, 0),
            child: WritePreviewTabs(
              previewing: _previewing,
              onChanged: (on) {
                setState(() => _previewing = on);
                if (on) _resolve();
              },
            ),
          ),
          Expanded(child: _previewing ? _preview() : _editor()),
          _actions(context),
        ],
      ),
    ),
  );

  Widget _editor() => ListView(
    padding: EdgeInsets.fromLTRB(20.s, 16.s, 20.s, 20.s),
    children: [
      const RequiredLabel(AppStrings.articleCover, required: false),
      SizedBox(height: 8.s),
      ThumbnailWell(
        image: _cover,
        onPick: _pickCover,
        emptyLabel: AppStrings.articleAddCover,
      ),
      SizedBox(height: 16.s),
      CreatorTextField(
        key: const ValueKey('article-title'),
        controller: _titleController,
        hint: AppStrings.articleTitleHint,
      ),
      const FieldNote(AppStrings.articleTitleNote),
      SizedBox(height: 14.s),
      CreatorTextField(
        key: const ValueKey('article-body'),
        controller: _bodyController,
        hint: AppStrings.articleBodyHint,
        maxLines: 14,
      ),
    ],
  );

  /// What a reader would get. The counts the design shows beside the read
  /// time — opens, and how long ago it went out — belong to a post that has
  /// been published; a new one has neither, so it says so instead
  /// (OPEN_ISSUES 33).
  Widget _preview() => ListView(
    padding: EdgeInsets.fromLTRB(20.s, 16.s, 20.s, 20.s),
    children: [
      if (_cover case final cover?)
        ClipRRect(
          borderRadius: BorderRadius.circular(10.s),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.memory(cover.bytes, fit: BoxFit.cover),
          ),
        ),
      SizedBox(height: 14.s),
      Text(
        _titleController.text.trim().isEmpty
            ? AppStrings.articleTitleHint
            : _titleController.text.trim(),
        style: AppStyles.heading(22, letterSpacing: -0.6),
      ),
      SizedBox(height: 8.s),
      Text(
        '${AppStrings.articleDraftBadge} · '
        '${_draft.readMinutes} ${AppStrings.articleReadSuffix}',
        style: AppStyles.label(12, color: AppColors.neutral500),
      ),
      SizedBox(height: 16.s),
      MarkdownBody(source: _bodyController.text, embeds: _embeds),
    ],
  );

  Widget _actions(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      20.s,
      10.s,
      20.s,
      10.s + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: const BoxDecoration(
      color: AppColors.base1,
      border: Border(top: BorderSide(color: AppColors.neutral900)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_previewing)
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.articlePreviewNote,
                  style: AppStyles.label(
                    12,
                    color: AppColors.neutral400,
                    lineHeight: 16 / 12,
                  ),
                ),
              ),
              SizedBox(width: 12.s),
              _publishButton(),
            ],
          )
        else
          MarkdownToolbar(
            onTool: _onTool,
            onImage: _insertImage,
            action: _publishButton(),
          ),
        SizedBox(height: 10.s),
        GestureDetector(
          key: const ValueKey('article-draft'),
          behavior: HitTestBehavior.opaque,
          onTap: _canSave && !_working ? _saveDraft : null,
          child: Text(
            AppStrings.newMediaSaveDraft,
            style: AppStyles.label(
              13,
              color: _canSave ? AppColors.neutral200 : AppColors.neutral500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _publishButton() => SizedBox(
    width: 120.s,
    child: PrimaryButton(
      key: const ValueKey('article-publish'),
      label: AppStrings.articlePublish,
      height: 44.s,
      enabled: _canPublish,
      loading: _working,
      onPressed: _publish,
    ),
  );
}
