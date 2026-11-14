import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/content_asset_repo.dart';
import 'package:test_app/features/creator/repo/post_repo.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount;
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/features/creator/views/widgets/go_live_sheet.dart';
import 'package:test_app/shared/components/markdown_body.dart';
import 'package:test_app/features/creator/views/widgets/new_article_parts.dart';
import 'package:test_app/features/creator/views/widgets/new_event_parts.dart';
import 'package:test_app/features/creator/views/widgets/new_media_parts.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/models/creator_models/post_draft_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';
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
///
/// The same screen **edits** an article that already exists: pass
/// [editPostId] and it opens what is filed, saves with
/// `PATCH /v1/content/posts/{id}`, and leaves the publishing state alone —
/// a creator fixing a typo in a published post expects it to stay
/// published, and one tidying a draft expects it to stay a draft.
class NewArticleScreen extends StatefulWidget {
  const NewArticleScreen({
    super.key,
    this.creatorId,
    this.posts,
    this.editPostId,
  });

  /// Defaults to the signed-in creator.
  final String? creatorId;

  /// Defaults to the real thing; a test supplies its own.
  final PostRepo? posts;

  /// The article to open and correct. Null writes a new one.
  final String? editPostId;

  @override
  State<NewArticleScreen> createState() => _NewArticleScreenState();
}

class _NewArticleScreenState extends State<NewArticleScreen> {
  late final _repo = widget.posts ?? PostRepo();

  /// The channel this goes out as, so the preview's byline is the real one.
  CreatorByline? _byline;

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _previewing = false;
  bool _working = false;

  PickedImage? _cover;
  String? _coverFileId;

  /// Pictures the API has confirmed, so the preview can show them.
  List<BodyEmbed> _embeds = const [];
  Timer? _resolveDebounce;

  /// The article as it is filed, when this screen is editing one.
  ///
  /// Kept whole rather than torn into controllers because the editor shows
  /// a headline, a body and a cover — not the excerpt, the categories or
  /// the visibility. A PATCH built from the controllers alone would send
  /// those back empty and quietly wipe them.
  PostDraft? _filed;

  /// Where the already-saved cover is, so the well shows it.
  String? _coverUrl;

  bool _loading = false;
  bool _loadFailed = false;

  bool get _editing => widget.editPostId != null;

