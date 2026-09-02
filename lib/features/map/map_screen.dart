import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_config.dart';
import '../../core/app_scope.dart';
import '../../core/theme.dart';
import '../../core/router.dart';
import '../../data/models/bidet.dart';
import '../../widgets/bidet_card.dart';
import '../bidet/bidet_detail_screen.dart';
import 'mobile_map.dart';
import 'web_map_interop.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _cebu = LatLng(10.3157, 123.8854);

  // Mapbox access token — passed at build/run time via:
  //   --dart-define=MAPBOX_TOKEN=pk.your_token_here
  static const _mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

  final _mapController = MapController();
  final _webController = WebMapController();
  final _mobileController = MobileMapController();
  final _searchController = TextEditingController();

  StreamSubscription<List<Bidet>>? _bidetSub;
  Position? _userPosition;
  List<Bidet> _bidets = [];
  String? _selectedBidetId;
  String _searchQuery = '';

  /// Type filter. The landing page teaches the colour encoding, so the map
  /// should let you act on it.
  final Set<BidetType> _typeFilter = {};

  /// Bidets this user has already rated, so the list can say so.
  Set<String> _ratedIds = {};

  // Map style switching --------------------------------------------------
  static const _styles = <_MapStyle>[
    _MapStyle(
      id: MapStyleId.map,
      label: 'Map',
      icon: Icons.map_outlined,
      // CARTO's free basemap endpoint now stamps "API KEY REQUIRED" across
      // every tile, so the default street map uses Esri — the same provider
      // already backing satellite, hybrid and terrain.
      url:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
      attribution: 'Streets © Esri, © OpenStreetMap contributors',
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The callback still fires if this screen was disposed during the
      // frame — touching context then registers a dependency on a dead
      // element and trips InheritedElement's _dependents assertion.
      if (!mounted) return;
      _fetchLocation();
      _subscribe();
      _loadRated();
    });
  }

  @override
  void dispose() {
    // The old screen never held the subscription, so its 5-second poll kept
    // running after the user navigated away.
    _bidetSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRated() async {
    if (!context.session.isSignedIn) return;
    try {
      final ids = await context.bidets.fetchRatedIds();
      if (mounted) setState(() => _ratedIds = ids);
    } catch (_) {
      // Not knowing what you rated is cosmetic; never surface it.
    }
  }

  void _subscribe() {
    _bidetSub = context.bidets.watchApproved().listen((bidets) {
      if (mounted) setState(() => _bidets = bidets);
    });
  }

  Future<void> _fetchLocation() async {
    final result = await context.location.getCurrentPosition();
    if (!mounted) return;
    if (result.ok) {
      setState(() => _userPosition = result.position);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  String _distance(Bidet bidet) {
    if (_userPosition == null) return '';
    final meters = context.location.distanceBetween(
      LatLng(_userPosition!.latitude, _userPosition!.longitude),
      LatLng(bidet.latitude, bidet.longitude),
    );
    return context.location.formatDistance(meters);
  }

  List<Bidet> _sortedByDistance(List<Bidet> bidets) {
    final origin = _userPosition;
    if (origin == null) return bidets;
    // Decorate-sort-undecorate: the previous comparator recomputed both
    // geodesic distances on every comparison.
    final location = context.location;
    final here = LatLng(origin.latitude, origin.longitude);
    final decorated = bidets
        .map((b) => (
              bidet: b,
              meters: location.distanceBetween(
                here,
                LatLng(b.latitude, b.longitude),
              ),
            ))
        .toList()
      ..sort((a, b) => a.meters.compareTo(b.meters));
    return decorated.map((e) => e.bidet).toList();
  }

  List<Bidet> get _filtered {
    var list = _sortedByDistance(_bidets);

    if (_typeFilter.isNotEmpty) {
      list = list.where((b) => _typeFilter.contains(b.type)).toList();
    }

    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list
        .where((b) =>
            b.placeName.toLowerCase().contains(q) ||
            b.floor.toLowerCase().contains(q) ||
            b.typeLabel.toLowerCase().contains(q))
        .toList();
  }

  void _selectAndFly(Bidet bidet) {
    setState(() => _selectedBidetId = bidet.id);
    if (_useWebMapbox) {
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
                  // Neutral card rather than a solid green bar: over map tiles
                  // a saturated block competes with the pins, which are the
                  // thing the colour is supposed to mean.
                  color: context.shad.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.shad.border),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(Radii.xs + 2),
                      ),
                      child: const Icon(Icons.water_drop,
                          color: Colors.white, size: 13),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'SanBidet Cebu',
                      style: AppType.heading(
                          size: 15.5, color: context.shad.foreground),
                    ),
                    const Spacer(),
                    Text(
                      '${_bidets.length}',
                      style: AppType.figure(
                          size: 14, color: context.shad.foreground),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'mapped',
                      style: AppType.body(
                          size: 12, color: context.shad.mutedForeground),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Layer switcher (raster styles only — the Mapbox 3D map has its own)
          if (!_useWebMapbox)
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
                  if (_useWebMapbox) {
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
              backgroundColor: context.shad.card,
              foregroundColor: context.shad.primary,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Attribution badge. Required by the Esri terms whenever the raster
          // tiles are in use; Mapbox renders its own.
          if (!_useWebMapbox)
            Positioned(
              left: 12,
              bottom: 312,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.shad.card.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _style.attribution,
                    style: TextStyle(
                        fontSize: 9.5,
                        color: context.shad.mutedForeground,
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
                decoration: BoxDecoration(
                  color: context.shad.card,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
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
                          color: context.shad.border,
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
                            filtered.length == _bidets.length
                                ? 'Nearby bidets (${_bidets.length})'
                                : 'Nearby bidets '
                                    '(${filtered.length} of ${_bidets.length})',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          ShadInput(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            placeholder:
                                const Text('Search name, floor or type'),
                            leading: Icon(Icons.search,
                                size: 17, color: context.shad.mutedForeground),
                            trailing: _searchQuery.isEmpty
                                ? null
                                : ShadIconButton.ghost(
                                    width: 22,
                                    height: 22,
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    icon: Icon(Icons.close,
                                        size: 15,
                                        color: context.shad.mutedForeground),
                                  ),
                          ),
                          const SizedBox(height: Insets.sm),
                          _TypeFilterBar(
                            selected: _typeFilter,
                            onToggle: (t) => setState(() {
                              if (!_typeFilter.remove(t)) _typeFilter.add(t);
                            }),
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
                                      color: context.shad.border),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'No bidets yet — be the first!'
                                        : 'No results for "$_searchQuery"',
                                    style: TextStyle(
                                        color: context.shad.mutedForeground,
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
                                  rated: _ratedIds.contains(bidet.id),
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
        onPressed: () => context.push(Routes.addBidet),
        backgroundColor: context.shad.primary,
        foregroundColor: context.shad.primaryForeground,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Mapbox needs an access token. Without one, mapbox-gl / the native SDK
  /// initialises with an empty token and renders nothing at all — which is
  /// exactly what a default checkout does, since MAPBOX_TOKEN is a dart-define
  /// with no fallback. The token therefore gates the whole Mapbox path, and
  /// the token-free raster tiles are the default everywhere.
  bool get _hasMapboxToken => _mapboxToken.trim().isNotEmpty;

  bool get _useWebMapbox => _hasMapboxToken && kIsWeb;

  // True on Android/iOS, where the native Mapbox SDK is used.
  bool get _useNativeMapbox =>
      _hasMapboxToken &&
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
    if (_useWebMapbox) {
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

    // Default everywhere else (and whenever no Mapbox token is configured):
    // token-free raster tiles.
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
          userAgentPackageName: AppConfig.tileUserAgent,
          maxNativeZoom: 19,
        ),
        if (_style.overlayUrl != null)
          TileLayer(
            key: ValueKey('${_style.id}-overlay'),
            urlTemplate: _style.overlayUrl!,
            userAgentPackageName: AppConfig.tileUserAgent,
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
                    color: AppColors.userDot,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.userDot.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            // Markers follow the *filtered* list. Previously they came from
            // the unfiltered set, so searching changed the list below while
            // every pin stayed on the map.
            ..._filtered.map((bidet) {
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
        color: context.shad.card,
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
                color: context.shad.primary,
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
                    color: context.shad.border,
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
                  color: selected ? context.shad.primary : context.shad.muted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  s.icon,
                  size: 17,
                  color: selected ? context.shad.primaryForeground : context.shad.primary,
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
                  color: selected ? context.shad.primary : context.shad.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarker(bool isSelected) {
    final color = isSelected ? AppColors.pinSelected : AppColors.pin;
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
    context.push(
      Routes.bidet(bidet.id),
      extra: BidetDetailArgs(bidet: bidet, distance: _distance(bidet)),
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

/// Filter chips for the three bidet types, in the same colours the landing
/// page legend and the map pins use.
class _TypeFilterBar extends StatelessWidget {
  const _TypeFilterBar({required this.selected, required this.onToggle});

  final Set<BidetType> selected;
  final ValueChanged<BidetType> onToggle;

  static Color _colorFor(BidetType t) => switch (t) {
        BidetType.sprayHose => AppColors.typeSpray,
        BidetType.bidetSeat => AppColors.typeSeat,
        BidetType.tabo => AppColors.typeTabo,
      };

  @override
  Widget build(BuildContext context) {
    final cs = context.shad;
    return Row(
      children: [
        for (final t in BidetType.values) ...[
          if (t != BidetType.values.first) const SizedBox(width: Insets.sm),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.sm),
              onTap: () => onToggle(t),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  color: selected.contains(t)
                      ? _colorFor(t).withValues(alpha: 0.12)
                      : null,
                  border: Border.all(
                    color: selected.contains(t) ? _colorFor(t) : cs.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _colorFor(t),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        t.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(
                          size: 11.5,
                          weight: selected.contains(t)
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected.contains(t)
                              ? _colorFor(t)
                              : cs.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
