import 'package:get_it/get_it.dart';

import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/onboarding/repo/onboarding_repo.dart';
import 'package:test_app/shared/services/analytics_service.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/app_session_service.dart';
import 'package:test_app/shared/services/connectivity_service.dart';
import 'package:test_app/shared/services/device_info_service.dart';
import 'package:test_app/shared/services/playback_info_cache.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/shared/services/vertical_feed_preloader.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

final getIt = GetIt.instance;

Future<void> setupLocator() async {
  await LocalStorage.init();

  final deviceInfo = DeviceInfoService();
  await deviceInfo.init();

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
  getIt.registerLazySingleton<OnboardingRepo>(() => OnboardingRepo());
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

  getIt<AnalyticsService>().init();
}
