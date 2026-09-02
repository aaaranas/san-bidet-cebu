import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../data/models/bidet.dart';
import '../bidet/bidet_detail_screen.dart';
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
  List<Bidet> _approved = const [];
  Map<String, int> _reportCounts = const {};
  int _tab = 0; // 0 = queue, 1 = approved
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
        repo.fetchApproved(),
        repo.fetchOpenReportCounts(),
      ]);
      if (!mounted) return;
      final approved = results[1] as List<Bidet>;
      setState(() {
        _pending = results[0] as List<Bidet>;
        _approved = approved;
        _reportCounts = results[2] as Map<String, int>;
        _approvedCount = approved.length;
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
    // Rejecting used to hard-delete, so the contributor got no feedback and
    // nothing stopped them re-adding the same place. Now it keeps the row with
    // a reason they can see on their dashboard.
    final reason = await showShadDialog<String>(
      context: context,
      builder: (ctx) => _RejectDialog(placeName: bidet.placeName),
    );
    if (reason == null || !mounted) return;

    final repo = context.bidets;
    final messenger = ScaffoldMessenger.of(context);
    final previous = _pending;

    setState(() {
      _pending = _pending.where((b) => b.id != bidet.id).toList();
    });

    try {
      await repo.reject(bidet.id, reason);
      messenger.showSnackBar(
        const SnackBar(content: Text('Rejected, with your reason recorded.')),
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
        action: ShadButton.outline(
          onPressed: _load,
          child: const Text('Retry'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: CenteredBody(
        maxWidth: 720,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.xl, 0, Insets.xl, Insets.md),
              child: ShadTabs<int>(
                value: _tab,
                onChanged: (v) => setState(() => _tab = v),
                tabs: [
                  ShadTab(value: 0, child: Text('Queue (${_pending.length})')),
                  ShadTab(
                      value: 1, child: Text('Approved (${_approved.length})')),
                ],
              ),
            ),
            Expanded(child: _tab == 0 ? _queue() : _approvedList()),
          ],
        ),
      ),
    );
  }

  Widget _queue() {
    if (_pending.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 60),
          EmptyState(
            icon: Icons.check_circle_outline,
            title: 'All caught up!',
            message: 'No pending submissions.',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          Insets.xl, 0, Insets.xl, Insets.xl),
      itemCount: _pending.length,
      itemBuilder: (context, i) => _PendingCard(
        bidet: _pending[i],
        openReports: _reportCounts[_pending[i].id] ?? 0,
        onApprove: () => _approve(_pending[i]),
        onReject: () => _reject(_pending[i]),
      ),
    );
  }

  /// Browsing what is already live. Previously the moderator could only see
  /// the pending queue, so a listing that needed correcting had no tool.
  Widget _approvedList() {
    if (_approved.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 60),
          EmptyState(
            icon: Icons.map_outlined,
            title: 'Nothing published yet',
            message: 'Approved bidets show up here.',
          ),
        ],
      );
    }

    // Anything with an open report first — that is what needs attention.
    final sorted = [..._approved]..sort((a, b) {
        final ra = _reportCounts[a.id] ?? 0;
        final rb = _reportCounts[b.id] ?? 0;
        if (ra != rb) return rb.compareTo(ra);
        return b.createdAt.compareTo(a.createdAt);
      });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          Insets.xl, 0, Insets.xl, Insets.xl),
      itemCount: sorted.length,
      itemBuilder: (context, i) => _ApprovedRow(
        bidet: sorted[i],
        openReports: _reportCounts[sorted[i].id] ?? 0,
        onOpen: () => context.push(
          Routes.bidet(sorted[i].id),
          extra: BidetDetailArgs(bidet: sorted[i], distance: ''),
        ),
        onUnpublish: () => _reject(sorted[i]),
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
    this.openReports = 0,
  });

  final Bidet bidet;
  final int openReports;
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
                child: ShadButton.outline(
                  onPressed: onReject,
                  leading: Icon(Icons.close, size: 15, color: error),
                  child: Text('Reject', style: TextStyle(color: error)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ShadButton(
                  onPressed: onApprove,
                  leading: const Icon(Icons.check, size: 15),
                  child: const Text('Approve'),
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

/// Asks for a rejection reason. Returning a string (rather than a bool) is
/// what lets the contributor find out why.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.placeName});

  final String placeName;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();

  static const _presets = [
    'Already listed',
    'Not enough detail to find it',
    'Could not verify it exists',
    'Not a public bidet',
  ];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog.alert(
      title: const Text('Reject submission'),
      description: Text(
        '"${widget.placeName}" stays on record as rejected, and the person '
        'who submitted it will see why.',
      ),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ShadButton.destructive(
          onPressed: _reason.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _reason.text.trim()),
          child: const Text('Reject'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final p in _presets)
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: () => setState(() => _reason.text = p),
                    child: Text(p),
                  ),
              ],
            ),
            const SizedBox(height: Insets.md),
            ShadInput(
              controller: _reason,
              placeholder: const Text('Reason'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}

/// A published listing in the moderator's browse tab. Open reports float to
/// the top of the list and are called out here, because that is the signal
/// that something needs correcting.
class _ApprovedRow extends StatelessWidget {
  const _ApprovedRow({
    required this.bidet,
    required this.openReports,
    required this.onOpen,
    required this.onUnpublish,
  });

  final Bidet bidet;
  final int openReports;
  final VoidCallback onOpen;
  final VoidCallback onUnpublish;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = context.shad;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: ShadCard(
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          bidet.placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.small,
                        ),
                      ),
                      if (openReports > 0) ...[
                        const SizedBox(width: Insets.sm),
                        ShadBadge.destructive(
                          child: Text(
                            openReports == 1
                                ? '1 report'
                                : '$openReports reports',
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bidet.floor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.muted,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: onOpen,
              child: const Text('Open'),
            ),
            ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: onUnpublish,
              child: Text(
                'Unpublish',
                style: TextStyle(color: cs.destructive),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
