import 'dart:async' show unawaited;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart';
import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/gtube_app.dart';
import 'package:test_app/shared/services/media_session_handler.dart';
import 'package:test_app/shared/services/playback_controller.dart';
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
  await _startMediaSession();

  if (await getIt<TokenStorageService>().hasSession) {
    unawaited(getIt<VerticalFeedPreloader>().warmUp());
  }

  runApp(const GTubeApp());
}

/// Registers the app with the OS media session, so a playing track appears in
/// the notification shade and keeps going in the background.
///
/// A failure here must not stop the app launching — the worst case is playback
/// without notification controls, which is where it stood before.
Future<void> _startMediaSession() async {
  try {
    // iOS defaults every app to the "solo ambient" category, which the ring
    // switch silences and backgrounding stops — UIBackgroundModes alone does
    // not change that, and neither media_kit nor audio_service sets a category
    // of its own. Declaring playback is what actually makes a track survive the
    // lock screen. Harmless on Android, where it is a no-op.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    final handler = await AudioService.init(
      builder: () => MediaSessionHandler(
        getIt<PlaybackController>(),
        setSessionActive: ({required active}) => session.setActive(active),
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'tv.gospeltube.audio',
        androidNotificationChannelName: 'Playback',
        // The notification is the only thing keeping the process alive while
        // the reader is in another app, so it must not be swipeable away
        // mid-track; it clears itself when playback stops.
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    getIt.registerSingleton<MediaSessionHandler>(handler);
  } catch (e, st) {
    logger.e('Media session unavailable', error: e, stackTrace: st);
  }
}
