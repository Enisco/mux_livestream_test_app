import 'dart:async';

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
import 'package:test_app/features/creator/views/widgets/moment_picker.dart';
import 'package:test_app/features/creator/views/widgets/new_event_parts.dart'
    show FieldNote;
import 'package:test_app/features/creator/views/widgets/new_media_parts.dart';
import 'package:test_app/features/creator/views/widgets/visibility_sheet.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/shared/components/image_crop_screen.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Uploading a video, or a piece of audio.
class NewMediaScreen extends StatefulWidget {
  const NewMediaScreen({
    super.key,
    required this.kind,
    this.creatorId,
    this.uploads,
    this.creators,
    this.editMediaId,
  });

  /// Video or audio. `music` is the API's word for what the design and the
  /// studio both call Audio.
  final MediaUploadKind kind;

  /// Defaults to the signed-in creator.
  final String? creatorId;

  /// Both default to the real thing; a test supplies its own.
  final MediaUploadRepo? uploads;
  final CreatorRepo? creators;

  /// The media row to open and correct. Null uploads a new one.
  final String? editMediaId;

  @override
  State<NewMediaScreen> createState() => _NewMediaScreenState();
}

class _NewMediaScreenState extends State<NewMediaScreen> {
  /// The row's own type outranks the caller's: on an edit the studio hands
  /// over a kind read from a list that may be minutes old, and the copy on
  /// this screen should say what the row actually is.
  bool get _audio => (_filed?.kind ?? widget.kind).isAudio;

  late final _repo = widget.uploads ?? MediaUploadRepo();
  late final _creators = widget.creators ?? CreatorRepo();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  PickedMediaFile? _file;
  MediaUploadTicket? _ticket;
  CancelToken? _cancel;

  /// The row, made before the first byte moves.
  FiledMedia? _draft;

  /// Bytes on the wire, and the future that finishes when they all are.
  int _sent = 0;
  Future<void>? _upload;
  bool _uploadFailed = false;

  PickedImage? _thumbnail;
  String? _thumbnailFileId;

  List<ContentCategory> _categories = const [];
  Set<String> _chosenCategories = {};

  bool _working = false;

  // ---- edit mode only ----------------------------------------------------

  /// The row as it is filed, when this screen is editing one.
  FiledMedia? _filed;

  /// Who can see it. Only on the form when editing; an upload's visibility
  /// is decided by the go-live sheet.
  MediaVisibility? _visibility;

  /// The moment it publishes itself, as the form currently has it. Null
  /// means not scheduled — which, against a row that *was* scheduled, is
  /// the creator clearing it.
  DateTime? _scheduledAt;

  bool _loading = false;

  /// What to say instead of the form, when the row could not be opened.
  String? _loadFailure;

  /// Whether that failure is worth a Retry. A row that is archived or not
  /// this member's to edit will not become either by asking again.
  bool _retryable = true;

  bool get _editing => widget.editMediaId != null;

  String? get _creatorId => widget.creatorId ?? LocalStorage.creatorId;

  @override
  void initState() {
    super.initState();
    // The primary button turns on as the last required field is filled, so
    // the form has to rebuild while the creator types.
    _titleController.addListener(_onTyped);
    _descriptionController.addListener(_onTyped);
    _loadCategories();
    if (widget.editMediaId case final id?) unawaited(_open(id));
  }

