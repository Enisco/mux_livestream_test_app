import 'package:get_it/get_it.dart';

import 'package:test_app/models/notification_models/notification_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/device_info_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// The notification service, probed against staging on 2026-10-14.
///
/// Four things the spec does not say, each of which changes the client:
///
/// - **Paging is on the query string.** `page` and `limit` in the body are
///   refused outright (*"property page should not exist"*); they belong on
///   `?page=&limit=`. The default `perPage` is **6**, which is small enough
///   to look like a bug if it is not overridden.
/// - **There is no unread filter and no unread count.**
///   `{"filters":{"readAt":{"equals":null}}}` returns nothing at all although
///   unread rows exist, and `{"isNull":true}` answers 500. So unread is
///   counted on the device from `readAt`, over as many rows as have been
///   fetched — see [NotificationStore].
/// - **`status` is delivery state, not read state.** Every row sits at
///   `pending` whether or not it has been read; `readAt` is the only signal.
///   Filtering on `status: "read"` answers 500.
/// - **`platform` takes `android`, `ios` or `web`.** The validator's refusal
///   prints its enum empty — *"platform must be one of the following values:
///   "* — which reads as "nothing is allowed". All three are accepted.
class NotificationRepo {
  NotificationRepo({ApiService? api, DeviceInfoService? device})
    : _injected = api,
      _injectedDevice = device;

  final ApiService? _injected;
  final DeviceInfoService? _injectedDevice;

  ApiService get _api => _injected ?? GetIt.instance<ApiService>();
  DeviceInfoService get _device =>
      _injectedDevice ?? GetIt.instance<DeviceInfoService>();

  /// How many to ask for. The server's own default is 6.
  static const pageSize = 30;

  /// `POST /v1/notification/search?page=&limit=` — newest first.
  Future<NotificationPage> search({int page = 1, int limit = pageSize}) async {
    final response = await _api.post(
      '${ApiEndpoints.notificationSearch}?page=$page&limit=$limit',
      data: {
        'sort': [
          {'field': 'createdAt', 'direction': 'desc'},
        ],
      },
    );
    final data = _data(response.data);
    final meta = data['meta'] as Map<String, dynamic>? ?? const {};
    return NotificationPage(
      items: [
        for (final row in data['data'] as List? ?? const [])
          if (row is Map<String, dynamic>) AppNotification.fromJson(row),
      ],
      total: (meta['total'] as num?)?.toInt() ?? 0,
      nextPage: (meta['next'] as num?)?.toInt(),
    );
  }

  /// `POST /v1/notification/mark-read` — sets `readAt` on one row.
  Future<void> markRead(String id) => _api.post(
    ApiEndpoints.notificationMarkRead,
    data: {'notificationId': id},
  );

  /// `POST /v1/notification/mark-all-read` → `{updatedCount}`.
  Future<int> markAllRead() async {
    final response = await _api.post(
      ApiEndpoints.notificationMarkAllRead,
      data: const <String, dynamic>{},
    );
    return (_data(response.data)['updatedCount'] as num?)?.toInt() ?? 0;
  }

  /// `GET /v1/notification/preferences`.
  Future<NotificationPrefs> fetchPreferences() async {
    final response = await _api.get(ApiEndpoints.notificationPreferences);
    return NotificationPrefs.fromJson(_data(response.data));
  }

  /// `PATCH /v1/notification/preferences` — send only what changed.
  Future<NotificationPrefs> updatePreferences({
    bool? email,
    bool? push,
    bool? inApp,
  }) async {
    final response = await _api.patch(
      ApiEndpoints.notificationPreferences,
      data: {'email': ?email, 'push': ?push, 'inApp': ?inApp},
    );
    return NotificationPrefs.fromJson(_data(response.data));
  }

  /// `POST /v1/notification/device-token` — where this install's pushes go.
  ///
  /// Keyed on `deviceId`, so re-registering a rotated token replaces the old
  /// one rather than adding a second.
  Future<void> registerDevice(String token) => _api.post(
    ApiEndpoints.notificationDeviceToken,
    data: {
      'token': token,
      'platform': _device.platform,
      'deviceId': _device.deviceId,
    },
  );

  /// `DELETE /v1/notification/device-token` — on sign-out, so the next person
  /// to use the phone does not get this account's pushes.
  Future<void> unregisterDevice() => _api.delete(
    ApiEndpoints.notificationDeviceToken,
    data: {'deviceId': _device.deviceId},
  );

  static Map<String, dynamic> _data(Object? body) {
    final data = (body as Map<String, dynamic>?)?['data'];
    return data is Map<String, dynamic> ? data : const {};
  }
}
