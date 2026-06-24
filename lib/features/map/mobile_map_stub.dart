// Web stub for MobileMapboxMap. Never instantiated on web (the map screen
// guards by platform), but must exist so the web build compiles without
// importing the Android/iOS-only mapbox_maps_flutter package.
import 'package:flutter/widgets.dart';

import '../bidet/bidet_model.dart';

class MobileMapController {
  void flyTo(double lat, double lng, double zoom) {}
}

class MobileMapboxMap extends StatelessWidget {
  final MobileMapController controller;
  final String token;
  final double centerLat;
  final double centerLng;
  final double zoom;
  final double pitch;
  final List<Bidet> bidets;
  final double? userLat;
  final double? userLng;
  final void Function(String bidetId) onMarkerTap;

  const MobileMapboxMap({
    super.key,
    required this.controller,
    required this.token,
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.pitch,
    required this.bidets,
    required this.onMarkerTap,
    this.userLat,
    this.userLng,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
