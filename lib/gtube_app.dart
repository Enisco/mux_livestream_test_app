import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_app/features/creator/services/checkout_link_listener.dart';
import 'package:test_app/shared/components/keyboard_done_toolbar.dart';
import 'package:test_app/shared/components/network_banner.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_theme.dart';

class GTubeApp extends StatelessWidget {
  const GTubeApp({super.key});

  static const _designSize = Size(390, 844);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider(create: (_) => AuthBloc())],
      child: SizingBuilder(
        baseSize: _designSize,
        // Type scale is pinned below, so layout must not track it either.
        respectSystemFontScale: false,
        builder: (context) => MaterialApp.router(
          title: AppStrings.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          routerConfig: appRouter,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: CheckoutLinkWatcher(
              child: GTubeNetworkBanner(
                child: KeyboardDoneToolbar(
                  child: BlocListener<AuthBloc, AuthState>(
                    listener: (context, state) {
                      if (state is AuthLoggedOut) {
                        appRouter.go(AppRouter.home);
                      }
                    },
                    child: child!,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
