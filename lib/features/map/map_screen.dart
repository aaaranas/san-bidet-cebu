import 'dart:ui' as ui;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/supabase_service.dart';
import '../../services/location_service.dart';
import '../../widgets/bidet_card.dart';
import '../bidet/bidet_add_screen.dart';
import '../bidet/bidet_detail_screen.dart';
import '../bidet/bidet_model.dart';
import 'mobile_map.dart';
import 'web_map_interop.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _green = Color(0xFF0F172A);
  static const _cebu = LatLng(10.3157, 123.8854);

  // Mapbox access token — passed at build/run time via:
  //   --dart-define=MAPBOX_TOKEN=pk.your_token_here
  static const _mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

  final _mapController = MapController();
  final _webController = WebMapController();
  final _mobileController = MobileMapController();
  final _supabaseService = SupabaseService();
  final _locationService = LocationService();
  final _searchController = TextEditingController();

  Position? _userPosition;
  List<Bidet> _bidets = [];
  String? _selectedBidetId;
  String _searchQuery = '';

  // Map style switching --------------------------------------------------
  static const _styles = <_MapStyle>[
    _MapStyle(
      id: MapStyleId.map,
      label: 'Map',
      icon: Icons.map_outlined,
      url:
          'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap, © CARTO',
      dark: false,
    ),
    _MapStyle(
      id: MapStyleId.satellite,
      label: 'Satellite',
      icon: Icons.satellite_alt_outlined,
      url:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      attribution: 'Imagery © Esri',
      dark: true,
    ),
    _MapStyle(
      id: MapStyleId.hybrid,
      label: 'Hybrid',
      icon: Icons.layers_outlined,
      url:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      overlayUrl:
          'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
      attribution: 'Imagery © Esri',
      dark: true,
    ),
    _MapStyle(
      id: MapStyleId.terrain,
      label: 'Terrain',
      icon: Icons.terrain_outlined,
      url:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
      attribution: 'Topo © Esri',
      dark: false,
    ),
  ];

  MapStyleId _styleId = MapStyleId.map;
  bool _layersOpen = false;

  _MapStyle get _style => _styles.firstWhere((s) => s.id == _styleId);

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _loadBidets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBidets() async {
    _supabaseService.getBidets().listen((bidets) {
      if (mounted) setState(() => _bidets = bidets);
    });
  }

  Future<void> _fetchLocation() async {
    final pos = await _locationService.getCurrentPosition();
    if (mounted) setState(() => _userPosition = pos);
  }

  String _distance(Bidet bidet) {
    if (_userPosition == null) return '';
    final meters = _locationService.distanceBetween(
      LatLng(_userPosition!.latitude, _userPosition!.longitude),
      LatLng(bidet.latitude, bidet.longitude),
    );
    return _locationService.formatDistance(meters);
  }

  List<Bidet> _sortedByDistance(List<Bidet> bidets) {
    if (_userPosition == null) return bidets;
    final sorted = [...bidets];
    sorted.sort((a, b) {
      final da = _locationService.distanceBetween(
        LatLng(_userPosition!.latitude, _userPosition!.longitude),
        LatLng(a.latitude, a.longitude),
      );
      final db = _locationService.distanceBetween(
        LatLng(_userPosition!.latitude, _userPosition!.longitude),
        LatLng(b.latitude, b.longitude),
      );
      return da.compareTo(db);
    });
    return sorted;
  }

  List<Bidet> get _filtered {
    final sorted = _sortedByDistance(_bidets);
    if (_searchQuery.isEmpty) return sorted;
    final q = _searchQuery.toLowerCase();
    return sorted
        .where((b) =>
            b.placeName.toLowerCase().contains(q) ||
            b.floor.toLowerCase().contains(q))
        .toList();
  }

  void _selectAndFly(Bidet bidet) {
    setState(() => _selectedBidetId = bidet.id);
    if (kIsWeb) {
      _webController.flyTo(bidet.latitude, bidet.longitude, 17);
    } else if (_useNativeMapbox) {
      _mobileController.flyTo(bidet.latitude, bidet.longitude, 17);
    } else {
      _mapController.move(LatLng(bidet.latitude, bidet.longitude), 17);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),

          // App bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.water_drop_outlined,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'SanBidet Cebu',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    ),
                    const Spacer(),
                    Text(
                      '${_bidets.length} bidets',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Layer switcher (raster styles only — not used by the web 3D map)
          if (!kIsWeb)
            Positioned(
              right: 16,
              bottom: 312,
              child: _buildLayerSwitcher(),
            ),

          // My location button
          Positioned(
            right: 16,
            bottom: 260,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              onPressed: () {
                if (_userPosition != null) {
                  if (kIsWeb) {
                    _webController.flyTo(_userPosition!.latitude,
                        _userPosition!.longitude, 16);
                  } else if (_useNativeMapbox) {
                    _mobileController.flyTo(_userPosition!.latitude,
                        _userPosition!.longitude, 16);
                  } else {
                    _mapController.move(
                      LatLng(_userPosition!.latitude,
                          _userPosition!.longitude),
                      15,
                    );
                  }
                } else {
                  _fetchLocation();
                }
              },
              backgroundColor: Colors.white,
              foregroundColor: _green,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Attribution badge (web shows Mapbox's own built-in attribution)
          if (!kIsWeb)
            Positioned(
              left: 12,
              bottom: 312,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _style.attribution,
                    style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),

          // Bottom sheet
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.12,
            maxChildSize: 0.75,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2))
                  ],
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        margin:
                            const EdgeInsets.symmetric(vertical: 10),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nearby bidets (${_bidets.length})',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _searchController,
                            onChanged: (v) =>
                                setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: 'Search by name or location…',
                              hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 13),
                              prefixIcon: Icon(Icons.search,
                                  color: Colors.grey.shade400,
                                  size: 18),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        setState(
                                            () => _searchQuery = '');
                                      },
                                      child: Icon(Icons.close,
                                          color: Colors.grey.shade400,
                                          size: 18),
                                    )
                                  : null,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.grey.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: _green),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.wc_outlined,
                                      size: 48,
                                      color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'No bidets yet — be the first!'
                                        : 'No results for "$_searchQuery"',
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                  20, 0, 20, 20),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final bidet = filtered[i];
                                return BidetCard(
                                  bidet: bidet,
                                  distance: _distance(bidet),
                                  onTap: () {
                                    _selectAndFly(bidet);
                                    _openDetail(bidet);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BidetAddScreen()),
        ),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // True on Android/iOS, where the native Mapbox SDK is used.
  bool get _useNativeMapbox =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _onMapboxMarkerTap(String id) {
    final match = _bidets.where((b) => b.id == id);
    if (match.isNotEmpty) {
      _selectAndFly(match.first);
      _openDetail(match.first);
    }
  }

  Widget _buildMap() {
    // Web: Mapbox GL JS v3 — 3D "Standard" style with pitch + 3D buildings.
    if (kIsWeb) {
      return WebMapboxMap(
        controller: _webController,
        token: _mapboxToken,
        centerLat: _cebu.latitude,
        centerLng: _cebu.longitude,
        zoom: 15,
        pitch: 55,
        bidets: _bidets,
        userLat: _userPosition?.latitude,
        userLng: _userPosition?.longitude,
        onMarkerTap: _onMapboxMarkerTap,
      );
    }

    // Android/iOS: native Mapbox SDK — same 3D Standard style.
    if (_useNativeMapbox) {
      return MobileMapboxMap(
        controller: _mobileController,
        token: _mapboxToken,
        centerLat: _cebu.latitude,
        centerLng: _cebu.longitude,
        zoom: 15,
        pitch: 55,
        bidets: _bidets,
        userLat: _userPosition?.latitude,
        userLng: _userPosition?.longitude,
        onMarkerTap: _onMapboxMarkerTap,
      );
    }

    // Desktop fallback: flutter_map raster tiles.
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: _cebu,
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          key: ValueKey(_style.id),
          urlTemplate: _style.url,
          userAgentPackageName: 'com.example.san_bidet_cebu',
          maxNativeZoom: 19,
        ),
        if (_style.overlayUrl != null)
          TileLayer(
            key: ValueKey('${_style.id}-overlay'),
            urlTemplate: _style.overlayUrl!,
            userAgentPackageName: 'com.example.san_bidet_cebu',
            maxNativeZoom: 19,
          ),
        MarkerLayer(
          markers: [
            if (_userPosition != null)
              Marker(
                point:
                    LatLng(_userPosition!.latitude, _userPosition!.longitude),
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ..._bidets.map((bidet) {
              final isSelected = _selectedBidetId == bidet.id;
              return Marker(
                point: LatLng(bidet.latitude, bidet.longitude),
                width: 44,
                height: 54,
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {
                    _selectAndFly(bidet);
                    _openDetail(bidet);
                  },
                  child: _buildMarker(isSelected),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildLayerSwitcher() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle button
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _layersOpen = !_layersOpen),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                _layersOpen ? Icons.close : Icons.layers_outlined,
                color: _green,
                size: 22,
              ),
            ),
          ),
          // Expanding option list
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: _layersOpen ? 1 : 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 1,
                    color: Colors.grey.shade200,
                  ),
                  for (final s in _styles) _layerOption(s),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _layerOption(_MapStyle s) {
    final selected = s.id == _styleId;
    return Tooltip(
      message: s.label,
      child: InkWell(
        onTap: () => setState(() {
          _styleId = s.id;
          _layersOpen = false;
        }),
        child: Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? _green : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  s.icon,
                  size: 17,
                  color: selected ? Colors.white : _green,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                s.label,
                style: TextStyle(
                  fontSize: 8,
                  height: 1.1,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _green : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarker(bool isSelected) {
    final color = isSelected ? const Color(0xFFE65100) : _green;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.wc, color: Colors.white, size: 20),
        ),
        CustomPaint(
          size: const Size(14, 10),
          painter: _PinTipPainter(color: color),
        ),
      ],
    );
  }

  void _openDetail(Bidet bidet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BidetDetailScreen(
          bidet: bidet,
          distance: _distance(bidet),
        ),
      ),
    );
  }
}

enum MapStyleId { map, satellite, hybrid, terrain }

class _MapStyle {
  final MapStyleId id;
  final String label;
  final IconData icon;
  final String url;
  final String? overlayUrl;
  final String attribution;
  final bool dark;

  const _MapStyle({
    required this.id,
    required this.label,
    required this.icon,
    required this.url,
    this.overlayUrl,
    required this.attribution,
    required this.dark,
  });
}

class _PinTipPainter extends CustomPainter {
  final Color color;
  const _PinTipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTipPainter old) => old.color != color;
}
