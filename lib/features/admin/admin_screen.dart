import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/gis_export_service.dart';
import '../../services/supabase_service.dart';
import '../bidet/bidet_model.dart';
import '../home/home_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _green = Color(0xFF0F172A);
  final _supabaseService = SupabaseService();
  final _authService = AuthService();
  final _gisExport = GisExportService();
  List<Bidet> _pending = [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _loading = true);
    final pending = await _supabaseService.getPendingBidets();
    if (mounted) setState(() { _pending = pending; _loading = false; });
  }

  Future<void> _approve(String id) async {
    await _supabaseService.approveBidet(id);
    setState(() => _pending.removeWhere((b) => b.id == id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bidet approved!'),
            backgroundColor: _green),
      );
    }
  }

  Future<void> _exportGis() async {
    final format = await showModalBottomSheet<GisFormat>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Export for GIS',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Download all bidets as a mappable layer. Open it directly '
                'in QGIS / ArcGIS, or convert to an ESRI Shapefile there.',
                style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade500,
                    height: 1.4),
              ),
              const SizedBox(height: 16),
              _exportOption(
                ctx,
                GisFormat.geoJson,
                Icons.public,
                'GeoJSON',
                'WGS84 points + attributes · best for QGIS / ArcGIS',
              ),
              const SizedBox(height: 10),
              _exportOption(
                ctx,
                GisFormat.csv,
                Icons.table_chart_outlined,
                'CSV (with WKT)',
                'Spreadsheet or PostGIS-friendly delimited points',
              ),
            ],
          ),
        ),
      ),
    );

    if (format == null) return;

    setState(() => _exporting = true);
    try {
      final bidets = await _supabaseService.getAllBidets();
      if (bidets.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No bidets to export yet.')),
          );
        }
        return;
      }
      final name = await _gisExport.export(bidets, format);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${bidets.length} bidets → $name'),
            backgroundColor: _green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _exportOption(BuildContext ctx, GisFormat format, IconData icon,
      String title, String subtitle) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pop(ctx, format),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _green, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _reject(String id) async {
    await _supabaseService.deleteBidet(id);
    setState(() => _pending.removeWhere((b) => b.id == id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Submission rejected.'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.water_drop,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text('SanBidet Cebu',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _exporting ? null : _exportGis,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: _exporting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.ios_share,
                                        color: Colors.white, size: 18),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () async {
                                await _authService.signOut();
                                if (context.mounted) {
                                  Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const HomeScreen()));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.logout,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Icon(Icons.admin_panel_settings,
                        color: Colors.white, size: 36),
                    const SizedBox(height: 8),
                    const Text('Admin panel',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('Review and approve bidet submissions.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                _statCard('Pending', '${_pending.length}',
                    Icons.pending_outlined),
                const SizedBox(width: 12),
                _statCard('Approved', '—', Icons.check_circle_outline),
                const SizedBox(width: 12),
                _statCard('Total', '—', Icons.wc_outlined),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _pending.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('All caught up!',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('No pending submissions.',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 13)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPending,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          itemCount: _pending.length,
                          itemBuilder: (context, i) {
                            final bidet = _pending[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 0.5),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.wc,
                                            color: _green, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(bidet.placeName,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontSize: 14)),
                                            const SizedBox(height: 2),
                                            Text(bidet.floor,
                                                style: TextStyle(
                                                    color: Colors
                                                        .grey.shade500,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(bidet.typeLabel,
                                            style: const TextStyle(
                                                color: _green,
                                                fontSize: 10,
                                                fontWeight:
                                                    FontWeight.w500)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _reject(bidet.id),
                                          icon: const Icon(Icons.close,
                                              size: 15,
                                              color: Colors.red),
                                          label: const Text('Reject',
                                              style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 13)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: Colors.red,
                                                width: 0.5),
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 10),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _approve(bidet.id),
                                          icon: const Icon(Icons.check,
                                              size: 15),
                                          label: const Text('Approve',
                                              style: TextStyle(
                                                  fontSize: 13)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _green,
                                            foregroundColor: Colors.white,
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 10),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        10)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: _green, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}