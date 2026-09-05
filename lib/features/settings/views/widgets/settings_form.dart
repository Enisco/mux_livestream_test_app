import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/gtube_text_field.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The shape every account form takes: a title, a column of labelled fields,
/// and one action pinned above the home indicator.
///
/// All four screens behind the account menu are this with different fields, so
/// the chrome lives here and each screen supplies only its own content.
class SettingsFormScaffold extends StatelessWidget {
  const SettingsFormScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.onAction,
    this.actionLabel = AppStrings.settingsUpdate,
    this.busy = false,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onAction;
  final String actionLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.s, 10.s, 20.s, 24.s),
              child: Row(
                children: [
                  const GTubeBackButton(size: 24, box: 24),
                  SizedBox(width: 12.s),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.label(
                        18,
                        weight: AppStyles.bold,
                        lineHeight: 28 / 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.s, 0, 20.s, 24.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.s, 0, 20.s, 20.s),
              child: PrimaryButton(
                label: actionLabel,
                loading: busy,
                onPressed: onAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled field, with the rule or error that belongs under it.
class SettingsFormField extends StatefulWidget {
  const SettingsFormField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.helper,
    this.error,
    this.obscure = false,
    this.locked = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  /// The standing rule, shown while there is no error to show instead.
  final String? helper;

  /// Replaces [helper] and turns red once validation has something to say.
  final String? error;

  /// Password fields start hidden and offer a Show toggle.
  final bool obscure;

  /// A value the reader can see but not edit — the address being changed
  /// away from. Marked with a padlock rather than merely being inert.
  final bool locked;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

  @override
  State<SettingsFormField> createState() => _SettingsFormFieldState();
}

class _SettingsFormFieldState extends State<SettingsFormField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final note = widget.error ?? widget.helper;

    return Padding(
      padding: EdgeInsets.only(bottom: 24.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: AppStyles.label(13, weight: AppStyles.medium),
          ),
          SizedBox(height: 8.s),
          IgnorePointer(
            ignoring: widget.locked,
            child: GTubeTextField(
              controller: widget.controller,
              hint: widget.hint,
              obscureText: _hidden,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              textCapitalization: widget.textCapitalization,
              inputFormatters: widget.keyboardType == TextInputType.phone
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))]
                  : null,
              trailing: _trailing(),
            ),
          ),
          if (note != null && note.isNotEmpty) ...[
            SizedBox(height: 8.s),
            Text(
              note,
              style: AppStyles.caption(
                12,
                color: widget.error != null
                    ? AppColors.destructive
                    : AppColors.neutral500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _trailing() {
    if (widget.locked) {
      return Padding(
        padding: EdgeInsets.only(right: 4.s),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedSquareLock01,
          color: AppColors.neutral400,
          size: 20.s,
        ),
      );
    }
    if (!widget.obscure) return null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _hidden = !_hidden),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.s, vertical: 8.s),
        child: Text(
          _hidden ? AppStrings.settingsShow : AppStrings.settingsHide,
          style: AppStyles.label(
            13,
            weight: AppStyles.bold,
            color: AppColors.brandPrimary,
          ),
        ),
      ),
    );
  }
}

/// The note above a form explaining what the change will actually do.
class SettingsFormNotice extends StatelessWidget {
  const SettingsFormNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            color: AppColors.neutral500,
            size: 20.s,
          ),
          SizedBox(width: 10.s),
          Expanded(
            child: Text(
              text,
              style: AppStyles.body(
                13,
                color: AppColors.neutral500,
                lineHeight: 18 / 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
