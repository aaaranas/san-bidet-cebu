import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../data/models/bidet.dart';
import '../../widgets/app_widgets.dart';

/// Passed via GoRouter `extra` when navigating from the map, so the screen can
/// paint immediately instead of showing a spinner for data we already hold.
/// Absent on a cold deep link, where the bidet is fetched by id.
class BidetDetailArgs {
  const BidetDetailArgs({required this.bidet, required this.distance});

  final Bidet bidet;
  final String distance;
}

class BidetDetailScreen extends StatefulWidget {
  const BidetDetailScreen({
    super.key,
    required this.bidetId,
    this.initial,
  });

  final String bidetId;
  final BidetDetailArgs? initial;

  @override
  State<BidetDetailScreen> createState() => _BidetDetailScreenState();
}

class _BidetDetailScreenState extends State<BidetDetailScreen> {
  Bidet? _bidet;
  Object? _error;
  bool _loading = false;
  bool _submittingRating = false;

  String get _distance => widget.initial?.distance ?? '';

  @override
  void initState() {
    super.initState();
    _bidet = widget.initial?.bidet;
    if (_bidet == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bidet = await context.bidets.fetchById(widget.bidetId);
      if (!mounted) return;
      setState(() {
        _bidet = bidet;
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

  Future<void> _rate() async {
    final session = context.session;
    if (!session.isSignedIn) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign in to rate'),
          content: const Text(
            'Ratings are tied to your account so each person rates a bidet '
            'once. Sign in to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
      if (go == true && mounted) context.push(Routes.login);
      return;
    }

    final rating = await showModalBottomSheet<BidetRating>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _RatingSheet(),
    );
    if (rating == null || !mounted) return;

    final repo = context.bidets;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _submittingRating = true);
    try {
      await repo.rate(widget.bidetId, rating);
      final updated = await repo.fetchById(widget.bidetId);
      if (!mounted) return;
      setState(() {
        _bidet = updated;
        _submittingRating = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks — your rating was saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submittingRating = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('duplicate')
                ? 'You have already rated this bidet.'
                : 'Could not save your rating. Please try again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bidet = _bidet;

    return Scaffold(
      appBar: AppBar(
        title: Text(bidet?.placeName ?? 'Bidet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.map),
        ),
      ),
      body: switch ((bidet, _loading, _error)) {
        (_, true, _) => const Center(child: CircularProgressIndicator()),
        (null, _, != null) => EmptyState(
            icon: Icons.search_off,
            title: 'Bidet not found',
            message: 'It may have been removed.',
            action: FilledButton(
              onPressed: () => context.go(Routes.map),
              child: const Text('Back to map'),
            ),
          ),
        (null, _, _) => const Center(child: CircularProgressIndicator()),
        (final b?, _, _) => _content(context, b),
      },
    );
  }

  Widget _content(BuildContext context, Bidet bidet) {
    final p = context.shad;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (bidet.imageUrl != null)
            CachedNetworkImage(
              imageUrl: bidet.imageUrl!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 220,
                color: p.muted,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 220,
                color: p.muted,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: p.mutedForeground,
                  size: 40,
                ),
              ),
            ),
          Container(
            // Neutral header. The rating figure and the type chip supply the
            // colour here; a solid green field drowned both.
            color: p.card,
            padding: EdgeInsets.fromLTRB(
              Insets.xl,
              bidet.imageUrl != null ? Insets.lg : Insets.sm,
              Insets.xl,
              Insets.xl,
            ),
            child: CenteredBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bidet.floor,
                    style: AppType.body(size: 13, color: p.mutedForeground),
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      Text(
                        bidet.ratingCount == 0
                            ? '—'
                            : bidet.rating.toStringAsFixed(1),
                        style: AppType.figure(size: 30, color: p.foreground),
                      ),
                      const SizedBox(width: Insets.sm),
                      StarRow(rating: bidet.rating),
                      const SizedBox(width: Insets.sm),
                      Flexible(
                        child: Text(
                          bidet.ratingCount == 1
                              ? '1 rating'
                              : '${bidet.ratingCount} ratings',
                          style: AppType.body(
                              size: 12, color: p.mutedForeground),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: [
                      _Badge(bidet.typeLabel),
                      if (_distance.isNotEmpty) _Badge(_distance),
                      const _Badge('Free'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          CenteredBody(
            child: Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bidet.ratingCount > 0) ...[
                    Text('Ratings breakdown', style: context.texts.titleMedium),
                    const SizedBox(height: Insets.md),
                    _RatingBar('Cleanliness', bidet.cleanlinessRating),
                    _RatingBar('Water pressure', bidet.pressureRating),
                    _RatingBar('Accessibility', bidet.accessibilityRating),
                    _RatingBar('Privacy', bidet.privacyRating),
                    const SizedBox(height: Insets.xl),
                    const Divider(height: 1),
                    const SizedBox(height: Insets.xl),
                  ],
                  _DetailRow('Location', bidet.floor),
                  _DetailRow('Type', bidet.typeLabel),
                  _DetailRow('Added', _formatDate(bidet.createdAt)),
                  _DetailRow('Total ratings', '${bidet.ratingCount}'),
                  const SizedBox(height: Insets.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submittingRating ? null : _rate,
                      child: _submittingRating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Rate this bidet'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.shad;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Insets.xs),
      decoration: BoxDecoration(
        color: p.muted,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: AppType.body(
            size: 11.5, weight: FontWeight.w600, color: p.mutedForeground),
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar(this.label, this.value);

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final p = context.shad;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            child: Text(label, style: context.texts.bodyMedium),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.xs),
              child: LinearProgressIndicator(
                value: (value / 5).clamp(0.0, 1.0),
                backgroundColor: p.border,
                valueColor: AlwaysStoppedAnimation(p.primary),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: Insets.sm),
          SizedBox(
            width: 26,
            child: Text(
              value.toStringAsFixed(1),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.texts.bodyMedium),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.texts.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingSheet extends StatefulWidget {
  const _RatingSheet();

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _cleanliness = 0;
  int _pressure = 0;
  int _accessibility = 0;
  int _privacy = 0;

  bool get _complete =>
      _cleanliness > 0 && _pressure > 0 && _accessibility > 0 && _privacy > 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Insets.xl,
          0,
          Insets.xl,
          Insets.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: CenteredBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rate this bidet', style: context.texts.titleLarge),
              const SizedBox(height: Insets.xs),
              Text(
                'All four criteria are required.',
                style: context.texts.bodyMedium,
              ),
              const SizedBox(height: Insets.lg),
              StarSelector(
                label: 'Cleanliness',
                value: _cleanliness,
                onChanged: (v) => setState(() => _cleanliness = v),
              ),
              StarSelector(
                label: 'Water pressure',
                value: _pressure,
                onChanged: (v) => setState(() => _pressure = v),
              ),
              StarSelector(
                label: 'Accessibility',
                value: _accessibility,
                onChanged: (v) => setState(() => _accessibility = v),
              ),
              StarSelector(
                label: 'Privacy',
                value: _privacy,
                onChanged: (v) => setState(() => _privacy = v),
              ),
              const SizedBox(height: Insets.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !_complete
                      ? null
                      : () => Navigator.pop(
                            context,
                            BidetRating(
                              cleanliness: _cleanliness.toDouble(),
                              pressure: _pressure.toDouble(),
                              accessibility: _accessibility.toDouble(),
                              privacy: _privacy.toDouble(),
                            ),
                          ),
                  child: const Text('Submit rating'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
