import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/onboarding/repo/onboarding_repo.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

class _FakeApi implements ApiService {
  String? path;
  Map<String, dynamic>? body;
  var calls = 0;

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    calls++;
    this.path = path;
    body = data as Map<String, dynamic>?;
    return Response<T>(requestOptions: RequestOptions(path: path));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

void main() {
  late _FakeApi api;
  late OnboardingRepo repo;

  setUp(() {
    api = _FakeApi();
    repo = OnboardingRepo(api: api);
  });

  test('sends all three fields in one payload', () async {
    await repo.updateViewerPreferences(
      categorySlugs: ['worship', 'devotionals', 'family'],
      discoverySource: 'friend',
      discoveryDetail: 'a colleague',
    );

    expect(api.path, ApiEndpoints.viewerPreferences);
    expect(api.body, {
      'categorySlugs': ['worship', 'devotionals', 'family'],
      'registrationDiscoverySource': 'friend',
      'registrationDiscoveryDetail': 'a colleague',
    });
  });

  test('keeps categorySlugs when only the discovery fields change', () async {
    await repo.updateViewerPreferences(
      categorySlugs: ['worship'],
      discoverySource: 'church',
    );

    expect(api.body!.containsKey('categorySlugs'), isTrue);
    expect(api.body!['categorySlugs'], ['worship']);
    expect(api.body!['registrationDiscoverySource'], 'church');
  });

  test('omits what was not supplied rather than sending nulls', () async {
    await repo.updateViewerPreferences(categorySlugs: ['prayer']);

    expect(api.body, {
      'categorySlugs': ['prayer'],
    });
  });

  test('does not call the API when there is nothing to send', () async {
    await repo.updateViewerPreferences();
    await repo.updateViewerPreferences(
      discoverySource: '',
      discoveryDetail: '',
    );

    expect(api.calls, 0);
  });
}
