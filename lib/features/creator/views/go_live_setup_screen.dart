import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/repo/livestream_repo.dart';
import 'package:test_app/features/creator/repo/media_upload_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/creator/views/live_broadcast_screen.dart';
import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/features/creator/views/widgets/creator_topics_sheet.dart';
import 'package:test_app/features/creator/views/widgets/new_media_parts.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// What the broadcast will be called, before any camera is touched.
///
/// Everything here goes on the session; nothing is uploaded except the
/// cover art, which uses the media thumbnail ticket the video and audio
/// screens use. The camera is not opened until the next screen, so a
/// creator who is only filling in a title is never asked for permission.
class GoLiveSetupScreen extends StatefulWidget {
  const GoLiveSetupScreen({
    super.key,
    this.creatorId,
    this.live,
    this.uploads,
    this.creators,
  });

  /// Defaults to the signed-in creator.
  final String? creatorId;

  /// All three default to the real thing; a test supplies its own.
  final LivestreamRepo? live;
  final MediaUploadRepo? uploads;
  final CreatorRepo? creators;

  @override
  State<GoLiveSetupScreen> createState() => _GoLiveSetupScreenState();
}

class _GoLiveSetupScreenState extends State<GoLiveSetupScreen> {
  late final _repo = widget.live ?? LivestreamRepo();
  late final _uploads = widget.uploads ?? MediaUploadRepo();
  late final _creators = widget.creators ?? CreatorRepo();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  PickedImage? _cover;
  List<ContentCategory> _categories = const [];
  Set<String> _chosenCategories = {};
  bool _working = false;

  String? get _creatorId => widget.creatorId ?? LocalStorage.creatorId;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTyped);
    _loadCategories();
  }

  void _onTyped() => setState(() {});

  @override
  void dispose() {
    _titleController.removeListener(_onTyped);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _creators.fetchCategories();
      if (!mounted || categories.isEmpty) return;
      setState(() => _categories = categories);
    } catch (e) {
      logger.w('Could not load categories', error: e);
    }
  }

  LiveSessionDraft get _draft => LiveSessionDraft(
    title: _titleController.text.trim(),
    description: _descriptionController.text.trim(),
    categorySlugs: _chosenCategories.toList(growable: false),
    // The button says the stream will notify subscribers, so it does.
    notifyFollowers: true,
  );

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

  Future<void> _pickCover() async {
    final result = await CreatorImagePicker.pick(maxBytes: 10 * 1024 * 1024);
    if (!mounted || result.isCancelled) return;

    switch (result.failure) {
      case PickFailure.tooLarge:
        _say(AppStrings.newMediaThumbTooLarge);
      case PickFailure.unreadable:
      case PickFailure.unsupported:
        _say(AppStrings.newMediaThumbUnreadable);
      case null:
        setState(() => _cover = result.image);
    }
  }

  Future<void> _pickCategories() async {
    final picked = await CreatorTopicsSheet.show(
      context,
      categories: _categories,
      selected: _chosenCategories,
    );
    if (!mounted || picked == null) return;
    setState(() => _chosenCategories = picked);
  }

  String get _categoryValue => [
    for (final slug in _chosenCategories)
      _categories.where((c) => c.slug == slug).map((c) => c.name).firstOrNull ??
          slug,
  ].join(', ');

  /// Provisions, uploads the cover and files the session — then hands over
  /// to the camera. Arming and starting belong to the broadcast screen,
  /// because the ingest window is only fifteen minutes and should not open
  /// until something is about to push into it.
  Future<void> _goLive() async {
    final creatorId = _creatorId;
    if (creatorId == null) return _say(AppStrings.goLiveRejected);

    setState(() => _working = true);
    try {
      final provision = await _repo.provision(creatorId);

      String? thumbnailFileId;
      if (_cover case final cover?) {
        thumbnailFileId = await _uploads.uploadThumbnail(
          creatorId: creatorId,
          image: cover,
        );
      }

      final mediaId = await _repo.createSession(
        creatorId: creatorId,
        draft: LiveSessionDraft(
          title: _draft.title,
          description: _draft.description,
          categorySlugs: _draft.categorySlugs,
          thumbnailFileId: thumbnailFileId,
          notifyFollowers: true,
        ),
      );

      if (!mounted) return;
      setState(() => _working = false);
      final went = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => LiveBroadcastScreen(
            mediaId: mediaId,
            rtmpIngestUrl: provision.rtmpIngestUrl,
            streamKey: provision.streamKeyRef,
            live: widget.live,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, went ?? false);
    } on LiveException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      _say(_wording(e));
    } on MediaUploadException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      _say(e.message ?? AppStrings.goLiveRejected);
    }
  }

  static String _wording(LiveException e) => switch (e.failure) {
    LiveFailure.noPermission => AppStrings.goLiveNeedsCamera,
    LiveFailure.conflict => AppStrings.goLiveConflict,
    LiveFailure.notArmed => AppStrings.goLiveNotArmed,
    LiveFailure.network => AppStrings.newMediaNetwork,
    LiveFailure.rejected => e.message ?? AppStrings.goLiveRejected,
  };

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
              title: AppStrings.goLiveTitle,
              subtitle: AppStrings.goLiveSubtitle,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20.s, 18.s, 20.s, 20.s),
              children: [
                const RequiredLabel(
                  AppStrings.goLiveCoverLabel,
                  required: false,
                ),
                SizedBox(height: 8.s),
                ThumbnailWell(image: _cover, onPick: _pickCover),
                SizedBox(height: 18.s),

                const RequiredLabel(
                  AppStrings.goLiveDescriptionLabel,
                  required: false,
                ),
                SizedBox(height: 8.s),
                CreatorTextField(
                  key: const ValueKey('live-description'),
                  controller: _descriptionController,
                  hint: AppStrings.goLiveDescriptionHint,
                  maxLines: 4,
                ),
                SizedBox(height: 18.s),

                const RequiredLabel(AppStrings.goLiveTitleLabel),
                SizedBox(height: 8.s),
                CreatorTextField(
                  key: const ValueKey('live-title'),
                  controller: _titleController,
                  hint: AppStrings.goLiveTitleHint,
                ),
                SizedBox(height: 18.s),

                const RequiredLabel(
                  AppStrings.goLiveCategoryLabel,
                  required: false,
                ),
                SizedBox(height: 8.s),
                CreatorSelectField(
                  key: const ValueKey('live-category'),
                  hint: AppStrings.newMediaCategoryHint,
                  value: _categoryValue.isEmpty ? null : _categoryValue,
                  onTap: _pickCategories,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20.s,
              12.s,
              20.s,
              16.s + MediaQuery.paddingOf(context).bottom,
            ),
            child: PrimaryButton(
              key: const ValueKey('live-start'),
              label: AppStrings.goLiveStart,
              height: 52.s,
              enabled: _draft.isReady,
              loading: _working,
              onPressed: _goLive,
            ),
          ),
        ],
      ),
    ),
  );
}