  /// Opens what is already filed.
  Future<void> _open(String mediaId) async {
    setState(() {
      _loading = true;
      _loadFailure = null;
      _retryable = true;
    });
    try {
      final filed = await _repo.readMedia(mediaId);
      if (!mounted) return;
      if (!filed.isEditable) {
        // The studio does not offer these, but a row can be archived
        // between the list loading and this screen opening.
        setState(() {
          _loading = false;
          _loadFailure = AppStrings.editMediaNotEditable;
          _retryable = false;
        });
        return;
      }
      setState(() {
        _filed = filed;
        _titleController.text = filed.title;
        _descriptionController.text = filed.description;
        _chosenCategories = filed.categorySlugs.toSet();
        _visibility = filed.visibility;
        _scheduledAt = filed.scheduledAt;
        _loading = false;
      });
    } on MediaUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailure = _explain(e);
        _retryable =
            e.failure != MediaUploadFailure.notAllowed &&
            e.failure != MediaUploadFailure.notFound;
      });
    }
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
      final categories = await _creators.fetchCategories(
        forContent: CategoryScope.media,
      );
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

  /// What an **edit** needs, which is only a title.
  bool get _canSaveEdit =>
      _filed != null &&
      _titleController.text.trim().isNotEmpty &&
      !_schedulePast;

  /// A moment the creator has just moved into the past.
  bool get _schedulePast {
    final at = _scheduledAt;
    return at != null &&
        at != _filed?.scheduledAt &&
        !at.isAfter(DateTime.now());
  }

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
      final draft =
          _draft ??
          await _repo.createDraft(creatorId: creatorId, kind: widget.kind);
      if (!mounted) return;
      setState(() => _draft = draft);

      final ticket = await _repo.requestUpload(
        creatorId: creatorId,
        kind: widget.kind,
        file: file,
        draft: draft,
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
      // `_draft` deliberately survives.
    });
  }

  // ---- the thumbnail -----------------------------------------------------

  Future<void> _pickThumbnail() async {
    final result = await CreatorImagePicker.pick(
      maxBytes: _thumbnailMaxBytes,
      crop: cropTo(
        context,
        shape: CropShape.wide,
        title: AppStrings.cropThumbnailTitle,
      ),
    );
    if (!mounted || result.isCancelled) return;

    switch (result.failure) {
      case PickFailure.tooLarge:
        _say(AppStrings.newMediaThumbTooLarge);
      case PickFailure.unreadable:
      case PickFailure.unsupported:
        _say(AppStrings.newMediaThumbUnreadable);
      // A shut library or a picker that would not open: nothing about the
      // picture, and the same sentence wherever it happens.
      case final refusal?:
        _say(refusal.accessProblem);
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
      scope: CategoryScope.media,
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

  Future<void> _pickVisibility() async {
    final chosen = await VisibilitySheet.show(context, current: _visibility);
    if (!mounted || chosen == null) return;
    setState(() => _visibility = chosen);
  }

  /// One wheel for the day, another for the clock — the same pair the
  /// go-live sheet shows, because it is the same field.
  Future<void> _pickSchedule({required bool dateOnly}) async {
    final now = DateTime.now();
    // A schedule only makes sense in the future: the route refuses one
    // that has already passed.
    final from = _scheduledAt == null || _scheduledAt!.isBefore(now)
        ? _nextHour()
        : _scheduledAt!;
    final picked = await pickMoment(
      context,
      initial: from,
      dateOnly: dateOnly,
      minimum: now,
    );
    if (picked == null || !mounted) return;
    setState(
      () => _scheduledAt = mergeMoment(from, picked, dateOnly: dateOnly),
    );
  }

  static DateTime _nextHour() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(const Duration(hours: 1));
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

  // ---- saving an edit ----------------------------------------------------

  /// One PATCH, and nothing about publishing.
  Future<void> _saveEdit() async {
    final mediaId = widget.editMediaId;
    final filed = _filed;
    final creatorId = _creatorId;
    if (mediaId == null || filed == null) return;
    // A new thumbnail has to be uploaded before it can be named, and that
    // needs a creator.
    if (_thumbnail != null && _thumbnailFileId == null && creatorId == null) {
      return _say(AppStrings.newMediaRejected);
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.length > 180) return _say(AppStrings.newMediaTitleTooLong);
    if (description.length > 5000) {
      return _say(AppStrings.newMediaDescriptionTooLong);
    }
    if (_chosenCategories.length > 8) {
      return _say(AppStrings.newMediaCategoryMax);
    }

    // Only a schedule the creator actually moved is sent.
    final scheduleMoved = _scheduledAt != filed.scheduledAt;
    final clearSchedule = scheduleMoved && _scheduledAt == null;
    final scheduledAt = scheduleMoved ? _scheduledAt : null;
    if (scheduledAt != null && !scheduledAt.isAfter(DateTime.now())) {
      return _say(AppStrings.newMediaSchedulePast);
    }

    setState(() => _working = true);
    try {
      // A thumbnail picked during this edit has not been uploaded yet; the
      // one that came with the row needs nothing and is never resent.
      if (_thumbnail case final picked? when creatorId != null) {
        _thumbnailFileId ??= await _repo.uploadThumbnail(
          creatorId: creatorId,
          image: picked,
        );
      }

      await _repo.saveEdits(
        mediaId: mediaId,
        title: title,
        // Left out only when it was empty and still is: sending `''` there
        // would risk a validator refusal to no purpose.
        description: description.isEmpty && filed.description.isEmpty
            ? null
            : description,
        categorySlugs: _chosenCategories.toList(growable: false),
        visibility: _visibility,
        thumbnailFileId: _thumbnailFileId,
        scheduledAt: scheduledAt,
        clearSchedule: clearSchedule,
      );
      if (!mounted) return;
      setState(() => _working = false);
      _say(AppStrings.editSaved);
      Navigator.pop(context, true);
    } on MediaUploadException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      _say(_explain(e));
    }
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
      // Wait for the bytes.
      await _upload;
      final draft = _draft;
      if (_uploadFailed || _ticket == null || draft == null) {
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

      await _repo.updateMedia(
        mediaId: draft.id,
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
          mediaId: draft.id,
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
    // Both 409s are the upload route's flow control and the repo answers
    // them itself.
    // Not the API: the system picker would not open or would not hand the
    // file back.
    MediaUploadFailure.pickerFailed => AppStrings.pickerUnavailable,
    MediaUploadFailure.sourceUnreadable => AppStrings.sourceUnreadable,
    MediaUploadFailure.notFound => AppStrings.editMediaGone,
    MediaUploadFailure.notAllowed => AppStrings.editMediaNotYours,
    MediaUploadFailure.draftChanged ||
    MediaUploadFailure.sourceAlreadyUploaded ||
    MediaUploadFailure.quotaReached ||
    MediaUploadFailure.cancelled ||
    MediaUploadFailure.rejected => AppStrings.newMediaRejected,
  };

  // ---- the screen --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.s, 8.s, 20.s, 0),
              child: CreatorFlowHeader(
                title: switch ((_editing, _audio)) {
                  (true, true) => AppStrings.editAudioTitle,
                  (true, false) => AppStrings.editVideoTitle,
                  (false, true) => AppStrings.newAudioTitle,
                  (false, false) => AppStrings.newVideoTitle,
                },
                subtitle: switch ((_editing, _audio)) {
                  (true, true) => AppStrings.editAudioSubtitle,
                  (true, false) => AppStrings.editVideoSubtitle,
                  (false, true) => AppStrings.newAudioSubtitle,
                  (false, false) => AppStrings.newVideoSubtitle,
                },
              ),
            ),
            Expanded(child: _body()),
            // Nothing to act on while the row is still being read, and
            // nothing to act on at all when it could not be.
            if (!_loading && _loadFailure == null) _actions(context),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        key: ValueKey('media-opening'),
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }
    if (_loadFailure case final message?) {
      return Center(
        key: const ValueKey('media-open-failed'),
        child: Padding(
          padding: EdgeInsets.all(24.s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppStyles.body(14, color: AppColors.neutral400),
              ),
              if (_retryable) ...[
                SizedBox(height: 14.s),
                SizedBox(
                  width: 150.s,
                  child: PrimaryButton(
                    key: const ValueKey('media-open-retry'),
                    label: AppStrings.feedRetry,
                    height: 44.s,
                    onPressed: () => unawaited(_open(widget.editMediaId!)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return _form();
  }

  Widget _form() {
    final file = _file;
    final filed = _filed;

    return ListView(
      padding: EdgeInsets.fromLTRB(20.s, 18.s, 20.s, 20.s),
      children: [
        // The file card belongs to an upload.
        if (_editing) ...[
          if (_sourceNote case final note?) ...[
            FieldNote(note),
            SizedBox(height: 14.s),
          ],
        ] else ...[
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
        ],
        // Required on an upload, where there is nothing to fall back on;
        // optional on an edit, where there already is one.
        RequiredLabel(AppStrings.newMediaThumbnail, required: !_editing),
        SizedBox(height: 8.s),
        ThumbnailWell(
          image: _thumbnail,
          existingUrl: filed?.thumbnailUrl,
          onPick: _pickThumbnail,
        ),
        SizedBox(height: 18.s),
        const RequiredLabel(AppStrings.newMediaTitleLabel),
        SizedBox(height: 8.s),
        CreatorTextField(
          key: const ValueKey('media-title'),
          controller: _titleController,
          hint: AppStrings.newMediaTitleHint,
        ),
        SizedBox(height: 18.s),
        RequiredLabel(AppStrings.newMediaDescriptionLabel, required: !_editing),
        SizedBox(height: 8.s),
        CreatorTextField(
          key: const ValueKey('media-description'),
          controller: _descriptionController,
          hint: AppStrings.newMediaDescriptionHint,
          maxLines: 4,
        ),
        SizedBox(height: 18.s),
        const RequiredLabel(AppStrings.newMediaCategoryLabel, required: false),
        SizedBox(height: 8.s),
        CreatorSelectField(
          key: const ValueKey('media-category'),
          hint: AppStrings.newMediaCategoryHint,
          value: _categoryValue.isEmpty ? null : _categoryValue,
          onTap: _pickCategories,
        ),
        if (_editing) ...[
          SizedBox(height: 18.s),
          const RequiredLabel(
            AppStrings.newMediaVisibilityLabel,
            required: false,
          ),
          SizedBox(height: 8.s),
          CreatorSelectField(
            key: const ValueKey('media-visibility'),
            hint: AppStrings.newMediaVisibilityHint,
            // No value rather than a wrong one when the row did not say.
            value: _visibility == null
                ? null
                : VisibilitySheet.label(_visibility!),
            onTap: _pickVisibility,
          ),
          // Setting a published row unlisted leaves the phone with no link
          // to hand over: only publish mints a share token.
          if (_visibility == MediaVisibility.unlisted)
            const FieldNote(AppStrings.visibilityUnlistedNoLink),
          SizedBox(height: 18.s),
          ?_schedule(filed),
        ],
      ],
    );
  }

  /// What the row's own status means for the edit in front of the creator.
  String? get _sourceNote => switch (_filed?.status) {
    MediaStatus.draft => AppStrings.editMediaNoFile,
    MediaStatus.processing => AppStrings.editMediaProcessing,
    MediaStatus.failed => AppStrings.editMediaFailed,
    null => null,
    _ => AppStrings.editMediaFileOnWeb,
  };

  /// The schedule, when the route will still take one.
  Widget? _schedule(FiledMedia? filed) {
    if (filed == null) return null;
    if (!filed.canBeScheduled) {
      return const FieldNote(AppStrings.newMediaScheduleClosed);
    }
    final at = _scheduledAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const RequiredLabel(AppStrings.newMediaScheduleLabel, required: false),
        SizedBox(height: 8.s),
        Row(
          children: [
            Expanded(
              child: CreatorSelectField(
                key: const ValueKey('media-schedule-date'),
                hint: AppStrings.newMediaScheduleHint,
                value: at == null ? null : formatSheetDate(at),
                onTap: () => unawaited(_pickSchedule(dateOnly: true)),
              ),
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: CreatorSelectField(
                key: const ValueKey('media-schedule-time'),
                hint: AppStrings.newMediaScheduleHint,
                value: at == null ? null : formatSheetTime(at),
                onTap: () => unawaited(_pickSchedule(dateOnly: false)),
              ),
            ),
          ],
        ),
        if (_schedulePast) ...[
          SizedBox(height: 10.s),
          Text(
            AppStrings.newMediaSchedulePast,
            key: const ValueKey('media-schedule-past'),
            style: AppStyles.label(
              12,
              color: AppColors.destructive,
              lineHeight: 16 / 12,
            ),
          ),
        ],
        if (at != null) ...[
          const FieldNote(AppStrings.newMediaScheduleNote),
          SizedBox(height: 4.s),
          GestureDetector(
            key: const ValueKey('media-schedule-clear'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _scheduledAt = null),
            child: Text(
              AppStrings.newMediaScheduleClear,
              style: AppStyles.label(12, color: AppColors.brandPrimary),
            ),
          ),
        ],
      ],
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
        // An edit has one button and no second thought.
        if (_editing)
          PrimaryButton(
            key: const ValueKey('media-save-edit'),
            label: AppStrings.editSaveChanges,
            height: 52.s,
            enabled: _canSaveEdit,
            loading: _working,
            onPressed: () => unawaited(_saveEdit()),
          )
        else ...[
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
      ],
    ),
  );
}
