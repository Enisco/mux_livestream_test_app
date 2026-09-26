import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/repo/media_upload_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/creator/services/creator_media_picker.dart';
import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/features/creator/views/widgets/creator_topics_sheet.dart';
import 'package:test_app/features/creator/views/widgets/go_live_sheet.dart';
import 'package:test_app/features/creator/views/widgets/new_media_parts.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Uploading a video, or a piece of audio.
///
/// The two designs are the same screen: the copy, the ceiling and the tile
/// on the file card differ, and nothing else does. Both take the same four
/// calls, which is why they share one [MediaUploadRepo].
///
/// Neither is Go Live. These are files that go to Mux over HTTP and are
/// transcoded; a livestream is provisioned and broadcast over RTMP, and the
/// API refuses to let one be created as the other.
///
/// The bytes start moving the moment a file is chosen, so the form is filled
/// in while the upload runs — which is what the design shows. Publishing
/// waits for the bytes to land: the API would accept the row sooner, but
/// leaving the screen mid-upload would then strand it with nothing coming.
class NewMediaScreen extends StatefulWidget {
  const NewMediaScreen({
    super.key,
    required this.kind,
    this.creatorId,
    this.uploads,
    this.creators,
  });

  /// Video or audio. `music` is the API's word for what the design and the
  /// studio both call Audio.
  final MediaUploadKind kind;

  /// Defaults to the signed-in creator.
  final String? creatorId;

  /// Both default to the real thing; a test supplies its own.
  final MediaUploadRepo? uploads;
  final CreatorRepo? creators;

  @override
  State<NewMediaScreen> createState() => _NewMediaScreenState();
}

class _NewMediaScreenState extends State<NewMediaScreen> {
  bool get _audio => widget.kind.isAudio;

  late final _repo = widget.uploads ?? MediaUploadRepo();
  late final _creators = widget.creators ?? CreatorRepo();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  PickedMediaFile? _file;
  MediaUploadTicket? _ticket;
  CancelToken? _cancel;

  /// Bytes on the wire, and the future that finishes when they all are.
  int _sent = 0;
  Future<void>? _upload;
  bool _uploadFailed = false;

  PickedImage? _thumbnail;
  String? _thumbnailFileId;

  List<ContentCategory> _categories = const [];
  Set<String> _chosenCategories = {};

  bool _working = false;

  String? get _creatorId => widget.creatorId ?? LocalStorage.creatorId;

  @override
  void initState() {
    super.initState();
    // The primary button turns on as the last required field is filled, so
    // the form has to rebuild while the creator types.
    _titleController.addListener(_onTyped);
    _descriptionController.addListener(_onTyped);
    _loadCategories();
  }

  void _onTyped() => setState(() {});

