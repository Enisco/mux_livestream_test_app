import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;

  static const slotHeight = 67.364;
  static const slotGap = 8.0;
  static const slotRadius = 8.0;
  static const activeBorderWidth = 0.972;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    if (widget.controller.text.length == widget.length) {
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    return Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < widget.length; i++) ...[
              if (i > 0) const SizedBox(width: OtpCodeField.slotGap),
              Expanded(
                child: _Slot(
                  character: i < value.length ? value[i] : null,
                  active: _focusNode.hasFocus && i == value.length,
                ),
              ),
            ],
          ],
        ),
        Positioned.fill(
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(widget.length),
            ],
            autofillHints: const [AutofillHints.oneTimeCode],
            enableInteractiveSelection: false,
            showCursor: false,
            cursorColor: Colors.transparent,
            style: const TextStyle(color: Colors.transparent, fontSize: 1),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.character, required this.active});

  final String? character;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: OtpCodeField.slotHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brandAltDark,
        borderRadius: BorderRadius.circular(OtpCodeField.slotRadius),
        border: active
            ? Border.all(
                color: AppColors.brandPrimary,
                width: OtpCodeField.activeBorderWidth,
              )
            : null,
        boxShadow: active ? AppStyles.otpSlotShadow : null,
      ),
      child: Text(
        character ?? '-',
        style: character != null
            ? AppStyles.display(38.864, lineHeight: 1)
            : AppStyles.display(
                38.864,
                color: AppColors.textMuted,
                lineHeight: 1,
              ),
      ),
    );
  }
}