  String? get _creatorId => widget.creatorId ?? LocalStorage.creatorId;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTyped);
    unawaited(_loadByline());
    _bodyController.addListener(_onBodyTyped);
    if (widget.editPostId case final id?) unawaited(_open(id));
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

  /// Opens what is already filed.
  Future<void> _open(String postId) async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final filed = await _repo.load(postId);
      if (!mounted) return;
      setState(() {
        _filed = filed.draft;
        _titleController.text = filed.draft.title;
        _bodyController.text = filed.draft.body;
        _coverFileId = filed.draft.coverThumbnailFileId;
        _coverUrl = AssetUrlResolver.resolve(filed.coverKey);
        _loading = false;
      });
      unawaited(_resolve());
    } on PostException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
      _say(_wording(e));
    }
  }

  Future<void> _loadByline() async {
    // A byline that cannot be read costs the byline, not the editor.
    final byline = await CreatorRepo().fetchByline();
    if (mounted) setState(() => _byline = byline);
  }

  /// What the editor has, over what is already filed.
  ///
  /// `copyWith` over [_filed] rather than a fresh [PostDraft]: the excerpt,
  /// the categories and the visibility are not on this screen, and a PATCH
  /// built without them would clear all three.
  PostDraft get _draft => (_filed ?? const PostDraft(title: '')).copyWith(
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

  /// Saving an edit. One PATCH, and nothing about publishing.
  Future<void> _saveEdit() async {
    final postId = widget.editPostId;
    final creatorId = _creatorId;
    if (postId == null) return;
    // A new cover has to be uploaded before it can be named, and that
    // needs a creator. Going ahead without one would save every other
    // change and drop the picture without saying so.
    if (_cover != null && creatorId == null) {
      return _say(AppStrings.newMediaRejected);
    }
    if (_titleController.text.trim().length > 500) {
      return _say(AppStrings.articleTitleTooLong);
    }

    setState(() => _working = true);
    try {
      // A cover picked during this edit has not been uploaded yet; one
      // that came with the article already has a file id.
      if (_cover case final picked? when creatorId != null) {
        _coverFileId = await _repo.uploadImage(
          creatorId: creatorId,
          kind: ContentAssetKind.cover,
          image: picked,
        );
      }
      await _repo.update(postId: postId, draft: _draft);
      if (!mounted) return;
      setState(() => _working = false);
      _say(AppStrings.editSaved);
      Navigator.pop(context, true);
    } on PostException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      _say(_wording(e));
    }
  }

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
            child: CreatorFlowHeader(
              title: _editing
                  ? AppStrings.editArticleTitle
                  : AppStrings.newArticleTitle,
              subtitle: _editing
                  ? AppStrings.editArticleSubtitle
                  : AppStrings.newArticleSubtitle,
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

  Widget _editor() {
    if (_loading) {
      return const Center(
        key: ValueKey('article-opening'),
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }
    if (_loadFailed) {
      return Center(
        key: const ValueKey('article-open-failed'),
        child: Padding(
          padding: EdgeInsets.all(24.s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.editCouldNotOpen,
                textAlign: TextAlign.center,
                style: AppStyles.body(14, color: AppColors.neutral400),
              ),
              SizedBox(height: 14.s),
              SizedBox(
                width: 150.s,
                child: PrimaryButton(
                  key: const ValueKey('article-open-retry'),
                  label: AppStrings.feedRetry,
                  height: 44.s,
                  onPressed: () => unawaited(_open(widget.editPostId!)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _form();
  }

  Widget _form() => ListView(
    padding: EdgeInsets.fromLTRB(20.s, 16.s, 20.s, 20.s),
    children: [
      const RequiredLabel(AppStrings.articleCover, required: false),
      SizedBox(height: 8.s),
      ThumbnailWell(
        image: _cover,
        existingUrl: _coverUrl,
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

  /// What a reader would get.
  ///
  /// Every figure here is the true one for a post being written. The design's
  /// meta line reads "12.9K Opens · 2 min read · 6 hours ago"; two of those
  /// three belong to a post that already exists, and a draft has neither an
  /// audience nor a publication date. Putting a fabricated number in front of
  /// the creator would be worse than saying so, so the line says what is
  /// actually true and the read time — words over two hundred, image tokens
  /// excluded — is real and updates as they type.
  ///
  /// The byline **is** real and available, so it is shown: the channel's
  /// avatar, name and tick, exactly as a reader would see them.
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
        )
      else if (_coverUrl case final url?)
        ClipRRect(
          borderRadius: BorderRadius.circular(10.s),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      SizedBox(height: 14.s),
      Text(
        _titleController.text.trim().isEmpty
            ? AppStrings.articleTitleHint
            : _titleController.text.trim(),
        style: AppStyles.heading(22, letterSpacing: -0.6),
      ),
      if (_byline case final byline?) ...[
        SizedBox(height: 12.s),
        _PreviewByline(byline: byline),
      ],
      SizedBox(height: 8.s),
      Text(
        '${_editing ? AppStrings.editEditing : AppStrings.articleDraftBadge} · '
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
              _actionButton(),
            ],
          )
        else
          // The toolbar belongs to editing just as much as to writing:
          // dropping it in edit mode would leave a creator correcting an
          // article with no bold, no link and no way to add a picture.
          MarkdownToolbar(
            onTool: _onTool,
            onImage: _insertImage,
            action: _actionButton(),
          ),
        if (!_editing) SizedBox(height: 10.s),
        if (!_editing)
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

  /// What the toolbar's right-hand end does: file a new article, or save
  /// the edit of one that exists.
  Widget _actionButton() => _editing
      ? SizedBox(
          width: 140.s,
          child: PrimaryButton(
            key: const ValueKey('article-save-edit'),
            label: AppStrings.editSaveChanges,
            height: 44.s,
            enabled: _canSave && !_loading && !_loadFailed,
            loading: _working,
            onPressed: _saveEdit,
          ),
        )
      : SizedBox(
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

/// The channel a post goes out as, under the preview's headline.
class _PreviewByline extends StatelessWidget {
  const _PreviewByline({required this.byline});

  final CreatorByline byline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16.s,
          backgroundColor: AppColors.neutral800,
          backgroundImage: byline.avatarUrl == null
              ? null
              : NetworkImage(byline.avatarUrl!),
          child: byline.avatarUrl != null
              ? null
              : Icon(
                  Icons.person_rounded,
                  size: 18.s,
                  color: AppColors.neutral500,
                ),
        ),
        SizedBox(width: 10.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      byline.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.label(14, weight: AppStyles.semiBold),
                    ),
                  ),
                  if (byline.verified) ...[
                    SizedBox(width: 5.s),
                    DesignIcon(
                      AppAssets.iconFeedVerified,
                      width: 13.s,
                      height: 13.s,
                    ),
                  ],
                ],
              ),
              Text(
                byline.subscriberCount > 0
                    ? '${byline.handle} · '
                          '${formatCount(byline.subscriberCount)} '
                          '${AppStrings.subscribersLabel}'
                    : byline.handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.body(12, color: AppColors.neutral500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
