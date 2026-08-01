import 'package:get_it/get_it.dart';

import '../features/auth/repo/auth_repo.dart';
import '../features/creator/repo/creator_repo.dart';
import '../features/discovery/repo/discovery_repo.dart';
import '../features/engagement/repo/engagement_repo.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/app_session_service.dart';
import '../services/connectivity_service.dart';
import '../services/device_info_service.dart';
import '../services/playback_info_cache.dart';
import '../services/token_storage_service.dart';
import '../services/vertical_feed_preloader.dart';
import '../utils/local_storage.dart';

final getIt = GetIt.instance;

Future<void> setupLocator() async {
  await LocalStorage.init();

  final deviceInfo = DeviceInfoService();
  await deviceInfo.init();

  // One analytics session ID, one clientSessionId, one anonymous viewer ID for
  // the whole app run — every screen reads them from here.
  final appSession = AppSessionService();
  await appSession.init();

  final connectivity = ConnectivityService();
  await connectivity.init();

  getIt.registerLazySingleton<DeviceInfoService>(() => deviceInfo);
  getIt.registerLazySingleton<AppSessionService>(() => appSession);
  getIt.registerLazySingleton<ConnectivityService>(() => connectivity);
  getIt.registerLazySingleton<TokenStorageService>(() => TokenStorageService());
  getIt.registerLazySingleton<ApiService>(
    () => ApiService(
      tokenStorage: getIt<TokenStorageService>(),
      deviceInfo: getIt<DeviceInfoService>(),
    ),
  );
  getIt.registerLazySingleton<AuthRepo>(() => AuthRepo());
  getIt.registerLazySingleton<CreatorRepo>(() => CreatorRepo());
  getIt.registerLazySingleton<DiscoveryRepo>(() => DiscoveryRepo());
  getIt.registerLazySingleton<EngagementRepo>(() => EngagementRepo());
  getIt.registerLazySingleton<AnalyticsService>(
    () => AnalyticsService(
      api: getIt<ApiService>(),
      deviceInfo: getIt<DeviceInfoService>(),
      session: getIt<AppSessionService>(),
      tokenStorage: getIt<TokenStorageService>(),
      connectivity: getIt<ConnectivityService>(),
    ),
  );
  getIt.registerLazySingleton<PlaybackInfoCache>(() => PlaybackInfoCache());
  getIt.registerLazySingleton<VerticalFeedPreloader>(
    () => VerticalFeedPreloader(
      repo: getIt<DiscoveryRepo>(),
      cache: getIt<PlaybackInfoCache>(),
      tokenStorage: getIt<TokenStorageService>(),
      session: getIt<AppSessionService>(),
    ),
  );

  // Eager: registers the app-lifecycle observer that flushes buffered beacons
  // before the OS suspends us (mobile's equivalent of a keepalive unload send).
  getIt<AnalyticsService>().init();
}