  @override
  void dispose() {
    _cancel?.cancel('left the screen');
    _titleController.removeListener(_onTyped);
    _descriptionController.removeListener(_onTyped);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// The category list is a nicety: without it the sheet falls back to the
  /// slugs the API publishes, so a failure here is not worth a message.
  Future<void> _loadCategories() async {
    try {
      final categories = await _creators.fetchCategories();
      if (!mounted || categories.isEmpty) return;
      setState(() => _categories = categories);
    } catch (e) {
      logger.w('Could not load categories', error: e);
    }
  }

  /// Everything the form needs before anything can be published. The
  /// thumbnail is on this list because the design marks it required, though
  /// the API would happily fall back to a Mux-generated still.
  bool get _complete =>
      _file != null &&
      !_uploadFailed &&
      _thumbnail != null &&
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty;

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

  // ---- choosing the file -------------------------------------------------

  Future<void> _pickFile() async {
    final result = await CreatorMediaPicker.pick(kind: widget.kind);
    if (!mounted || result.isCancelled) return;

    if (result.failure case final failure?) {
      _say(_wording(failure));
      return;
    }

    final file = result.file!;
    // Swapping the file mid-upload has to stop the old one; otherwise its
    // bytes keep going to a ticket nothing will ever reference.
    _cancel?.cancel('replaced');
    setState(() {
      _file = file;
      _sent = 0;
      _ticket = null;
      _uploadFailed = false;
    });
    _upload = _startUpload(file);
  }

  /// Mints the ticket and pushes the bytes, keeping the card's percentage
  /// honest as it goes.
  Future<void> _startUpload(PickedMediaFile file) async {
    final creatorId = _creatorId;
    if (creatorId == null) {
      setState(() => _uploadFailed = true);
      _say(AppStrings.newMediaRejected);
      return;
    }

    final cancel = CancelToken();
    _cancel = cancel;
    try {
      final ticket = await _repo.requestUpload(
        creatorId: creatorId,
        kind: widget.kind,
        file: file,
      );
      if (!mounted) return;
      setState(() => _ticket = ticket);

      await _repo.putFile(
        ticket: ticket,
        file: file,
        cancelToken: cancel,
        onProgress: (sent, _) {
          // The pick may have been swapped out from under a slow upload.
          if (!mounted || _file != file) return;
          // Dio reports every chunk; the card only shows whole percents, and
          // a gigabyte's worth of rebuilds would be wasted on nothing.
          if (_percent(sent, file.size) == _percent(_sent, file.size)) return;
          setState(() => _sent = sent);
        },
      );
      if (!mounted || _file != file) return;
      setState(() => _sent = file.size);
    } on MediaUploadException catch (e) {
      if (!mounted || e.failure == MediaUploadFailure.cancelled) return;
      setState(() => _uploadFailed = true);
      _say(_explain(e));
    }
  }

  static int _percent(int sent, int total) =>
      total <= 0 ? 0 : ((sent / total) * 100).floor();

  void _removeFile() {
    _cancel?.cancel('removed');
    _cancel = null;
    setState(() {
      _file = null;
      _ticket = null;
      _upload = null;
      _sent = 0;
      _uploadFailed = false;
    });
  }

  // ---- the thumbnail -----------------------------------------------------

  Future<void> _pickThumbnail() async {
    final result = await CreatorImagePicker.pick(maxBytes: _thumbnailMaxBytes);
    if (!mounted || result.isCancelled) return;

    switch (result.failure) {
      case PickFailure.tooLarge:
        _say(AppStrings.newMediaThumbTooLarge);
      case PickFailure.unreadable:
      case PickFailure.unsupported:
        _say(AppStrings.newMediaThumbUnreadable);
      case null:
        setState(() {
          _thumbnail = result.image;
          // A new picture needs a new file id.
          _thumbnailFileId = null;
        });
    }
  }

  /// `POST /v1/media/thumbnail/upload-url` answers
  /// `constraints.maxSizeBytes: 10485760` and accepts JPEG, PNG and WebP —
  /// a looser ceiling than the banner's, and its own.
  static const _thumbnailMaxBytes = 10 * 1024 * 1024;

  Future<void> _pickCategories() async {
    final picked = await CreatorTopicsSheet.show(
      context,
      categories: _categories,
      selected: _chosenCategories,
    );
    if (!mounted || picked == null) return;
    if (picked.length > 8) {
      _say(AppStrings.newMediaCategoryMax);
      return;
    }
    setState(() => _chosenCategories = picked);
  }

  String get _categoryValue {
    if (_chosenCategories.isEmpty) return '';
    final names = [
      for (final slug in _chosenCategories)
        _categories
                .where((c) => c.slug == slug)
                .map((c) => c.name)
                .firstOrNull ??
            slug,
    ];
    return names.join(', ');
  }

  // ---- publishing --------------------------------------------------------

  Future<void> _publish() async {
    final choice = await GoLiveSheet.show(context);
    if (!mounted || choice == null) return;
    await _commit(choice);
  }

  Future<void> _saveDraft() => _commit(const PublishChoice.draft());

  Future<void> _commit(PublishChoice choice) async {
    final creatorId = _creatorId;
    final file = _file;
    if (creatorId == null || file == null) {
      _say(AppStrings.newMediaNeedsFile);
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.length > 180) return _say(AppStrings.newMediaTitleTooLong);
    if (description.length > 5000) {
      return _say(AppStrings.newMediaDescriptionTooLong);
    }

    setState(() => _working = true);
    try {
      // Wait for the bytes. The API would take the row now, but a half-sent
      // file with nobody on the screen to finish it helps no one.
      await _upload;
      if (_uploadFailed || _ticket == null) {
        throw const MediaUploadException(MediaUploadFailure.rejected);
      }

      _thumbnailFileId ??= _thumbnail == null
          ? null
          : await _repo.uploadThumbnail(
              creatorId: creatorId,
              image: _thumbnail!,
            );

      // A draft stays private; anything going out is public — the design
      // offers no third choice here.
      final visibility = choice.timing == PublishTiming.draft
          ? MediaVisibility.private
          : MediaVisibility.public;

      final mediaId = await _repo.createMedia(
        creatorId: creatorId,
        kind: widget.kind,
        uploadId: _ticket!.uploadId,
        title: title,
        description: description,
        categorySlugs: _chosenCategories.toList(growable: false),
        thumbnailFileId: _thumbnailFileId,
        visibility: visibility,
        scheduledAt: choice.at,
      );

      // Only "publish now" needs the extra call: a scheduled row publishes
      // itself, and a draft is not published at all.
      if (choice.timing == PublishTiming.now) {
        await _repo.publish(
          mediaId: mediaId,
          visibility: MediaVisibility.public,
        );
      }

      if (!mounted) return;
      setState(() => _working = false);
      await PublishedCard.show(
        context,
        title: switch (choice.timing) {
          PublishTiming.now =>
            _audio
                ? AppStrings.newAudioLiveTitle
                : AppStrings.newVideoLiveTitle,
          PublishTiming.schedule =>
            _audio
                ? AppStrings.newAudioScheduledTitle
                : AppStrings.newVideoScheduledTitle,
          PublishTiming.draft => AppStrings.newMediaDraftTitle,
        },
        body: switch (choice.timing) {
          PublishTiming.now =>
            _audio ? AppStrings.newAudioLiveBody : AppStrings.newVideoLiveBody,
          PublishTiming.schedule =>
            'It goes live on ${formatSheetDate(choice.at!)} '
                'at ${formatSheetTime(choice.at!)}.',
          PublishTiming.draft => AppStrings.newMediaDraftBody,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on MediaUploadException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      // A spent ticket cannot be reused, so the file has to go back with
      // it — otherwise every retry fails the same way.
      if (e.failure == MediaUploadFailure.ticketExpired) _removeFile();
      _say(_explain(e));
    }
  }

  /// The quota refusal is the one worth repeating in the server's words: it
  /// names the plan's number, which nothing else tells the client
  /// (OPEN_ISSUES 19). Everything else reads better in ours.
  String _explain(MediaUploadException e) =>
      e.failure == MediaUploadFailure.quotaReached && e.message != null
      ? e.message!
      : _wording(e.failure);

  String _wording(MediaUploadFailure failure) => switch (failure) {
    MediaUploadFailure.tooLarge =>
      _audio ? AppStrings.newAudioTooLarge : AppStrings.newVideoTooLarge,
    MediaUploadFailure.unsupportedFormat =>
      _audio ? AppStrings.newAudioBadFormat : AppStrings.newVideoBadFormat,
    MediaUploadFailure.network => AppStrings.newMediaNetwork,
    MediaUploadFailure.ticketExpired => AppStrings.newMediaExpired,
    MediaUploadFailure.scheduleInPast => AppStrings.newMediaSchedulePast,
    // The quota message is the server's own and names the plan's number, so
    // it is shown verbatim when there is one.
    MediaUploadFailure.quotaReached ||
    MediaUploadFailure.cancelled ||
    MediaUploadFailure.rejected => AppStrings.newMediaRejected,
  };

  // ---- the screen --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final file = _file;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.s, 8.s, 20.s, 0),
              child: CreatorFlowHeader(
                title: _audio
                    ? AppStrings.newAudioTitle
                    : AppStrings.newVideoTitle,
                subtitle: _audio
                    ? AppStrings.newAudioSubtitle
                    : AppStrings.newVideoSubtitle,
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.s, 18.s, 20.s, 20.s),
                children: [
                  if (file == null)
                    MediaPickCard(
                      hint: _audio
                          ? AppStrings.newAudioPickHint
                          : AppStrings.newVideoPickHint,
                      selectLabel: _audio
                          ? AppStrings.newAudioSelect
                          : AppStrings.newVideoSelect,
                      onPick: _pickFile,
                    )
                  else
                    MediaFileCard(
                      kind: widget.kind,
                      file: file,
                      sent: _sent,
                      failed: _uploadFailed,
                      onRemove: _removeFile,
                    ),
                  SizedBox(height: 18.s),
                  const RequiredLabel(AppStrings.newMediaThumbnail),
                  SizedBox(height: 8.s),
                  ThumbnailWell(image: _thumbnail, onPick: _pickThumbnail),
                  SizedBox(height: 18.s),
                  const RequiredLabel(AppStrings.newMediaTitleLabel),
                  SizedBox(height: 8.s),
                  CreatorTextField(
                    key: const ValueKey('media-title'),
                    controller: _titleController,
                    hint: AppStrings.newMediaTitleHint,
                  ),
                  SizedBox(height: 18.s),
                  const RequiredLabel(AppStrings.newMediaDescriptionLabel),
                  SizedBox(height: 8.s),
                  CreatorTextField(
                    key: const ValueKey('media-description'),
                    controller: _descriptionController,
                    hint: AppStrings.newMediaDescriptionHint,
                    maxLines: 4,
                  ),
                  SizedBox(height: 18.s),
                  const RequiredLabel(
                    AppStrings.newMediaCategoryLabel,
                    required: false,
                  ),
                  SizedBox(height: 8.s),
                  CreatorSelectField(
                    key: const ValueKey('media-category'),
                    hint: AppStrings.newMediaCategoryHint,
                    value: _categoryValue.isEmpty ? null : _categoryValue,
                    onTap: _pickCategories,
                  ),
                ],
              ),
            ),
            _actions(context),
          ],
        ),
      ),
    );
  }

  /// The design floats these over the form; they sit on a plate here so the
  /// Category field underneath is never hidden by them.
  Widget _actions(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      20.s,
      12.s,
      20.s,
      12.s + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: const BoxDecoration(
      color: AppColors.base1,
      border: Border(top: BorderSide(color: AppColors.neutral900)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          key: const ValueKey('media-publish'),
          label: AppStrings.newMediaPublish,
          height: 52.s,
          enabled: _complete,
          loading: _working,
          onPressed: _publish,
        ),
        SizedBox(height: 12.s),
        GestureDetector(
          key: const ValueKey('media-draft'),
          behavior: HitTestBehavior.opaque,
          onTap: _complete && !_working ? _saveDraft : null,
          child: Text(
            AppStrings.newMediaSaveDraft,
            style: AppStyles.label(
              13,
              color: _complete ? AppColors.neutral200 : AppColors.neutral500,
            ),
          ),
        ),
      ],
    ),
  );
}
