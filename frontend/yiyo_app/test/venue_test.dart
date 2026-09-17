import 'package:flutter_test/flutter_test.dart';
import 'package:yiyo_app/models/venue.dart';

void main() {
  group('Venue.fromJson', () {
    test('parses a venue returned by the API', () {
      final venue = Venue.fromJson({
        'place_id': 'test_place_123',
        'name': 'Test Lounge',
        'lat': -26.2041,
        'lng': 28.0473,
        'rating': 4.3,
        'address': '123 Test Street',
        'types': ['bar', 'night_club'],
        'location_key': '-26.20_28.05',
        'yiyo_badge': 'YIYO',
        'distance_km': 2.5,
        'relevance_score': 8.0,
      });

      expect(venue.id, 'test_place_123');
      expect(venue.name, 'Test Lounge');
      expect(venue.lat, -26.2041);
      expect(venue.lng, 28.0473);
      expect(venue.rating, 4.3);
      expect(venue.address, '123 Test Street');
      expect(venue.types, ['bar', 'night_club']);
      expect(venue.locationKey, '-26.20_28.05');
      expect(venue.yiyoBadge, 'YIYO');
      expect(venue.distanceKm, 2.5);
      expect(venue.relevanceScore, 8.0);
    });

    test('uses defaults when optional venue fields are missing', () {
      final venue = Venue.fromJson({
        'name': 'Basic Venue',
        'lat': -26.0,
        'lng': 28.0,
      });

      expect(venue.id, 'Basic Venue');
      expect(venue.name, 'Basic Venue');
      expect(venue.rating, 0.0);
      expect(venue.address, 'No address available');
      expect(venue.types, isEmpty);
      expect(venue.locationKey, isNull);
      expect(venue.yiyoBadge, isNull);
      expect(venue.distanceKm, isNull);
      expect(venue.relevanceScore, isNull);
    });
  });
}