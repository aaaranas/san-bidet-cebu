import 'dart:ui' as ui;
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

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _green = Color(0xFF1A6B3C);
  static const _cebu = LatLng(10.3157, 123.8854);

  final _mapController = MapController();
  final _supabaseService = SupabaseService();
  final _locationService = LocationService();
  final _searchController = TextEditingController();

  Position? _userPosition;
  List<Bidet> _bidets = [];
  String? _selectedBidetId;
  String _searchQuery = '';

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
    _mapController.move(LatLng(bidet.latitude, bidet.longitude), 17);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _cebu,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.san_bidet_cebu',
              ),
              MarkerLayer(
                markers: [
                  if (_userPosition != null)
                    Marker(
                      point: LatLng(_userPosition!.latitude,
                          _userPosition!.longitude),
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 3),
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
          ),

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

          // My location button
          Positioned(
            right: 16,
            bottom: 260,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              onPressed: () {
                if (_userPosition != null) {
                  _mapController.move(
                    LatLng(_userPosition!.latitude,
                        _userPosition!.longitude),
                    15,
                  );
                } else {
                  _fetchLocation();
                }
              },
              backgroundColor: Colors.white,
              foregroundColor: _green,
              child: const Icon(Icons.my_location),
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
