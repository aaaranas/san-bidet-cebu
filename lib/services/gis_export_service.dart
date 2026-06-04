import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../features/bidet/bidet_model.dart';

/// Turns the bidet dataset into GIS-ready files and hands them off to the
/// platform share sheet.
///
/// GeoJSON (EPSG:4326 / WGS84) is the interchange format here because every
/// desktop GIS — QGIS, ArcGIS Pro, etc. — opens it natively and can re-export
/// it to an ESRI Shapefile in one step (in QGIS: right-click the layer →
/// Export → Save Features As → ESRI Shapefile). Generating a raw .shp bundle
/// on-device would mean emitting four coupled binary files (.shp/.shx/.dbf/
/// .prj); GeoJSON is a single, lossless, text source for all of them.
enum GisFormat { geoJson, csv }

class GisExportService {
  /// Builds an RFC 7946 FeatureCollection. Coordinates are [lon, lat].
  String buildGeoJson(List<Bidet> bidets) {
    final features = bidets.map((b) {
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [b.longitude, b.latitude],
        },
        'properties': _properties(b),
      };
    }).toList();

    final collection = {
      'type': 'FeatureCollection',
      'name': 'san_bidet_cebu',
      // CRS84 is lon/lat WGS84 — the default GeoJSON datum.
      'crs': {
        'type': 'name',
        'properties': {'name': 'urn:ogc:def:crs:OGC:1.3:CRS84'},
      },
      'features': features,
    };

    return const JsonEncoder.withIndent('  ').convert(collection);
  }

  /// Delimited points with a WKT geometry column — handy for importing as a
  /// "delimited text layer" or loading straight into PostGIS.
  String buildCsv(List<Bidet> bidets) {
    const headers = [
      'id',
      'place_name',
      'floor',
      'type',
      'latitude',
      'longitude',
      'wkt',
      'rating',
      'rating_count',
      'cleanliness_rating',
      'pressure_rating',
      'accessibility_rating',
      'privacy_rating',
      'status',
      'created_at',
    ];

    final rows = <String>[headers.join(',')];
    for (final b in bidets) {
      rows.add([
        b.id,
        b.placeName,
        b.floor,
        b.type,
        b.latitude.toString(),
        b.longitude.toString(),
        'POINT (${b.longitude} ${b.latitude})',
        b.rating.toString(),
        b.ratingCount.toString(),
        b.cleanlinessRating.toString(),
        b.pressureRating.toString(),
        b.accessibilityRating.toString(),
        b.privacyRating.toString(),
        b.status,
        b.createdAt.toIso8601String(),
      ].map(_csvCell).join(','));
    }
    return rows.join('\n');
  }

  Map<String, dynamic> _properties(Bidet b) => {
        'id': b.id,
        'place_name': b.placeName,
        'floor': b.floor,
        'type': b.type,
        'type_label': b.typeLabel,
        'rating': b.rating,
        'rating_count': b.ratingCount,
        'cleanliness_rating': b.cleanlinessRating,
        'pressure_rating': b.pressureRating,
        'accessibility_rating': b.accessibilityRating,
        'privacy_rating': b.privacyRating,
        'status': b.status,
        'created_at': b.createdAt.toIso8601String(),
        'image_url': b.imageUrl,
      };

  String _csvCell(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Writes the chosen format to a file and opens the share sheet. Returns the
  /// file name that was shared.
  Future<String> export(List<Bidet> bidets, GisFormat format) async {
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final String content;
    final String fileName;
    final String mime;

    switch (format) {
      case GisFormat.geoJson:
        content = buildGeoJson(bidets);
        fileName = 'san_bidet_cebu_$stamp.geojson';
        mime = 'application/geo+json';
        break;
      case GisFormat.csv:
        content = buildCsv(bidets);
        fileName = 'san_bidet_cebu_$stamp.csv';
        mime = 'text/csv';
        break;
    }

    final bytes = Uint8List.fromList(utf8.encode(content));

    if (kIsWeb) {
      // No filesystem on web — share the bytes directly (triggers a download).
      await Share.shareXFiles([
        XFile.fromData(bytes, mimeType: mime, name: fileName),
      ], subject: fileName);
      return fileName;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mime, name: fileName)],
      subject: 'SanBidet Cebu — GIS export',
    );
    return fileName;
  }
}
