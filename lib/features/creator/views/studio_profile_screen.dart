import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/creator_asset_repo.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The studio's own settings: logo, cover and about, on one screen.
///
/// This exists because the switcher used to open the **onboarding** chain —
/// four screens in sequence, every field starting empty — at a creator who
/// had already filled all three. Setting something up and changing
/// something that exists are different jobs: the first wants one decision
/// at a time and a way to skip, and the second wants to see what is there
/// and touch only the one thing that is wrong.
///
/// So this screen reads the channel first and shows it. Each image is its
/// own control, the about text comes back in the field, and **nothing is
/// written until Save**: a reader who picks a photo, thinks better of it
/// and backs out has changed nothing. That is what makes the uploads safe
/// to do eagerly — an object stays in `quarantine/` until a save references
/// its id, which is exactly what quarantine is for.
///
/// What it deliberately does not carry: channel name, page address and
/// categories, which the integration guide puts on the web studio's
/// settings form along with a warning that changing a handle breaks links
/// a community already shares. And no social links — *"There is no
/// social-links field, deliberately."*
class StudioProfileScreen extends StatefulWidget {
  const StudioProfileScreen({super.key, this.repo, this.assets, this.picker});

  final CreatorRepo? repo;
  final CreatorAssetRepo? assets;

  /// The photo library, injected so a test never reaches the plugin.
  final Future<PickResult> Function({required int maxBytes})? picker;

  @override
  State<StudioProfileScreen> createState() => _StudioProfileScreenState();
}

class _StudioProfileScreenState extends State<StudioProfileScreen> {
  late final _repo = widget.repo ?? CreatorRepo();
  late final _assets = widget.assets ?? getIt<CreatorAssetRepo>();

  final _about = TextEditingController();

  bool _loading = true;
  bool _failed = false;
  bool _saving = false;
  String? _problem;

  String _name = '';
  String _handle = '';

  /// What the server holds right now, so a change can be told from a
  /// redisplay of the same thing.
  String _savedAbout = '';
  String? _avatarUrl;
  String? _bannerUrl;

  /// Picked but not yet saved. The preview comes from the bytes; the id is
  /// what the save sends.
  PickedImage? _newAvatar;
  PickedImage? _newBanner;
  String? _avatarFileId;
  String? _bannerFileId;

  CreatorAssetKind? _uploading;

  @override
  void initState() {
    super.initState();
    _about.addListener(_onEdited);
    unawaited(_load());
  }

  @override
  void dispose() {
    _about.removeListener(_onEdited);
    _about.dispose();
    super.dispose();
  }

  /// Only the Save button's enabled state depends on the text, so this is a
  /// rebuild rather than a field.
  void _onEdited() => setState(() {});

