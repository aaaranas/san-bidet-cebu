// Native Android/iOS Mapbox map (mapbox_maps_flutter, Standard 3D style).
// Compiled only on dart:io platforms (see mobile_map.dart); web uses the stub.
import 'package:flutter/widgets.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../bidet/bidet_model.dart';

/// Drives the native map camera (fly-to) from the map screen.
class MobileMapController {
  MapboxMap? _map;
  void attach(MapboxMap map) => _map = map;

  void flyTo(double lat, double lng, double zoom) {
    _map?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
        pitch: 60,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }
}

class MobileMapboxMap extends StatefulWidget {
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
  State<MobileMapboxMap> createState() => _MobileMapboxMapState();
}

class _MobileMapboxMapState extends State<MobileMapboxMap> {
  MapboxMap? _map;
  CircleAnnotationManager? _bidetManager;
  CircleAnnotationManager? _userManager;
  final Map<String, String> _annToBidet = {};

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(widget.token);
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    widget.controller.attach(map);
    _bidetManager = await map.annotations.createCircleAnnotationManager();
    _userManager = await map.annotations.createCircleAnnotationManager();
    _bidetManager!.tapEvents(
      onTap: (ann) {
        final id = _annToBidet[ann.id];
        if (id != null) widget.onMarkerTap(id);
      },
    );
    await _drawBidets();
    await _drawUser();
  }

  // Standard style → dark "dusk" lighting to match the web map.
  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    try {
      await _map?.style
          .setStyleImportConfigProperty('basemap', 'lightPreset', 'dusk');
    } catch (_) {}
  }

  Future<void> _drawBidets() async {
    final mgr = _bidetManager;
    if (mgr == null) return;
    await mgr.deleteAll();
    _annToBidet.clear();
    for (final b in widget.bidets) {
      final ann = await mgr.create(CircleAnnotationOptions(
        geometry: Point(coordinates: Position(b.longitude, b.latitude)),
        circleRadius: 8.0,
        circleColor: 0xFF0F172A,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2.5,
      ));
      _annToBidet[ann.id] = b.id;
    }
  }

  Future<void> _drawUser() async {
    final mgr = _userManager;
    if (mgr == null) return;
    await mgr.deleteAll();
    if (widget.userLat == null || widget.userLng == null) return;
    await mgr.create(CircleAnnotationOptions(
      geometry: Point(coordinates: Position(widget.userLng!, widget.userLat!)),
      circleRadius: 7.0,
      circleColor: 0xFF2196F3,
      circleStrokeColor: 0xFFFFFFFF,
      circleStrokeWidth: 3.0,
    ));
  }

  @override
  void didUpdateWidget(MobileMapboxMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bidets != widget.bidets) _drawBidets();
    if (oldWidget.userLat != widget.userLat ||
        oldWidget.userLng != widget.userLng) {
      _drawUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('mobile-mapbox'),
      styleUri: MapboxStyles.STANDARD,
      viewport: CameraViewportState(
        center: Point(coordinates: Position(widget.centerLng, widget.centerLat)),
        zoom: widget.zoom,
        pitch: widget.pitch,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }
}
