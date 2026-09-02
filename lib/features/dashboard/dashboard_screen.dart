import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/app_scope.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../data/models/bidet.dart';
import '../bidet/bidet_detail_screen.dart';

/// The shadcn `dashboard-01` block, in Flutter.
///
/// Same anatomy as the web original: a header with the account, a row of
/// section cards, a chart, and a tabbed data table — all built from shadcn
/// primitives (ShadCard, ShadBadge, ShadTabs, ShadTable, ShadSeparator,
/// ShadAvatar) rather than hand-rolled containers.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// Fixed row height, so the table's total height can be computed instead of
/// measured — ShadTable needs a bounded box.
const double _kRowHeight = 46;

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<List<Bidet>>? _sub;

  List<Bidet> _bidets = [];

  /// Everything this user submitted, any status. Without it a contributor
  /// submits something and it vanishes into moderation with no feedback.
  List<Bidet> _mine = const [];
  bool _loaded = false;
  int _tab = 0; // 0 = Recent, 1 = Top rated, 2 = All

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The callback still fires if this screen was disposed during the
      // frame — touching context then registers a dependency on a dead
      // element and trips InheritedElement's _dependents assertion.
      if (!mounted) return;
      _sub = context.bidets.watchApproved().listen((b) {
        if (!mounted) return;
        setState(() {
          _bidets = b;
          _loaded = true;
        });
      }, onError: (_) {
        if (mounted) setState(() => _loaded = true);
      });
      _loadMine();
    });
  }

  Future<void> _loadMine() async {
    final userId = context.session.user?.id;
    if (userId == null) return;
    try {
      final mine = await context.bidets.fetchMine(userId);
      if (mounted) setState(() => _mine = mine);
    } catch (_) {
      // The rest of the dashboard is still useful without this.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ---- derived metrics ---------------------------------------------------

  double get _avgRating {
    final rated = _bidets.where((b) => b.ratingCount > 0).toList();
    if (rated.isEmpty) return 0;
    return rated.map((b) => b.rating).reduce((a, b) => a + b) / rated.length;
  }

  int get _topRated => _bidets.where((b) => b.rating >= 4).length;

  int get _unrated => _bidets.where((b) => b.ratingCount == 0).length;

  int _addedIn(DateTime month) => _bidets
      .where((b) =>
          b.createdAt.year == month.year && b.createdAt.month == month.month)
      .length;

  double _criteriaAvg(double Function(Bidet) pick) {
    final rated = _bidets.where((b) => b.ratingCount > 0).toList();
    if (rated.isEmpty) return 0;
    return rated.map(pick).reduce((a, b) => a + b) / rated.length;
  }

  List<({String label, int count})> get _last6Months {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final m = DateTime(now.year, now.month - (5 - i));
      return (label: _monthAbbr(m.month), count: _addedIn(m));
    });
  }

  List<Bidet> get _tableData {
    final list = [..._bidets];
    switch (_tab) {
      case 1:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case 2:
        list.sort((a, b) => a.placeName.compareTo(b.placeName));
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list.take(8).toList();
  }

  static String _monthAbbr(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][(m - 1) % 12];

  static String _fmtDate(DateTime d) => '${d.day} ${_monthAbbr(d.month)}';

  // ---- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = context.shad;
    final now = DateTime.now();
    final thisMonth = _addedIn(DateTime(now.year, now.month));
    final lastMonth = _addedIn(DateTime(now.year, now.month - 1));
    final monthDelta = thisMonth - lastMonth;
    final wide = !context.isCompact;

    return Scaffold(
      backgroundColor: cs.background,
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                    padding: const EdgeInsets.all(Insets.lg),
                    children: [
                      _header(context),
                      const SizedBox(height: Insets.lg),
                      _sectionCards(context, thisMonth, monthDelta, wide),
                      const SizedBox(height: Insets.md),
                      _chartCard(context),
                      const SizedBox(height: Insets.md),
                      _criteriaCard(context),
                      const SizedBox(height: Insets.md),
                      _tableCard(context),
                      const SizedBox(height: Insets.md),
                      if (_mine.isNotEmpty) ...[
                        _mySubmissions(context),
                        const SizedBox(height: Insets.md),
                      ],
                      _ctaRow(context),
                      const SizedBox(height: Insets.sm),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = ShadTheme.of(context);
    final session = context.session;
    final name = session.user?.displayName ?? 'there';
    final initials = name.isEmpty ? '?' : name[0].toUpperCase();

    return Row(
      children: [
        ShadAvatar(
          null,
          placeholder: Text(initials, style: AppType.body(size: 14)),
          size: const Size.square(38),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: theme.textTheme.h3),
              const SizedBox(height: 1),
              Text('Welcome back, $name', style: theme.textTheme.muted),
            ],
          ),
        ),
        ShadButton.outline(
          size: ShadButtonSize.sm,
          // The router redirect drops us off this guarded route as soon as the
          // session clears, so no manual navigation is needed.
          onPressed: () async => context.session.signOut(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }

  /// The "section cards" row from dashboard-01. Every badge here is computed
  /// from real data; the block's placeholder trend chips are not carried over.
  Widget _sectionCards(
    BuildContext context,
    int thisMonth,
    int monthDelta,
    bool wide,
  ) {
    final cards = [
      _StatCard(
        label: 'Bidets mapped',
        value: '${_bidets.length}',
        icon: Icons.place_outlined,
        footnote: '$_unrated still unrated',
      ),
      _StatCard(
        label: 'Average score',
        value: _avgRating == 0 ? '—' : _avgRating.toStringAsFixed(1),
        icon: Icons.star_outline_rounded,
        suffix: _avgRating == 0 ? null : '/5',
        footnote: '$_topRated rated 4.0 or better',
      ),
      _StatCard(
        label: 'Added this month',
        value: '$thisMonth',
        icon: Icons.trending_up,
        badge: monthDelta == 0
            ? null
            : (monthDelta > 0 ? '+$monthDelta' : '$monthDelta'),
        badgeUp: monthDelta > 0,
        footnote: 'vs ${thisMonth - monthDelta} last month',
      ),
    ];

    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: Insets.md),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: Insets.md),
          cards[i],
        ],
      ],
    );
  }

  /// dashboard-01's chart area. Bars rather than an area chart, because the
  /// series is six discrete monthly counts, not a continuous signal.
  Widget _chartCard(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = context.shad;
    final months = _last6Months;
    final peak = months.map((m) => m.count).fold(0, (a, b) => a > b ? a : b);

    return ShadCard(
      width: double.infinity,
      title: const Text('Added per month'),
      description: const Text('New bidets accepted over the last six months.'),
      child: Padding(
        padding: const EdgeInsets.only(top: Insets.lg),
        child: SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in months)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${m.count}',
                          style: AppType.figure(
                            size: 12,
                            color: cs.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Zero months still get a hairline, so the baseline
                        // reads as a row rather than a gap.
                        Container(
                          height: peak == 0
                              ? 2
                              : (m.count / peak * 96).clamp(2, 96).toDouble(),
                          decoration: BoxDecoration(
                            color: m == months.last
                                ? cs.primary
                                : cs.primary.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(Radii.xs),
                          ),
                        ),
                        const SizedBox(height: Insets.sm),
                        Text(m.label, style: theme.textTheme.muted),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _criteriaCard(BuildContext context) {
    final rated = _bidets.where((b) => b.ratingCount > 0).length;

    return ShadCard(
      width: double.infinity,
      title: const Text('How Cebu scores it'),
      description: Text(
        rated == 0
            ? 'No ratings yet.'
            : 'Averaged across $rated rated ${rated == 1 ? 'bidet' : 'bidets'}.',
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: Insets.lg),
        child: Column(
          children: [
            _CriteriaBar('Cleanliness', _criteriaAvg((b) => b.cleanlinessRating)),
            _CriteriaBar('Water pressure', _criteriaAvg((b) => b.pressureRating)),
            _CriteriaBar(
                'Accessibility', _criteriaAvg((b) => b.accessibilityRating)),
            _CriteriaBar('Privacy', _criteriaAvg((b) => b.privacyRating)),
          ],
        ),
      ),
    );
  }

  /// dashboard-01's tabbed data table, using ShadTabs + ShadTable.
  Widget _tableCard(BuildContext context) {
    final theme = ShadTheme.of(context);
    final rows = _tableData;

    return ShadCard(
      width: double.infinity,
      title: const Text('Browse'),
      description: Text('Showing ${rows.length} of ${_bidets.length}.'),
      child: Padding(
        padding: const EdgeInsets.only(top: Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShadTabs<int>(
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
              tabs: [
                for (final (i, label) in const [
                  (0, 'Recent'),
                  (1, 'Top rated'),
                  (2, 'A–Z'),
                ])
                  ShadTab(value: i, child: Text(label)),
              ],
            ),
            const SizedBox(height: Insets.md),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xxl),
                child: Center(
                  child: Text(
                    'Nothing mapped yet.',
                    style: theme.textTheme.muted,
                  ),
                ),
              )
            else
              // ShadTable is a two-dimensional scrollable, so it needs a
              // bounded height — inside the page's ListView it would otherwise
              // be handed unbounded space and fail layout. Rows are capped at
              // eight, so the height is deterministic.
              SizedBox(
                height: _kRowHeight * (rows.length + 1) + 2,
                child: ShadTable.list(
                  rowSpanExtent: (_) =>
                      const FixedTableSpanExtent(_kRowHeight),
                  header: const [
                    ShadTableCell.header(child: Text('Place')),
                    ShadTableCell.header(child: Text('Type')),
                    ShadTableCell.header(
                        alignment: Alignment.centerRight, child: Text('Score')),
                    ShadTableCell.header(
                        alignment: Alignment.centerRight, child: Text('Added')),
                  ],
                  columnSpanExtent: (index) {
                    if (index == 0) return const FixedTableSpanExtent(180);
                    if (index == 1) return const FixedTableSpanExtent(132);
                    return const FixedTableSpanExtent(76);
                  },
                  children: [
                  for (final b in rows)
                    [
                      ShadTableCell(
                        child: Text(
                          b.placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: context.shad.foreground,
                          ),
                        ),
                      ),
                      ShadTableCell(child: _TypeBadge(b.type)),
                      ShadTableCell(
                        alignment: Alignment.centerRight,
                        child: Text(
                          b.ratingCount == 0
                              ? '—'
                              : b.rating.toStringAsFixed(1),
                          style: AppType.figure(
                            size: 13,
                            color: context.shad.foreground,
                          ),
                        ),
                      ),
                      ShadTableCell(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _fmtDate(b.createdAt),
                          style: theme.textTheme.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: Insets.md),
              const ShadSeparator.horizontal(margin: EdgeInsets.zero),
              const SizedBox(height: Insets.md),
              Align(
                alignment: Alignment.centerLeft,
                child: ShadButton.link(
                  padding: EdgeInsets.zero,
                  onPressed: () => context.push(
                    Routes.bidet(rows.first.id),
                    extra: BidetDetailArgs(bidet: rows.first, distance: ''),
                  ),
                  child: const Text('Open the most recent'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Your own submissions, with their real status. A pending row now says so,
  /// and a rejected one carries the moderator's reason.
  Widget _mySubmissions(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = context.shad;
    final pending = _mine.where((b) => b.status == BidetStatus.pending).length;

    return ShadCard(
      width: double.infinity,
      title: const Text('Your submissions'),
      description: Text(
        pending == 0
            ? '${_mine.length} submitted.'
            : '${_mine.length} submitted · $pending awaiting review.',
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: Insets.md),
        child: Column(
          children: [
            for (var i = 0; i < _mine.length && i < 6; i++) ...[
              if (i > 0) Divider(height: 20, color: cs.border),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _mine[i].placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.small,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _mine[i].floor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.muted,
                        ),
                        if (_mine[i].status == BidetStatus.rejected &&
                            (_mine[i].rejectionReason?.isNotEmpty ?? false)) ...[
                          const SizedBox(height: 3),
                          Text(
                            _mine[i].rejectionReason!,
                            style: AppType.body(
                              size: 12,
                              color: cs.destructive,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  _StatusBadge(_mine[i].status),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ctaRow(BuildContext context) {
    final open = ShadButton(
      onPressed: () => context.push(Routes.map),
      leading: const Icon(Icons.map_outlined, size: 16),
      child: const Text('Open the map'),
    );
    final add = ShadButton.outline(
      onPressed: () => context.push(Routes.addBidet),
      leading: const Icon(Icons.add, size: 16),
      child: const Text('Add a bidet'),
    );

    // Side by side there is not always room for an icon and a label; stacking
    // on narrow screens avoids squeezing the button's own content row.
    if (context.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [open, const SizedBox(height: Insets.sm), add],
      );
    }
    return Row(
      children: [
        Expanded(child: open),
        const SizedBox(width: Insets.md),
        Expanded(child: add),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.suffix,
    this.badge,
    this.badgeUp = true,
    this.footnote,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? suffix;
  final String? badge;
  final bool badgeUp;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = context.shad;

    return ShadCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: cs.mutedForeground),
              const SizedBox(width: 7),
              Expanded(child: Text(label, style: theme.textTheme.muted)),
              if (badge != null)
                badgeUp
                    ? ShadBadge.secondary(child: Text(badge!))
                    : ShadBadge.destructive(child: Text(badge!)),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppType.figure(size: 28, color: cs.foreground)),
              if (suffix != null) ...[
                const SizedBox(width: 3),
                Text(suffix!, style: theme.textTheme.muted),
              ],
            ],
          ),
          if (footnote != null) ...[
            const SizedBox(height: 4),
            Text(footnote!, style: theme.textTheme.muted),
          ],
        ],
      ),
    );
  }
}

class _CriteriaBar extends StatelessWidget {
  const _CriteriaBar(this.label, this.value);

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = context.shad;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            child: Text(label, style: theme.textTheme.muted),
          ),
          Expanded(
            child: ShadProgress(
              value: (value / 5).clamp(0.0, 1.0),
              minHeight: 7,
            ),
          ),
          const SizedBox(width: Insets.md),
          SizedBox(
            width: 26,
            child: Text(
              value == 0 ? '—' : value.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: AppType.figure(size: 12.5, color: cs.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.type);

  final BidetType type;

  static Color _colorFor(BidetType type) => switch (type) {
        BidetType.bidetSeat => AppColors.typeSeat,
        BidetType.tabo => AppColors.typeTabo,
        BidetType.sprayHose => AppColors.typeSpray,
      };

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(type);
    return ShadBadge.outline(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              type.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.body(size: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final BidetStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
        BidetStatus.approved => const ShadBadge(child: Text('Live')),
        BidetStatus.pending =>
          const ShadBadge.secondary(child: Text('In review')),
        BidetStatus.rejected =>
          const ShadBadge.destructive(child: Text('Rejected')),
      };
}
