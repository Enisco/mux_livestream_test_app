import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/onboarding/repo/onboarding_repo.dart';
import 'package:test_app/models/onboarding_models/onboarding_state.dart';
import 'package:test_app/shared/services/api_service.dart';

/// The funnel state the server keeps for a signup in progress.
///
/// `PATCH /v1/user/me/onboarding-state` types every field as a bare
/// `{"type": "object"}`, so nothing in the contract says what may be sent.
/// The validator does, on refusal, and these are the four lists it named on
/// staging (2026-09-26) — every one of them was then replayed against the
/// live route and accepted. If the backend ever narrows a list, the probe in
/// the integration suite is what will catch it; this holds the app to the
/// spellings it agreed to.
class _RecordingApi implements ApiService {
  final List<({String path, Map<String, dynamic> body})> calls = [];
  bool fail = false;

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (fail) {
      throw DioException(requestOptions: RequestOptions(path: path));
    }
    calls.add((path: path, body: data! as Map<String, dynamic>));
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  late _RecordingApi api;
  late OnboardingRepo repo;

  setUp(() {
    api = _RecordingApi();
    repo = OnboardingRepo(api: api);
  });

  group('the wire spellings', () {
    test('status', () {
      expect(OnboardingStatus.notStarted.slug, 'not_started');
      expect(OnboardingStatus.inProgress.slug, 'in_progress');
      expect(OnboardingStatus.completed.slug, 'completed');
      expect(OnboardingStatus.skipped.slug, 'skipped');
    });

    test('intent — the creator answer is NOT "ministry"', () {
      // The app says ministry to the reader; the API refuses that word.
      expect(OnboardingIntentState.watch.slug, 'watch');
      expect(OnboardingIntentState.creator.slug, 'creator');
      expect(OnboardingIntentState.parse('ministry'), isNull);
    });

    test('step', () {
      expect(OnboardingStep.values.map((s) => s.slug), [
        'platform_intent',
        'viewer_preferences',
        'creator_profile_type',
        'creator_profile_form',
        'subscription_plan',
      ]);
    });

    test('creatorType is American here, unlike billingSubject', () {
      expect(OnboardingCreatorType.organization.slug, 'organization');
      expect(OnboardingCreatorType.parse('organisation'), isNull);
    });

    test('an unknown value parses to null rather than a wrong default', () {
      expect(OnboardingStatus.parse('bogus'), isNull);
      expect(OnboardingStep.parse(null), isNull);
    });
  });

  group('what gets sent', () {
    test('only the fields given, because the route merges', () async {
      await repo.updateOnboardingState(step: OnboardingStep.viewerPreferences);
      expect(api.calls.single.path, '/v1/user/me/onboarding-state');
      expect(api.calls.single.body, {'step': 'viewer_preferences'});
    });

    test('a full transition carries everything it knows', () async {
      await repo.updateOnboardingState(
        status: OnboardingStatus.inProgress,
        intent: OnboardingIntentState.creator,
        step: OnboardingStep.creatorProfileForm,
        creatorType: OnboardingCreatorType.organization,
        creatorId: 'c1',
      );
      expect(api.calls.single.body, {
        'status': 'in_progress',
        'intent': 'creator',
        'step': 'creator_profile_form',
        'creatorType': 'organization',
        'creatorId': 'c1',
      });
    });

    test('nothing to say means no request at all', () async {
      await repo.updateOnboardingState();
      expect(api.calls, isEmpty);
    });

    test('a blank creator id is left out rather than sent empty', () async {
      await repo.updateOnboardingState(
        step: OnboardingStep.subscriptionPlan,
        creatorId: '',
      );
      expect(api.calls.single.body.containsKey('creatorId'), isFalse);
    });

    test('a failed write never reaches the caller', () async {
      // This is bookkeeping. Losing it must not stop someone finishing the
      // step they have just completed.
      api.fail = true;
      await expectLater(
        repo.updateOnboardingState(status: OnboardingStatus.completed),
        completes,
      );
    });
  });
}
