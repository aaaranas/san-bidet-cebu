import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../data/models/bidet.dart';
import '../../services/gis_export_service.dart';
import '../../widgets/app_widgets.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _gisExport = const GisExportService();

  List<Bidet> _pending = const [];
  int _approvedCount = 0;
  bool _loading = true;
  bool _exporting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // See note in map_screen: a post-frame callback can outlive the element.
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.bidets;
      // The stat cards used to render a hardcoded em dash.
      final results = await Future.wait([
        repo.fetchPending(),
        repo.countApproved(),
      ]);
      if (!mounted) return;
      setState(() {
        _pending = results[0] as List<Bidet>;
        _approvedCount = results[1] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _approve(Bidet bidet) async {
    final repo = context.bidets;
    final messenger = ScaffoldMessenger.of(context);
    final previous = _pending;

    // Optimistic removal, rolled back if the write fails.
    setState(() {
      _pending = _pending.where((b) => b.id != bidet.id).toList();
      _approvedCount++;
    });

    try {
      await repo.approve(bidet.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Approved "${bidet.placeName}".')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pending = previous;
        _approvedCount--;
      });
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Could not approve. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _reject(Bidet bidet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject submission?'),
        content: Text(
          '"${bidet.placeName}" will be permanently deleted. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = context.bidets;
    final messenger = ScaffoldMessenger.of(context);
    final previous = _pending;

    setState(() {
      _pending = _pending.where((b) => b.id != bidet.id).toList();
    });

    try {
      await repo.delete(bidet.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Submission rejected.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pending = previous);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Could not reject. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _exportGis() async {
    final format = await showModalBottomSheet<GisFormat>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => const _ExportSheet(),
    );
    if (format == null || !mounted) return;

    final repo = context.bidets;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _exporting = true);
    try {
      final bidets = await repo.fetchAll();
      if (bidets.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No bidets to export yet.')),
        );
        return;
      }
      final name = await _gisExport.export(bidets, format);
      messenger.showSnackBar(
        SnackBar(content: Text('Exported ${bidets.length} bidets → $name')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Admin panel',
            subtitle: 'Review and approve bidet submissions.',
            icon: Icons.admin_panel_settings,
            actions: [
              GlassIconButton(
                icon: Icons.ios_share,
                tooltip: 'Export for GIS',
                busy: _exporting,
                onPressed: _exportGis,
              ),
              const SizedBox(width: 10),
              GlassIconButton(
                icon: Icons.logout,
                tooltip: 'Sign out',
                onPressed: () async {
                  final router = GoRouter.of(context);
                  await context.session.signOut();
                  router.go(Routes.home);
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.xl,
              Insets.lg,
              Insets.xl,
              Insets.sm,
            ),
            child: CenteredBody(
              maxWidth: 720,
              child: Row(
                children: [
                  _StatCard(
                    label: 'Pending',
                    value: _loading ? null : '${_pending.length}',
                    icon: Icons.pending_outlined,
                  ),
                  const SizedBox(width: Insets.md),
                  _StatCard(
                    label: 'Approved',
                    value: _loading ? null : '$_approvedCount',
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(width: Insets.md),
                  _StatCard(
                    label: 'Total',
                    value: _loading
                        ? null
                        : '${_approvedCount + _pending.length}',
                    icon: Icons.wc_outlined,
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load submissions',
        message: 'Check your connection and try again.',
        action: OutlinedButton(onPressed: _load, child: const Text('Retry')),
      );
    }
    if (_pending.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyState(
              icon: Icons.check_circle_outline,
              title: 'All caught up!',
              message: 'No pending submissions.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: CenteredBody(
        maxWidth: 720,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            Insets.xl,
            Insets.sm,
            Insets.xl,
            Insets.xl,
          ),
          itemCount: _pending.length,
          itemBuilder: (context, i) => _PendingCard(
            bidet: _pending[i],
            onApprove: () => _approve(_pending[i]),
            onReject: () => _reject(_pending[i]),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String? value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.shad;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Insets.md, horizontal: 10),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: p.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: p.primary, size: 20),
            const SizedBox(height: 6),
            SizedBox(
              height: 22,
              child: value == null
                  ? Center(
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: p.mutedForeground,
                        ),
                      ),
                    )
                  : Text(
                      value!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(height: 2),
            Text(label, style: context.texts.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.bidet,
    required this.onApprove,
    required this.onReject,
  });

  final Bidet bidet;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final p = context.shad;
    final error = Theme.of(context).colorScheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Insets.sm),
                decoration: BoxDecoration(
                  color: p.muted,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(Icons.wc, color: p.primary, size: 18),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bidet.placeName,
                      style: context.texts.titleMedium?.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bidet.floor,
                      style: context.texts.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm,
                  vertical: Insets.xs,
                ),
                decoration: BoxDecoration(
                  color: p.muted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  bidet.typeLabel,
                  style: TextStyle(
                    color: p.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: Icon(Icons.close, size: 15, color: error),
                  label: Text('Reject', style: TextStyle(color: error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: error.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 15),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportSheet extends StatelessWidget {
  const _ExportSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xl),
        child: CenteredBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Export for GIS', style: context.texts.titleLarge),
              const SizedBox(height: Insets.xs),
              Text(
                'Download all bidets as a mappable layer. Open it directly in '
                'QGIS / ArcGIS, or convert to an ESRI Shapefile there.',
                style: context.texts.bodyMedium,
              ),
              const SizedBox(height: Insets.lg),
              _ExportOption(
                format: GisFormat.geoJson,
                icon: Icons.public,
                title: 'GeoJSON',
                subtitle: 'WGS84 points + attributes · best for QGIS / ArcGIS',
              ),
              const SizedBox(height: 10),
              _ExportOption(
                format: GisFormat.csv,
                icon: Icons.table_chart_outlined,
                title: 'CSV (with WKT)',
                subtitle: 'Spreadsheet or PostGIS-friendly delimited points',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.format,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final GisFormat format;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.shad;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: () => Navigator.pop(context, format),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.muted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: p.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.texts.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.texts.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: p.mutedForeground),
          ],
        ),
      ),
    );
  }
}