  bool get _dirty =>
      _avatarFileId != null ||
      _bannerFileId != null ||
      _about.text.trim() != _savedAbout;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final creatorId = LocalStorage.creatorId;
    if (creatorId == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    try {
      final channel = await _repo.fetchChannel(creatorId);
      if (!mounted) return;
      final about = (channel?['bio'] as String? ?? '').trim();
      setState(() {
        _name = channel?['displayName'] as String? ?? '';
        _handle = channel?['handle'] as String? ?? '';
        _savedAbout = about;
        _about.text = about;
        _avatarUrl = AssetUrlResolver.resolve(channel?['avatarKey'] as String?);
        _bannerUrl = AssetUrlResolver.resolve(channel?['bannerKey'] as String?);
        // A fresh read is the new truth; anything picked against the old
        // one is no longer what is on screen.
        _newAvatar = null;
        _newBanner = null;
        _avatarFileId = null;
        _bannerFileId = null;
        _loading = false;
      });
    } catch (e) {
      logger.w('Could not read the channel', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// Pick an image and get it as far as a file id — but no further.
  Future<void> _pick(CreatorAssetKind kind) async {
    if (_uploading != null || _saving) return;
    final creatorId = LocalStorage.creatorId;
    if (creatorId == null) return;

    final pick = widget.picker ?? CreatorImagePicker.pick;
    final result = await pick(maxBytes: kind.maxBytes);
    if (!mounted || result.isCancelled) return;
    if (result.failure case final failure?) {
      setState(() => _problem = _pickProblem(failure));
      return;
    }
    final image = result.image!;
    setState(() {
      _uploading = kind;
      _problem = null;
      if (kind == CreatorAssetKind.avatar) {
        _newAvatar = image;
      } else {
        _newBanner = image;
      }
    });

    final outcome = await _assets.upload(
      creatorId: creatorId,
      kind: kind,
      image: image,
    );
    if (!mounted) return;
    setState(() {
      _uploading = null;
      if (outcome.fileId case final fileId?) {
        if (kind == CreatorAssetKind.avatar) {
          _avatarFileId = fileId;
        } else {
          _bannerFileId = fileId;
        }
        return;
      }
      // The preview goes back with it: showing an image that will not be
      // saved is worse than showing none.
      if (kind == CreatorAssetKind.avatar) {
        _newAvatar = null;
      } else {
        _newBanner = null;
      }
      _problem = _uploadProblem(outcome.failure!);
    });
  }

  Future<void> _save() async {
    final creatorId = LocalStorage.creatorId;
    if (creatorId == null || !_dirty || _uploading != null) return;
    final about = _about.text.trim();
    setState(() {
      _saving = true;
      _problem = null;
    });
    try {
      await _repo.updateCreatorProfile(
        creatorId: creatorId,
        // Only what changed. An unchanged about must not be resent as an
        // edit, and an emptied one has to go as '' rather than be dropped.
        bio: about == _savedAbout ? null : about,
        avatarFileId: _avatarFileId,
        bannerFileId: _bannerFileId,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      _say(AppStrings.studioProfileSaved);
      // Re-read rather than assume: the save is what promotes the files,
      // and the keys they end up under are the server's to say.
      await _load();
    } catch (e) {
      logger.w('Could not save the channel', error: e);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _problem = AppStrings.studioProfileSaveFailed;
      });
    }
  }

  static String _pickProblem(PickFailure failure) => switch (failure) {
    PickFailure.tooLarge => AppStrings.creatorImageTooLarge,
    PickFailure.unreadable => AppStrings.creatorImageUnreadable,
    PickFailure.unsupported => AppStrings.creatorImageUnsupported,
  };

  static String _uploadProblem(AssetUploadFailure failure) => switch (failure) {
    AssetUploadFailure.tooLarge => AppStrings.creatorImageTooLarge,
    AssetUploadFailure.network => AppStrings.creatorImageOffline,
    AssetUploadFailure.rejected => AppStrings.creatorImageUploadFailed,
  };

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Out of settings is back where the reader was, or the studio when they
  /// arrived by a route change rather than a push.
  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.studio);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base1,
      appBar: AppBar(
        backgroundColor: AppColors.base1,
        elevation: 0,
        leading: Align(
          alignment: Alignment.centerRight,
          child: GTubeBackButton(
            key: const ValueKey('studio-profile-back'),
            onTap: _back,
          ),
        ),
        title: Text(
          AppStrings.studioProfileTitle,
          style: AppStyles.heading(16),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandPrimary),
            )
          : _failed
          ? ErrorStateView(
              onRetry: _load,
              title: AppStrings.studioProfileFailed,
            )
          : RefreshIndicator(
              color: AppColors.brandPrimary,
              backgroundColor: AppColors.base1,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 32.s),
                children: [
                  Text(
                    AppStrings.studioProfileSubtitle,
                    style: AppStyles.body(
                      12,
                      color: AppColors.neutral400,
                      lineHeight: 17 / 12,
                    ),
                  ),
                  SizedBox(height: 18.s),
                  // Cover and logo together, the way a visitor meets them.
                  _cover(),
                  SizedBox(height: 22.s),
                  _sectionLabel(AppStrings.studioProfileAbout),
                  SizedBox(height: 8.s),
                  _aboutField(),
                  SizedBox(height: 10.s),
                  Text(
                    AppStrings.studioProfileWebNote,
                    style: AppStyles.label(
                      10,
                      color: AppColors.neutral500,
                      lineHeight: 14 / 10,
                    ),
                  ),
                  if (_problem case final message?) ...[
                    SizedBox(height: 12.s),
                    Text(
                      message,
                      key: const ValueKey('studio-profile-problem'),
                      style: AppStyles.label(12, color: AppColors.red500),
                    ),
                  ],
                  SizedBox(height: 22.s),
                  PrimaryButton(
                    key: const ValueKey('studio-profile-save'),
                    label: AppStrings.studioProfileSave,
                    loading: _saving,
                    // Nothing changed is nothing to send, and a live Save
                    // over an untouched form invites a pointless write.
                    enabled: _dirty && _uploading == null,
                    onPressed: () => unawaited(_save()),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: AppStyles.heading(14));

  Widget _cover() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionLabel(AppStrings.studioProfileCover),
        SizedBox(height: 8.s),
        SizedBox(
          height: 150.s,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _Tile(
                tileKey: const ValueKey('studio-profile-cover'),
                height: 122.s,
                radius: 10.s,
                busy: _uploading == CreatorAssetKind.banner,
                picked: _newBanner,
                url: _bannerUrl,
                emptyLabel: AppStrings.studioProfileNoCover,
                onTap: () => unawaited(_pick(CreatorAssetKind.banner)),
              ),
              Positioned(
                left: 14.s,
                bottom: 0,
                child: _Tile(
                  tileKey: const ValueKey('studio-profile-logo'),
                  height: 64.s,
                  width: 64.s,
                  circle: true,
                  busy: _uploading == CreatorAssetKind.avatar,
                  picked: _newAvatar,
                  url: _avatarUrl,
                  emptyLabel: null,
                  onTap: () => unawaited(_pick(CreatorAssetKind.avatar)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 6.s),
        Row(
          children: [
            Text(
              '${AppStrings.studioProfileLogo} · '
              '${_avatarUrl == null && _newAvatar == null ? AppStrings.studioProfileNoLogo : AppStrings.studioProfileChange}',
              style: AppStyles.label(11, color: AppColors.neutral500),
            ),
            if (_name.isNotEmpty) ...[
              const Spacer(),
              Flexible(
                child: Text(
                  _handle.isEmpty ? _name : '$_name · @$_handle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppStyles.label(11, color: AppColors.neutral500),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _aboutField() {
    final length = _about.text.characters.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 10.s),
          decoration: BoxDecoration(
            color: AppColors.fieldBg,
            borderRadius: BorderRadius.circular(10.s),
          ),
          child: TextField(
            key: const ValueKey('studio-profile-about'),
            controller: _about,
            maxLines: 5,
            minLines: 3,
            maxLength: AppStrings.creatorBioLimit,
            cursorColor: AppColors.brandPrimary,
            style: AppStyles.body(13, lineHeight: 18 / 13),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              counterText: '',
              hintText: AppStrings.studioProfileAboutHint,
              hintStyle: AppStyles.body(13, color: AppColors.neutral500),
            ),
          ),
        ),
        SizedBox(height: 6.s),
        Text(
          '$length/${AppStrings.creatorBioLimit}',
          textAlign: TextAlign.right,
          style: AppStyles.label(10, color: AppColors.neutral500),
        ),
      ],
    );
  }
}

/// One image slot: what is there now, what was just picked, or an invitation
/// to add one — and a spinner over it while the bytes are in flight.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.tileKey,
    required this.height,
    required this.busy,
    required this.picked,
    required this.url,
    required this.emptyLabel,
    required this.onTap,
    this.width,
    this.radius,
    this.circle = false,
  });

  final Key tileKey;
  final double height;
  final double? width;
  final double? radius;
  final bool circle;
  final bool busy;
  final PickedImage? picked;
  final String? url;
  final String? emptyLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = circle ? BoxShape.circle : BoxShape.rectangle;
    return GestureDetector(
      key: tileKey,
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: shape,
          color: AppColors.fieldBg,
          borderRadius: circle ? null : BorderRadius.circular(radius ?? 10),
          border: Border.all(color: AppColors.brandPrimary, width: 1.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (picked case final image?)
              Image.memory(image.bytes, fit: BoxFit.cover)
            else if (url case final address?)
              Image.network(
                address,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _empty(),
              )
            else
              _empty(),
            if (busy)
              ColoredBox(
                color: AppColors.base1.withValues(alpha: 0.5),
                child: Center(
                  child: SizedBox(
                    width: 16.s,
                    height: 16.s,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.s,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedImage02,
          color: AppColors.brandPrimary,
          size: 18.s,
        ),
        if (emptyLabel case final label?) ...[
          SizedBox(height: 6.s),
          Text(
            label,
            style: AppStyles.label(11, color: AppColors.brandPrimary),
          ),
        ],
      ],
    ),
  );
}
