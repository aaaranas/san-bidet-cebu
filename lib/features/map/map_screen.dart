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

  Position? _userPosition;
  List<Bidet> _bidets = [];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _loadBidets();
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

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedByDistance(_bidets);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _cebu,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.san_bidet_cebu',
              ),
              MarkerLayer(
                markers: [
                  if (_userPosition != null)
                    Marker(
                      point: LatLng(_userPosition!.latitude,
                          _userPosition!.longitude),
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                  ..._bidets.map((bidet) => Marker(
                        point: LatLng(bidet.latitude, bidet.longitude),
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTap: () => _openDetail(bidet),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: _green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.wc,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      )),
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
                        color: Colors.black.withOpacity(0.15),
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
            bottom: 240,
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
                child: ListView(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                    Text(
                      'Nearby bidets (${_bidets.length})',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (sorted.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          children: [
                            Icon(Icons.wc_outlined,
                                size: 48,
                                color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text(
                              'No bidets yet — be the first to add one!',
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ...sorted.map((bidet) => BidetCard(
                          bidet: bidet,
                          distance: _distance(bidet),
                          onTap: () => _openDetail(bidet),
                        )),
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
          MaterialPageRoute(
              builder: (_) => const BidetAddScreen()),
        ),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
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