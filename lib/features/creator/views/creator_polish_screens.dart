import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/creator_asset_repo.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The four optional steps between "your channel exists" and using it.
///
/// Photo, banner, bio, links. Each can be skipped, so none of them may block
/// the reader or lose what the ones before it collected.
///
/// Picking and uploading are both real. [CreatorImagePicker] handles the HEIC
/// an iPhone hands over and the per-asset ceiling; [CreatorAssetRepo] does the
/// three-step handshake (`upload-url` → presigned S3 POST → save the creator
/// with the returned `fileId`, which is what promotes the object out of
/// quarantine). Saving is what attaches it, so each step patches the creator
/// as it advances rather than holding the ids to the end.

/// Picks, uploads and reports, for the two steps that carry an image.
///
/// The fileId is patched onto the creator as soon as it exists: the steps can
/// each be skipped, so there is no later moment guaranteed to run.
mixin _AssetStep<T extends StatefulWidget> on State<T> {
  PickedImage? picked;
  bool uploading = false;

  CreatorAssetKind get kind;

  Future<void> pickAndUpload() async {
    if (uploading) return;

    final result = await CreatorImagePicker.pick(maxBytes: kind.maxBytes);
    if (!mounted || result.isCancelled) return;
    if (result.failure case final failure?) {
      _reportPickFailure(context, failure);
      return;
    }

    setState(() {
      picked = result.image;
      uploading = true;
    });

    final creatorId = LocalStorage.creatorId;
    if (creatorId == null) {
      // Nothing to attach it to yet; the preview still stands so the reader
      // is not left wondering whether the tap registered.
      logger.w('No cached creatorId; ${kind.slug} not uploaded');
      if (mounted) setState(() => uploading = false);
      return;
    }

    final outcome = await getIt<CreatorAssetRepo>().upload(
      creatorId: creatorId,
      kind: kind,
      image: result.image!,
    );
    if (!mounted) return;

    if (outcome.fileId case final fileId?) {
      await getIt<CreatorRepo>().updateCreatorProfile(
        creatorId: creatorId,
        avatarFileId: kind == CreatorAssetKind.avatar ? fileId : null,
        bannerFileId: kind == CreatorAssetKind.banner ? fileId : null,
      );
      if (mounted) setState(() => uploading = false);
      return;
    }

    setState(() {
      uploading = false;
      picked = null;
    });
    _reportUploadFailure(context, outcome.failure!);
  }
}

