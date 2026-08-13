import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Adds a "Done" strip above the keyboard so numeric and email fields — which
/// have no return key that dismisses — can still be closed.
class KeyboardDoneToolbar extends StatelessWidget {
  const KeyboardDoneToolbar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final visible = keyboardHeight > 50.s;
    final toolbarHeight = 34.s;

    return Stack(
      children: [
        // The toolbar sits on top of the keyboard, so content has to clear both.
        visible
            ? MediaQuery(
                data: media.copyWith(
                  viewInsets: media.viewInsets.copyWith(
                    bottom: keyboardHeight + toolbarHeight,
                  ),
                ),
                child: child,
              )
            : child,
        if (visible)
          Positioned(
            bottom: keyboardHeight,
            left: 0,
            right: 0,
            child: Material(
              color: AppColors.base1,
              child: SizedBox(
                height: toolbarHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      child: Text(
                        AppStrings.done,
                        style: AppStyles.label(
                          15,
                          color: AppColors.brandPrimary,
                          weight: AppStyles.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
