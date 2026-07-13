import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart';

import 'core/app_strings.dart';
import 'core/app_theme.dart';
import 'core/locator.dart';
import 'core/router.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'services/token_storage_service.dart';
import 'services/vertical_feed_preloader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await dotenv.load(fileName: '.env');
  await setupLocator();
  setupSessionExpiredCallback();

  // Pre-warm the vertical feed immediately after auth is confirmed so the first
  // video has the maximum lead time to buffer before the user opens the screen.
  if (await getIt<TokenStorageService>().hasSession) {
    unawaited(getIt<VerticalFeedPreloader>().warmUp());
  }

  runApp(const GTubeApp());
}

class GTubeApp extends StatelessWidget {
  const GTubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(),
      child: MaterialApp.router(
        title: AppStrings.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: appRouter,
        builder: (context, child) => BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthLoggedOut) {
              appRouter.go(AppRoutes.signIn);
            }
          },
          child: child!,
        ),
      ),
    );
  }
}
