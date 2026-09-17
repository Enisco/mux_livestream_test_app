import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// Everything the Studio tab shows.
///
/// The four routes are real and were read off staging; none publishes a
/// response schema, so the shapes in [DashboardContext] and friends are what
/// the server actually answered rather than what the spec claims.
///
/// Each section loads on its own and fails on its own: a studio with no
/// payment setup makes the giving figure 500, and that must not take the rest
/// of the dashboard down with it.
class CreatorDashboardRepo {
  CreatorDashboardRepo([ApiService? api]) : _injected = api;

  final ApiService? _injected;

  /// Resolved on use, not on construction — see [CreatorRepo].
  ApiService get _api => _injected ?? getIt<ApiService>();

  /// The channel's running totals. `dashboard/context` carries the creator
  /// but not its `subscriberCount`, and the TODAY card wants the total with
  /// the day's gain beside it, not the gain alone.
  Future<int?> fetchSubscriberCount(String creatorId) async {
    try {
      final response = await _api.get(ApiEndpoints.creatorById(creatorId));
      final data = response.data['data'];
      final creator = data is Map<String, dynamic>
          ? (data['creator'] as Map<String, dynamic>? ?? data)
          : null;
      return (creator?['subscriberCount'] as num?)?.toInt();
    } catch (e) {
      logger.w('Subscriber count failed', error: e);
      return null;
    }
  }

  Future<DashboardContext?> fetchContext(String creatorId) async {
    try {
      final response = await _api.get(
        ApiEndpoints.creatorDashboard(creatorId, 'context'),
      );
      final data = response.data['data'];
      return data is Map<String, dynamic>
          ? DashboardContext.fromJson(data)
          : null;
    } catch (e) {
      logger.w('Dashboard context failed', error: e);
      return null;
    }
  }

  /// The "here's how to start" steps, or empty once there is nothing left to
  /// do — which is also how the card knows to disappear.
  Future<List<GettingStartedStep>> fetchGettingStarted(String creatorId) async {
    try {
      final response = await _api.get(
        ApiEndpoints.creatorDashboard(creatorId, 'getting-started'),
      );
      final steps = (response.data['data'] as Map<String, dynamic>?)?['steps'];
      if (steps is! List) return const [];
      return [
        for (final step in steps)
          if (step is Map<String, dynamic>) GettingStartedStep.fromJson(step),
      ];
    } catch (e) {
      logger.w('Getting-started failed', error: e);
      return const [];
    }
  }

  Future<List<AttentionItem>> fetchAttention(String creatorId) async {
    try {
      final response = await _api.get(
        ApiEndpoints.creatorDashboard(creatorId, 'attention'),
      );
      final items = (response.data['data'] as Map<String, dynamic>?)?['items'];
      if (items is! List) return const [];
      return [
        for (final item in items)
          if (item is Map<String, dynamic>) AttentionItem.fromJson(item),
      ];
    } catch (e) {
      logger.w('Attention failed', error: e);
      return const [];
    }
  }

  /// Views and subscribers over the plan's analytics window.
  ///
  /// The window is sent as an explicit `from`/`to` pair — the route rejects a
  /// named window like "today".
  Future<DashboardPerformance> fetchPerformance(
    String creatorId, {
    int windowDays = 1,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final response = await _api.post(
        ApiEndpoints.creatorDashboardPerformance(creatorId),
        data: {
          'window': {
            'from': now.subtract(Duration(days: windowDays)).toIso8601String(),
            'to': now.toIso8601String(),
          },
        },
      );
      final data = response.data['data'];
      return data is Map<String, dynamic>
          ? DashboardPerformance.fromJson(data)
          : DashboardPerformance.empty;
    } catch (e) {
      logger.w('Performance failed', error: e);
      return DashboardPerformance.empty;
    }
  }
}
