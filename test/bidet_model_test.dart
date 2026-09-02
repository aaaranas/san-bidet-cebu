import 'package:flutter_test/flutter_test.dart';
import 'package:san_bidet_cebu/data/models/bidet.dart';

import 'fakes.dart';

void main() {
  group('Bidet.fromMap', () {
    test('parses a full row', () {
      final bidet = Bidet.fromMap({
        'id': 'abc',
        'place_name': 'Ayala Center',
        'floor': 'Ground floor',
        'type': 'bidet_seat',
        'latitude': 10.3181,
        'longitude': 123.9057,
        'rating': 4.25,
        'rating_count': 4,
        'created_at': '2026-02-03T10:00:00Z',
        'status': 'approved',
        'image_url': 'https://example.test/a.jpg',
        'cleanliness_rating': 4.5,
        'pressure_rating': 4.0,
        'accessibility_rating': 4.5,
        'privacy_rating': 4.0,
      });

      expect(bidet.id, 'abc');
      expect(bidet.type, BidetType.bidetSeat);
      expect(bidet.typeLabel, 'Bidet seat');
      expect(bidet.status, BidetStatus.approved);
      expect(bidet.rating, 4.25);
      expect(bidet.createdAt.year, 2026);
    });

    test('falls back safely on unknown or missing values', () {
      final bidet = Bidet.fromMap({'id': 'x', 'type': 'not_a_real_type'});

      expect(bidet.type, BidetType.sprayHose);
      expect(bidet.status, BidetStatus.pending);
      expect(bidet.rating, 0);
      expect(bidet.ratingCount, 0);
      expect(bidet.placeName, isEmpty);
    });

    test('handles integer coordinates from Postgres', () {
      final bidet = Bidet.fromMap({'id': 'x', 'latitude': 10, 'longitude': 123});

      expect(bidet.latitude, 10.0);
      expect(bidet.longitude, 123.0);
    });
  });

  group('value equality', () {
    // This is what the map stream relies on to avoid rebuilding on every
    // snapshot. The previous model had identity equality, so the old
    // Stream.distinct() never actually de-duplicated anything.
    test('identical content compares equal', () {
      expect(makeBidet(), equals(makeBidet()));
      expect(makeBidet().hashCode, equals(makeBidet().hashCode));
    });

    test('differing content compares unequal', () {
      expect(makeBidet(rating: 3), isNot(equals(makeBidet(rating: 4))));
    });

    test('a list of unchanged bidets compares equal', () {
      final a = [makeBidet(id: 'a'), makeBidet(id: 'b')];
      final b = [makeBidet(id: 'a'), makeBidet(id: 'b')];
      expect(a, equals(b));
    });
  });

  group('toInsert', () {
    test('omits server-managed columns', () {
      final map = makeBidet().toInsert(userId: 'u1');

      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('created_at'), isFalse);
      expect(map.containsKey('rating'), isFalse);
      expect(map.containsKey('rating_count'), isFalse);
      expect(map['submitted_by'], 'u1');
      expect(map['type'], 'spray_hose');
    });

    test('omits submitted_by when signed out', () {
      expect(makeBidet().toInsert().containsKey('submitted_by'), isFalse);
    });
  });

  group('new fields', () {
    test('parses access, fee and rejection reason', () {
      final bidet = Bidet.fromMap({
        'id': 'x',
        'access_type': 'customer',
        'hours_note': 'Mall hours',
        'fee_note': 'PHP 5',
        'status': 'rejected',
        'rejection_reason': 'Already listed',
      });

      expect(bidet.accessType, AccessType.customer);
      expect(bidet.accessType.label, 'Customers only');
      expect(bidet.hoursNote, 'Mall hours');
      expect(bidet.feeNote, 'PHP 5');
      expect(bidet.status, BidetStatus.rejected);
      expect(bidet.rejectionReason, 'Already listed');
    });

    test('falls back to public access on an unknown value', () {
      expect(
        Bidet.fromMap({'id': 'x', 'access_type': 'nonsense'}).accessType,
        AccessType.public,
      );
    });

    test('reads the embedded contributor username', () {
      final bidet = Bidet.fromMap({
        'id': 'x',
        'profiles': {'username': 'bidet_hunter'},
      });
      expect(bidet.submittedByUsername, 'bidet_hunter');
    });

    test('tolerates a missing profile embed', () {
      expect(Bidet.fromMap({'id': 'x'}).submittedByUsername, isNull);
      expect(
        Bidet.fromMap({'id': 'x', 'profiles': null}).submittedByUsername,
        isNull,
      );
    });

    test('toInsert carries access details but omits empty optional notes', () {
      final map = makeBidet()
          .copyWith(accessType: AccessType.staff, hoursNote: '', feeNote: 'PHP 5')
          .toInsert(userId: 'u1');

      expect(map['access_type'], 'staff');
      expect(map.containsKey('hours_note'), isFalse);
      expect(map['fee_note'], 'PHP 5');
    });
  });

  group('BidetRating round trip', () {
    test('reads a stored rating back', () {
      final r = BidetRating.fromMap({
        'cleanliness': 5,
        'pressure': 4,
        'accessibility': 3,
        'privacy': 4.0,
      });
      expect(r.cleanliness, 5);
      expect(r.overall, 4.0);
      expect(r.isComplete, isTrue);
    });
  });

  group('NearbyBidet', () {
    test('parses the proximity RPC result', () {
      final n = NearbyBidet.fromMap({
        'id': 'abc',
        'place_name': 'SM City Cebu',
        'floor': '3F',
        'distance_m': 18.4,
      });
      expect(n.placeName, 'SM City Cebu');
      expect(n.distanceMeters, closeTo(18.4, 0.01));
    });
  });

  group('ReportKind', () {
    test('maps ids and falls back to other', () {
      expect(ReportKind.fromId('gone'), ReportKind.gone);
      expect(ReportKind.fromId('nope'), ReportKind.other);
    });
  });

  group('BidetRating', () {
    test('overall is the mean of the four criteria', () {
      const rating = BidetRating(
        cleanliness: 5,
        pressure: 4,
        accessibility: 3,
        privacy: 4,
      );
      expect(rating.overall, 4.0);
    });

    test('isComplete requires all four', () {
      const partial = BidetRating(
        cleanliness: 5,
        pressure: 0,
        accessibility: 3,
        privacy: 4,
      );
      expect(partial.isComplete, isFalse);
    });
  });
}