/// Says why an upload did not stick.
void _reportUploadFailure(BuildContext context, AssetUploadFailure failure) {
  final message = switch (failure) {
    AssetUploadFailure.tooLarge => AppStrings.creatorImageTooLarge,
    AssetUploadFailure.network => AppStrings.creatorImageOffline,
    AssetUploadFailure.rejected => AppStrings.creatorImageUploadFailed,
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: AppStyles.body(13)),
      backgroundColor: AppColors.neutral800,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Says why a pick could not be used, in the words that name the fix.
void _reportPickFailure(BuildContext context, PickFailure failure) {
  final message = switch (failure) {
    PickFailure.tooLarge => AppStrings.creatorImageTooLarge,
    PickFailure.unreadable => AppStrings.creatorImageUnreadable,
    PickFailure.unsupported => AppStrings.creatorImageUnsupported,
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: AppStyles.body(13)),
      backgroundColor: AppColors.neutral800,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// The frame every polish step shares: header, content, dots, skip, button.
class _PolishScaffold extends StatelessWidget {
  const _PolishScaffold({
    required this.title,
    required this.subtitle,
    required this.step,
    required this.onNext,
    required this.child,
    this.centerContent = false,
  });

  final String title;
  final String subtitle;

  /// Which of the four dots is lit.
  final int step;

  final VoidCallback onNext;
  final Widget child;
  final bool centerContent;

  /// Skipping and continuing land in the same place — the difference is only
  /// whether this step wrote anything first.
  static void _advance(BuildContext context, int step) {
    switch (step) {
      case 0:
        context.go(AppRouter.creatorBanner);
      case 1:
        context.go(AppRouter.creatorBio);
      case 2:
        context.go(AppRouter.creatorLinks);
      default:
        // Setting up a channel ends in the studio it just made, not back on
        // the home feed with nothing to show for it.
        context.go(AppRouter.studio);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      backgroundColor: AppColors.brandSecondary,
      centerContent: centerContent,
      topBar: CreatorFlowHeader(
        title: title,
        subtitle: subtitle,
        onBack: () => context.pop(),
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CreatorStepDots(index: step),
          const SizedBox(height: 12),
          CreatorSkipLine(
            label: AppStrings.creatorDoThisLater,
            onTap: () => _advance(context, step),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: AppStrings.continueLabel,
            height: 54,
            onPressed: onNext,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Step one: the avatar that sits beside everything the channel publishes.
class CreatorPhotoScreen extends StatefulWidget {
  const CreatorPhotoScreen({super.key});

  @override
  State<CreatorPhotoScreen> createState() => _CreatorPhotoScreenState();
}

class _CreatorPhotoScreenState extends State<CreatorPhotoScreen>
    with _AssetStep {
  @override
  CreatorAssetKind get kind => CreatorAssetKind.avatar;

  @override
  Widget build(BuildContext context) {
    final name = LocalStorage.getString(LocalStorage.creatorNameKey) ?? '';

    return _PolishScaffold(
      title: AppStrings.creatorPhotoTitle,
      subtitle: AppStrings.creatorPhotoSubtitle,
      step: 0,
      centerContent: true,
      onNext: () => _PolishScaffold._advance(context, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            key: const ValueKey('creator-photo-picker'),
            behavior: HitTestBehavior.opaque,
            onTap: pickAndUpload,
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.brandPrimary, width: 2),
              ),
              child: picked == null
                  ? const HugeIcon(
                      icon: HugeIcons.strokeRoundedCamera01,
                      color: AppColors.brandPrimary,
                      size: 30,
                    )
                  : Image.memory(
                      picked!.bytes,
                      fit: BoxFit.cover,
                      width: 96,
                      height: 96,
                    ),
            ),
          ),
          if (picked != null) ...[
            const SizedBox(height: 10),
            uploading
                ? const _UploadingLine()
                : _ChangeLink(onTap: pickAndUpload),
          ],
          if (name.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              name,
              textAlign: TextAlign.center,
              style: AppStyles.heading(18, letterSpacing: -0.4),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            AppStrings.creatorPhotoCaption,
            textAlign: TextAlign.center,
            style: AppStyles.body(
              12,
              color: AppColors.neutral400,
              lineHeight: 16 / 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step two: the wide image across the top of the channel page.
class CreatorBannerScreen extends StatefulWidget {
  const CreatorBannerScreen({super.key});

  @override
  State<CreatorBannerScreen> createState() => _CreatorBannerScreenState();
}

class _CreatorBannerScreenState extends State<CreatorBannerScreen>
    with _AssetStep {
  @override
  CreatorAssetKind get kind => CreatorAssetKind.banner;

  @override
  Widget build(BuildContext context) {
    return _PolishScaffold(
      title: AppStrings.creatorBannerTitle,
      subtitle: AppStrings.creatorBannerSubtitle,
      step: 1,
      onNext: () => _PolishScaffold._advance(context, 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 18),
          // The banner and the avatar that overlaps it, so the reader sees how
          // the two sit together before choosing either.
          SizedBox(
            height: 150,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  key: const ValueKey('creator-banner-picker'),
                  behavior: HitTestBehavior.opaque,
                  onTap: pickAndUpload,
                  child: Container(
                    height: 122,
                    width: double.infinity,
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.brandPrimary,
                        width: 1.5,
                      ),
                      image: picked == null
                          ? null
                          : DecorationImage(
                              image: MemoryImage(picked!.bytes),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: picked != null
                        ? const SizedBox.shrink()
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const HugeIcon(
                                  icon: HugeIcons.strokeRoundedImage02,
                                  color: AppColors.brandPrimary,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppStrings.creatorBannerTapToAdd,
                                  style: AppStyles.label(
                                    12,
                                    weight: AppStyles.bold,
                                    color: AppColors.brandPrimary,
                                    lineHeight: 16 / 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 0,
                  child: Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.fieldBg,
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedImage02,
                      color: AppColors.neutral400,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (picked != null) ...[
            uploading
                ? const _UploadingLine()
                : _ChangeLink(onTap: pickAndUpload),
            const SizedBox(height: 10),
          ],
          const _PlaceholderLine(width: 120),
          const SizedBox(height: 8),
          const _PlaceholderLine(width: 180),
        ],
      ),
    );
  }
}

/// Stands in for the Change link while the bytes are in flight, so a slow
/// upload does not look like a finished one.
class _UploadingLine extends StatelessWidget {
  const _UploadingLine();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 11,
        height: 11,
        child: CircularProgressIndicator(
          strokeWidth: 1.6,
          color: AppColors.brandPrimary,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        AppStrings.creatorImageUploading,
        style: AppStyles.label(
          12,
          color: AppColors.neutral400,
          lineHeight: 16 / 12,
        ),
      ),
    ],
  );
}

/// Once an image fills the target, the way to replace it needs saying.
class _ChangeLink extends StatelessWidget {
  const _ChangeLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        AppStrings.creatorImageChange,
        style: AppStyles.label(
          12,
          weight: AppStyles.bold,
          color: AppColors.brandPrimary,
          lineHeight: 16 / 12,
        ),
      ),
    ),
  );
}

/// The greyed-out name and handle under the banner, standing in for the
/// channel page the reader has not filled in yet.
class _PlaceholderLine extends StatelessWidget {
  const _PlaceholderLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 9,
    decoration: BoxDecoration(
      color: AppColors.fieldBg,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

/// Step three: one or two sentences for the channel page.
class CreatorBioScreen extends StatefulWidget {
  const CreatorBioScreen({super.key});

  @override
  State<CreatorBioScreen> createState() => _CreatorBioScreenState();
}

class _CreatorBioScreenState extends State<CreatorBioScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Writes the bio before moving on. Skipping bypasses this, which is the
  /// whole difference between the two ways out of the step.
  Future<void> _saveAndAdvance() async {
    final bio = _controller.text.trim();
    final creatorId = LocalStorage.creatorId;

    if (bio.isNotEmpty && creatorId != null) {
      setState(() => _saving = true);
      try {
        await getIt<CreatorRepo>().updateCreatorProfile(
          creatorId: creatorId,
          bio: bio,
        );
      } catch (e) {
        logger.w('Could not save bio', error: e);
      }
      if (!mounted) return;
      setState(() => _saving = false);
    }

    if (mounted) _PolishScaffold._advance(context, 2);
  }

  @override
  Widget build(BuildContext context) {
    final name = LocalStorage.getString(LocalStorage.creatorNameKey)?.trim();

    return _PolishScaffold(
      title: name == null || name.isEmpty
          ? '${AppStrings.creatorBioTitlePrefix} this channel '
                '${AppStrings.creatorBioTitleSuffix}'
          : '${AppStrings.creatorBioTitlePrefix} $name '
                '${AppStrings.creatorBioTitleSuffix}',
      subtitle: AppStrings.creatorBioSubtitle,
      step: 2,
      onNext: _saveAndAdvance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 18),
          Container(
            height: 170,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.fieldBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              maxLength: AppStrings.creatorBioLimit,
              cursorColor: AppColors.brandPrimary,
              style: AppStyles.body(13, lineHeight: 20 / 13),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                counterText: '',
                hintText: AppStrings.creatorBioHint,
                hintStyle: AppStyles.body(
                  13,
                  color: AppColors.neutral500,
                  lineHeight: 20 / 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _saving
                ? AppStrings.creatorBioSaving
                : '${_controller.text.characters.length}/'
                      '${AppStrings.creatorBioLimit}',
            style: AppStyles.label(
              11,
              color: AppColors.neutral500,
              lineHeight: 14 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step four: where else the ministry already lives.
class CreatorLinksScreen extends StatefulWidget {
  const CreatorLinksScreen({super.key});

  @override
  State<CreatorLinksScreen> createState() => _CreatorLinksScreenState();
}

class _CreatorLinksScreenState extends State<CreatorLinksScreen> {
  /// The three the design names, then whatever the reader adds.
  late final List<(List<List<dynamic>>, String, TextEditingController)> _rows =
      [
        (
          HugeIcons.strokeRoundedGlobe02,
          AppStrings.creatorLinksWebsiteHint,
          TextEditingController(),
        ),
        (
          HugeIcons.strokeRoundedInstagram,
          AppStrings.creatorLinksInstagramHint,
          TextEditingController(),
        ),
        (
          HugeIcons.strokeRoundedYoutube,
          AppStrings.creatorLinksYoutubeHint,
          TextEditingController(),
        ),
      ];

  @override
  void dispose() {
    for (final (_, _, controller) in _rows) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add((
        HugeIcons.strokeRoundedLink02,
        AppStrings.creatorLinksMoreHint,
        TextEditingController(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PolishScaffold(
      title: AppStrings.creatorLinksTitle,
      subtitle: AppStrings.creatorLinksSubtitle,
      step: 3,
      onNext: () => _PolishScaffold._advance(context, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 18),
          Text.rich(
            TextSpan(
              style: AppStyles.label(
                12,
                weight: AppStyles.bold,
                lineHeight: 16 / 12,
              ),
              children: [
                const TextSpan(text: '${AppStrings.creatorLinksLabel} '),
                TextSpan(
                  text: AppStrings.creatorLinksOptional,
                  style: AppStyles.label(
                    11,
                    color: AppColors.neutral500,
                    lineHeight: 16 / 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (final (i, (icon, hint, controller)) in _rows.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                HugeIcon(icon: icon, color: AppColors.neutral400, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: AppColors.fieldBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.url,
                      cursorColor: AppColors.brandPrimary,
                      style: AppStyles.body(13),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: hint,
                        hintStyle: AppStyles.body(
                          13,
                          color: AppColors.neutral500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            key: const ValueKey('creator-add-link'),
            behavior: HitTestBehavior.opaque,
            onTap: _addRow,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 15, color: AppColors.brandPrimary),
                const SizedBox(width: 6),
                Text(
                  AppStrings.creatorLinksAddAnother,
                  style: AppStyles.label(
                    12,
                    weight: AppStyles.bold,
                    color: AppColors.brandPrimary,
                    lineHeight: 16 / 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
