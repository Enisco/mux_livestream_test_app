import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/models/discovery_models/content_detail.dart';
import 'package:test_app/shared/services/maps_launcher.dart';

/// Getting to an event.
///
/// The design draws a map preview with a pin. An event carries only text —
/// `label`, `addressLine`, `city` — and no coordinates, and the app has no
/// maps SDK or key, so there is nothing to place a pin at. Handing the
/// address to the reader's own map app costs nothing and does more.
///
/// The payload shape below is `GET /v1/public/content/events/{id}` on
/// staging, 2026-09-26.
EventDetail _event(
  Map<String, dynamic> location, {
  String venue = 'physical',
}) => EventDetail.fromJson({
  'data': {
    'id': 'e1',
    'title': 'Encounter Conference',
    'venueType': venue,
    'location': location,
  },
});

void main() {
  group('reading the location', () {
    test('the three parts are all kept', () {
      final event = _event(const {
        'label': 'Lekki Conference Centre',
        'addressLine': '1 Admiralty Way',
        'city': 'Lagos',
      });
      expect(event.locationLabel, 'Lekki Conference Centre');
      expect(event.addressLine, '1 Admiralty Way');
      expect(event.city, 'Lagos');
    });

    test('and read back as one address, in the order it is spoken', () {
      final event = _event(const {
        'label': 'Lekki Conference Centre',
        'addressLine': '1 Admiralty Way',
        'city': 'Lagos',
      });
      expect(
        event.fullAddress,
        'Lekki Conference Centre, 1 Admiralty Way, Lagos',
      );
    });

    test('a venue name on its own is still enough to search for', () {
      final event = _event(const {'label': 'Lekki Conference Centre'});
      expect(event.hasPlace, isTrue);
      expect(event.fullAddress, 'Lekki Conference Centre');
    });

    test('blanks are dropped rather than left as empty commas', () {
      final event = _event(const {
        'label': 'Somewhere',
        'addressLine': '   ',
        'city': '',
      });
      expect(event.fullAddress, 'Somewhere');
    });

    test('an event with no location at all has no place to point at', () {
      expect(_event(const {}).hasPlace, isFalse);
      expect(_event(const {}).fullAddress, isNull);
    });

    test('an online event is not sent to a map', () {
      final event = _event(const {'label': 'Zoom'}, venue: 'virtual');
      expect(event.isOnline, isTrue);
      expect(event.hasPlace, isFalse);
    });

    test('and its meeting link is kept instead', () {
      final event = _event(const {
        'meetingUrl': 'https://meet.example.test/abc',
      }, venue: 'virtual');
      expect(event.meetingUrl, 'https://meet.example.test/abc');
    });
  });

  group('handing an address to a map app', () {
    test('the address is escaped into the query', () {
      final uris = MapsLauncher.urisFor('1 Admiralty Way, Lagos');
      expect(uris, isNotEmpty);
      for (final uri in uris) {
        expect(uri.toString(), contains('Admiralty'));
        // Spaces and commas must not survive raw.
        expect(uri.toString(), isNot(contains(' ')));
      }
    });

    test('there is always a web fallback for a device with no map app', () {
      final uris = MapsLauncher.urisFor('Lekki Conference Centre');
      expect(uris.last.host, 'www.google.com');
      expect(uris.last.toString(), contains('maps/search'));
    });

    test('nothing in, nothing to open', () {
      expect(MapsLauncher.urisFor(''), isEmpty);
      expect(MapsLauncher.urisFor('   '), isEmpty);
    });
  });
}
