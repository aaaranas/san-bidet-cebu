import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../services/place_actions.dart';
import '../../data/bidet_repository.dart';
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
  static const _actions = PlaceActions();

  Bidet? _bidet;
  Object? _error;
  bool _loading = false;
  bool _submittingRating = false;

  /// This user's existing rating, so the sheet opens pre-filled and the screen
  /// can say "you rated this" instead of pretending they never did.
  BidetRating? _myRating;

  /// Distance computed here when the screen was opened cold (a shared link),
  /// rather than only when handed in from the map.
  String? _measuredDistance;

  String get _distance =>
      widget.initial?.distance.isNotEmpty == true
          ? widget.initial!.distance
          : (_measuredDistance ?? '');

  @override
  void initState() {
    super.initState();
    _bidet = widget.initial?.bidet;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_bidet == null) {
        _load();
      } else {
        _loadMyRating();
        _measureDistance();
      }
    });
  }

  /// A shared link arrives with no distance attached, so measure it.
  Future<void> _measureDistance() async {
    final bidet = _bidet;
    if (bidet == null || widget.initial?.distance.isNotEmpty == true) return;

    final location = context.location;
    final result = await location.getCurrentPosition();
    if (!mounted || !result.ok) return;
    final meters = location.distanceBetween(
      LatLng(result.position!.latitude, result.position!.longitude),
      LatLng(bidet.latitude, bidet.longitude),
    );
    setState(() => _measuredDistance = location.formatDistance(meters));
  }

  Future<void> _loadMyRating() async {
    if (!context.session.isSignedIn) return;
    try {
      final mine = await context.bidets.fetchMyRating(widget.bidetId);
      if (mounted) setState(() => _myRating = mine);
    } catch (_) {
      // Not being able to read your own rating is not worth an error state.
    }
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
      _loadMyRating();
      _measureDistance();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _report(Bidet bidet) async {
    if (!context.session.isSignedIn) {
      final go = await _askToSignIn(
        'Sign in to report',
        'Reports are tied to your account so moderators can follow up.',
      );
      if (go && mounted) context.push(Routes.login);
      return;
    }

    final result = await showShadSheet<({ReportKind kind, String note})>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (_) => const _ReportSheet(),
    );
    if (result == null || !mounted) return;

    final repo = context.bidets;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.report(bidet.id, result.kind, result.note);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thanks — a moderator will take a look.'),
        ),
      );
    } on BidetFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not send that report.')),
      );
    }
  }

  Future<bool> _askToSignIn(String title, String body) async {
    final go = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: Text(title),
        description: Text(body),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          ShadButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
    return go ?? false;
  }

  Future<void> _rate() async {
    final session = context.session;
    if (!session.isSignedIn) {
      final go = await showShadDialog<bool>(
        context: context,
        builder: (ctx) => ShadDialog.alert(
          title: const Text('Sign in to rate'),
          description: const Text(
            'Ratings are tied to your account so each person rates a bidet '
            'once. Sign in to continue.',
          ),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            ShadButton(
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
      builder: (_) => _RatingSheet(initial: _myRating),
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
        _myRating = rating;
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
        actions: bidet == null
            ? null
            : [
                IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.ios_share, size: 20),
                  onPressed: () => _actions.share(bidet),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (v) {
                    if (v == 'report') _report(bidet);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'report',
                      child: Text('Report a problem'),
                    ),
                  ],
                ),
              ],
      ),
      body: switch ((bidet, _loading, _error)) {
        (_, true, _) => const Center(child: CircularProgressIndicator()),
        (null, _, != null) => EmptyState(
            icon: Icons.search_off,
            title: 'Bidet not found',
            message: 'It may have been removed.',
            action: ShadButton(
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
                      if (bidet.accessType != AccessType.public)
                        _Badge(bidet.accessType.label),
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
                  _DetailRow('Access', bidet.accessType.label),
                  if (bidet.hoursNote?.isNotEmpty ?? false)
                    _DetailRow('Hours', bidet.hoursNote!),
                  _DetailRow(
                    'Cost',
                    (bidet.feeNote?.isNotEmpty ?? false)
                        ? bidet.feeNote!
                        : 'Free',
                  ),
                  _DetailRow('Added', _formatDate(bidet.createdAt)),
                  if (bidet.submittedByUsername != null)
                    _DetailRow('Added by', '@${bidet.submittedByUsername}'),
                  _DetailRow('Total ratings', '${bidet.ratingCount}'),
                  const SizedBox(height: Insets.xl),

                  // Knowing where it is was never enough — this is how you get
                  // there.
                  ShadButton(
                    width: double.infinity,
                    size: ShadButtonSize.lg,
                    leading: const Icon(Icons.directions_walk, size: 17),
                    onPressed: () => _actions.openDirections(bidet),
                    child: const Text('Directions'),
                  ),
                  const SizedBox(height: Insets.sm),
                  ShadButton.outline(
                    width: double.infinity,
                    size: ShadButtonSize.lg,
                    onPressed: _submittingRating ? null : _rate,
                    child: _submittingRating
                        ? const SizedBox(
                            height: 17,
                            width: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _myRating == null
                                ? 'Rate this bidet'
                                : 'Change your rating',
                          ),
                  ),
                  if (_myRating != null) ...[
                    const SizedBox(height: Insets.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: p.primary),
                        const SizedBox(width: 6),
                        Text(
                          'You rated this '
                          '${_myRating!.overall.toStringAsFixed(1)}',
                          style: AppType.body(
                              size: 12.5, color: p.mutedForeground),
                        ),
                      ],
                    ),
                  ],
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
            child: ShadProgress(
              value: (value / 5).clamp(0.0, 1.0),
              minHeight: 8,
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
  const _RatingSheet({this.initial});

  /// Existing rating, so re-rating starts from what you said last time.
  final BidetRating? initial;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  late int _cleanliness = widget.initial?.cleanliness.round() ?? 0;
  late int _pressure = widget.initial?.pressure.round() ?? 0;
  late int _accessibility = widget.initial?.accessibility.round() ?? 0;
  late int _privacy = widget.initial?.privacy.round() ?? 0;

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
              ShadButton(
                width: double.infinity,
                size: ShadButtonSize.lg,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Flagging a listing that has gone stale. Physical amenities close, break and
/// get renovated, so this is the only route by which the map corrects itself.
class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportKind _kind = ReportKind.gone;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = context.shad;

    return ShadSheet(
      title: const Text('Report a problem'),
      description: const Text(
        'Moderators use these to keep the map honest.',
      ),
      actions: [
        ShadButton(
          onPressed: () => Navigator.pop(
            context,
            (kind: _kind, note: _note.text),
          ),
          child: const Text('Send report'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in ReportKind.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  onTap: () => setState(() => _kind = kind),
                  child: Container(
                    padding: const EdgeInsets.all(Insets.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      border: Border.all(
                        color: _kind == kind ? cs.primary : cs.border,
                        width: _kind == kind ? 1.5 : 1,
                      ),
                      color: _kind == kind
                          ? cs.primary.withValues(alpha: 0.06)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _kind == kind
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color:
                              _kind == kind ? cs.primary : cs.mutedForeground,
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(kind.label, style: theme.textTheme.small),
                              const SizedBox(height: 1),
                              Text(kind.hint, style: theme.textTheme.muted),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: Insets.sm),
            ShadInput(
              controller: _note,
              placeholder: const Text('Anything else we should know?'),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
