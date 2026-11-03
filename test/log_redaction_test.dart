import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/shared/services/log_redaction.dart';

/// Keeping credentials out of the logs.
///
/// Found on the device on 2026-10-29: tapping Give printed the whole checkout
/// response to logcat, launch ticket included. The ticket is single-use and
/// short-lived, which lowers the stakes without changing them — logcat is
/// readable, and a debug log is what ends up in a bug report.
void main() {
  group('a checkout response', () {
    test('the launch url is masked, and the session is not', () {
      // Which session was created is the only thing logging this is good for.
      final out =
          redactSecrets({
                'data': {
                  'session': {
                    'id': 'cmvt82ep801g7ku138rhr5t76',
                    'status': 'created',
                  },
                  'launchUrl':
                      'https://auth.staging.gospeltube.tv/api/auth/'
                      'browser-handoff?ticket=NYGG1MgLylgaxrQ2bumoNZgRKZIdK5L',
                  'launchExpiresAt': '2026-10-29T07:29:51.019Z',
                },
              })
              as Map;
      final data = out['data'] as Map;
      expect(data['launchUrl'], '<redacted>');
      expect(data['launchExpiresAt'], '2026-10-29T07:29:51.019Z');
      expect((data['session'] as Map)['id'], 'cmvt82ep801g7ku138rhr5t76');
    });

    test('the key survives so the log still shows one came back', () {
      final out = redactSecrets({'launchUrl': 'x'}) as Map;
      expect(out.containsKey('launchUrl'), isTrue);
    });

    test('a provider payment page is masked', () {
      final out =
          redactSecrets({
                'hostedAuthorizationUrl': 'https://checkout.stripe.com/c/pay/x',
              })
              as Map;
      expect(out['hostedAuthorizationUrl'], '<redacted>');
    });

    test('embedded processor credentials are masked whole', () {
      // The Khaime token carries processor credentials; the guide says never
      // to log, store or parse it.
      final out =
          redactSecrets({
                'embedded': {
                  'khaime': {'token': 'secret', 'chargeId': 'ch_1'},
                },
              })
              as Map;
      expect(out['embedded'], '<redacted>');
    });

    test('tokens are masked wherever they sit', () {
      final out =
          redactSecrets({
                'data': {
                  'accessToken': 'a',
                  'refreshToken': 'b',
                  'user': {'id': 'u1'},
                },
              })
              as Map;
      final data = out['data'] as Map;
      expect(data['accessToken'], '<redacted>');
      expect(data['refreshToken'], '<redacted>');
      expect((data['user'] as Map)['id'], 'u1');
    });

    test('a ticket in a field nobody listed is still masked', () {
      // The key list cannot anticipate every name the gateway might use, so
      // any string that carries a credential-bearing query parameter is
      // cleaned on the way past regardless of what it is called.
      final out =
          redactSecrets({
                'redirect':
                    'https://auth.gospeltube.tv/handoff?ticket=abc&flow=giving',
              })
              as Map;
      expect(out['redirect'], contains('ticket=%3Credacted%3E'));
      expect(out['redirect'], contains('flow=giving'));
    });

    test('a list of rows is walked, not skipped', () {
      final out =
          redactSecrets({
                'items': [
                  {'id': 'a', 'ticket': 'secret'},
                ],
              })
              as Map;
      expect(((out['items'] as List).single as Map)['ticket'], '<redacted>');
    });
  });

  group('a bare url', () {
    test('loses its ticket but keeps the rest', () {
      expect(
        redactUrl('https://auth.gospeltube.tv/handoff?ticket=abc&flow=giving'),
        'https://auth.gospeltube.tv/handoff?ticket=%3Credacted%3E&flow=giving',
      );
    });

    test('a return link keeps its session, which is not a credential', () {
      // The session id is matched against a local attempt and proves nothing
      // on its own; masking it would make a return impossible to debug.
      const link =
          'https://app.gospeltube.tv/mobile/payments/return?session=g1';
      expect(redactUrl(link), link);
    });

    test('ordinary text is left alone', () {
      expect(
        redactUrl('Giving could not be started'),
        'Giving could not be started',
      );
      expect(redactSecrets('plain'), 'plain');
    });

    test('a url with no query is left alone', () {
      expect(
        redactUrl('https://api.staging.gospeltube.tv/v1/payment/x'),
        'https://api.staging.gospeltube.tv/v1/payment/x',
      );
    });

    test('something that is not a url is not mangled', () {
      expect(redactUrl('a?b=c'), 'a?b=c');
    });
  });

  test('a null body does not throw', () {
    expect(redactSecrets(null), isNull);
  });
}
