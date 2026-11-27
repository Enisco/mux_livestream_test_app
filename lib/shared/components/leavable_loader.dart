import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/home/views/widgets/home_loader.dart';
import 'package:test_app/shared/components/app_icons.dart';

/// The branded loader with a way out of it.
///
/// A fetch that takes a while used to be a dead screen: the logo, the
/// spinner, and nothing to press. Both screens that use it had already
/// learned this lesson for their *failed* state — "a page that failed
/// left no way back" — and both still shipped the same trap one state
/// earlier, where the reader is far more likely to be sitting.
///
/// The arrow is drawn only when there is somewhere to go. On a root tab
/// the loader is exactly what it was.
class LeavableLoader extends StatelessWidget {
  const LeavableLoader({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const HomeLoader();
    return Stack(
      children: [
        const Positioned.fill(child: HomeLoader()),
        Positioned(
          left: 15.s,
          top: 12.s,
          child: SafeArea(
            child: GTubeBackButton(
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ],
    );
  }
}
