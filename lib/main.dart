import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/gtube_app.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/shared/services/vertical_feed_preloader.dart';

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

  if (await getIt<TokenStorageService>().hasSession) {
    unawaited(getIt<VerticalFeedPreloader>().warmUp());
  }

  runApp(const GTubeApp());
}
