import 'package:get_it/get_it.dart';

import '../features/auth/repo/auth_repo.dart';
import '../features/creator/repo/creator_repo.dart';
import '../features/discovery/repo/discovery_repo.dart';
import '../features/engagement/repo/engagement_repo.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/device_info_service.dart';
import '../services/playback_info_cache.dart';
import '../services/token_storage_service.dart';
import '../utils/local_storage.dart';

final getIt = GetIt.instance;

Future<void> setupLocator() async {
  await LocalStorage.init();

  final deviceInfo = DeviceInfoService();
  await deviceInfo.init();

  getIt.registerLazySingleton<DeviceInfoService>(() => deviceInfo);
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
  getIt.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
  getIt.registerLazySingleton<PlaybackInfoCache>(() => PlaybackInfoCache());
}
