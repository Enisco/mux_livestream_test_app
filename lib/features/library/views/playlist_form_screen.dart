import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/models/library_models/playlist_models.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// What the form hands back — a name and who may see it.
class PlaylistDraft {
  const PlaylistDraft({required this.name, required this.isPrivate});

  final String name;
  final bool isPrivate;
}

/// Naming a playlist, whether it is being made or renamed.
///
/// The design gives New playlist and Edit playlist the same screen with a
/// different title and button, so they are the same widget.
class PlaylistFormScreen extends StatefulWidget {
  const PlaylistFormScreen({super.key, this.existing});

  /// Null when creating; the playlist being renamed otherwise.
  final Playlist? existing;

  @override
  State<PlaylistFormScreen> createState() => _PlaylistFormScreenState();
}

class _PlaylistFormScreenState extends State<PlaylistFormScreen> {
  late final _controller = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late bool _private = widget.existing?.isPrivate ?? true;

  bool get _editing => widget.existing != null;

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

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, PlaylistDraft(name: name, isPrivate: _private));
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 10.s),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GTubeBackButton(size: 24, box: 24),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(
                      width: 24.s,
                      height: 24.s,
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: AppColors.textPrimary,
                        size: 22.s,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.s),
              Text(
                _editing
                    ? AppStrings.playlistEditTitle
                    : AppStrings.playlistNewTitle,
                style: AppStyles.label(
                  18,
                  weight: AppStyles.bold,
                  lineHeight: 28 / 18,
                ),
              ),
              SizedBox(height: 24.s),
              _Label(AppStrings.playlistNameLabel),
              SizedBox(height: 8.s),
              _NameField(controller: _controller),
              SizedBox(height: 20.s),
              _Label(AppStrings.playlistVisibilityLabel),
              SizedBox(height: 8.s),
              Row(
                children: [
                  Expanded(
                    child: _VisibilityOption(
                      label: AppStrings.playlistPrivate,
                      icon: HugeIcons.strokeRoundedViewOff,
                      selected: _private,
                      onTap: () => setState(() => _private = true),
                    ),
                  ),
                  SizedBox(width: 12.s),
                  Expanded(
                    child: _VisibilityOption(
                      label: AppStrings.playlistPublic,
                      icon: HugeIcons.strokeRoundedView,
                      selected: !_private,
                      onTap: () => setState(() => _private = false),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _SubmitButton(
                label: _editing
                    ? AppStrings.playlistUpdate
                    : AppStrings.playlistCreate,
                enabled: ready,
                onTap: _submit,
              ),
              SizedBox(height: 20.s),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppStyles.label(
      12,
      color: AppColors.neutral400,
      lineHeight: 16 / 12,
    ),
  );
}

/// The field keeps the design's amber border the whole time — it is the only
/// thing on the screen to type into, so it always reads as the focus.
class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52.s,
      padding: EdgeInsets.symmetric(horizontal: 14.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(8.s),
        border: Border.all(color: AppColors.brandPrimary),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        autofocus: true,
        cursorColor: AppColors.brandPrimary,
        style: AppStyles.body(14),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: AppStrings.playlistNameHint,
          hintStyle: AppStyles.body(14, color: AppColors.neutral500),
        ),
      ),
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final List<List<dynamic>> icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? AppColors.brandPrimary : AppColors.neutral300;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48.s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.fieldBg,
          borderRadius: BorderRadius.circular(8.s),
          border: Border.all(
            color: selected ? AppColors.brandPrimary : AppColors.neutral800,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, color: tint, size: 16.s),
            SizedBox(width: 8.s),
            Text(label, style: AppStyles.button(13, color: tint)),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          height: 52.s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.fieldBg,
            borderRadius: BorderRadius.circular(8.s),
            border: Border.all(color: AppColors.neutral800),
          ),
          child: Text(label, style: AppStyles.button(14)),
        ),
      ),
    );
  }
}
