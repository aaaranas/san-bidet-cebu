// Non-web stub for WebMapboxMap. Mobile/desktop never instantiate this (the
// map screen guards with kIsWeb), but it must exist so the app compiles off-web.
import 'package:flutter/widgets.dart';

import '../bidet/bidet_model.dart';

class WebMapController {
  void flyTo(double lat, double lng, double zoom) {}
}

class WebMapboxMap extends StatelessWidget {
  final WebMapController controller;
  final String token;
  final double centerLat;
  final double centerLng;
  final double zoom;
  final double pitch;
  final List<Bidet> bidets;
  final double? userLat;
  final double? userLng;
  final void Function(String bidetId) onMarkerTap;

  const WebMapboxMap({
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
