import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:san_bidet_cebu/data/models/bidet.dart';
import 'package:san_bidet_cebu/services/gis_export_service.dart';

import 'fakes.dart';

void main() {
  const service = GisExportService();

  group('GeoJSON', () {
    test('emits an RFC 7946 FeatureCollection in lon/lat order', () {
      final json = jsonDecode(service.buildGeoJson([makeBidet()]))
          as Map<String, dynamic>;

      expect(json['type'], 'FeatureCollection');
      final feature = (json['features'] as List).single as Map<String, dynamic>;
      final coords = feature['geometry']['coordinates'] as List;

      // GeoJSON is [longitude, latitude] — the opposite of how they are
      // usually written. Getting this backwards puts Cebu in Somalia.
      expect(coords[0], 123.8854);
      expect(coords[1], 10.3157);
    });

    test('serialises enums by their database id', () {
      final json = jsonDecode(
        service.buildGeoJson([
          makeBidet(type: BidetType.tabo, status: BidetStatus.pending),
        ]),
      ) as Map<String, dynamic>;

      final props = (json['features'] as List).single['properties'];
      expect(props['type'], 'tabo');
      expect(props['status'], 'pending');
      expect(props['type_label'], 'Tabo');
    });
  });

  group('CSV', () {
    test('writes a header plus one row per bidet', () {
      final csv = service.buildCsv([
        makeBidet(id: 'a'),
        makeBidet(id: 'b'),
      ]);
      final lines = const LineSplitter().convert(csv);

      expect(lines.first, startsWith('id,place_name,floor,type'));
      expect(lines, hasLength(3));
    });

    test('quotes fields containing commas and escapes quotes', () {
      final csv = service.buildCsv([
        makeBidet(placeName: 'Robinsons, Galleria'),
      ]);
      expect(csv, contains('"Robinsons, Galleria"'));

      final quoted = service.buildCsv([makeBidet(placeName: 'The "Good" One')]);
      expect(quoted, contains('"The ""Good"" One"'));
    });

    test('includes a WKT point column for PostGIS', () {
      final csv = service.buildCsv([makeBidet()]);
      expect(csv, contains('POINT (123.8854 10.3157)'));
    });
  });
}
