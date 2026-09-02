import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Why a location request failed, so the UI can say something specific
/// instead of a flat "Could not get location."
enum LocationError { serviceDisabled, denied, deniedForever, failed }

class LocationResult {
  final Position? position;
  final LocationError? error;

  const LocationResult.success(Position this.position) : error = null;
  const LocationResult.failure(LocationError this.error) : position = null;

  bool get ok => position != null;

  String get message => switch (error) {
        LocationError.serviceDisabled =>
          'Location services are turned off. Enable them and try again.',
        LocationError.denied =>
          'Location permission is needed to place a bidet on the map.',
        LocationError.deniedForever =>
          'Location is blocked for this app. Enable it in your settings.',
        _ => 'Could not get your location. Please try again.',
      };
}

class LocationService {
  const LocationService();

  Future<LocationResult> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failure(LocationError.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failure(LocationError.denied);
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failure(LocationError.deniedForever);
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      return LocationResult.success(position);
    } catch (_) {
      return const LocationResult.failure(LocationError.failed);
    }
  }

  double distanceBetween(LatLng a, LatLng b) => Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );

  String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    if (meters < 10000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${(meters / 1000).round()}km';
  }
}
