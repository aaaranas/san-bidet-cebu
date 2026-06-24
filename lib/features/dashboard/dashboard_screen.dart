import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../auth/login_screen.dart';
import '../bidet/bidet_model.dart';
import '../bidet/bidet_add_screen.dart';
import '../map/map_screen.dart';

/// shadcn "dashboard-01" adapted to Flutter: section stat cards, a criteria
/// breakdown, a 6-month bar chart, and a tabbed data table — fed by the live
/// bidet data. Shown to logged-in users as their home.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _auth = AuthService();
  final _service = SupabaseService();
  StreamSubscription<List<Bidet>>? _sub;

  List<Bidet> _bidets = [];
  bool _loaded = false;
  int _tab = 0; // 0 = Recent, 1 = Top rated, 2 = All

  @override
  void initState() {
    super.initState();
    _sub = _service.getBidets().listen((b) {
      if (!mounted) return;
      setState(() {
        _bidets = b;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ---- derived metrics -------------------------------------------------

  double get _avgRating {
    final rated = _bidets.where((b) => b.ratingCount > 0).toList();
    if (rated.isEmpty) return 0;
    return rated.map((b) => b.rating).reduce((a, b) => a + b) / rated.length;
  }

  int get _topRated => _bidets.where((b) => b.rating >= 4).length;

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

  // ---- build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final thisMonth = _addedIn(DateTime(now.year, now.month));
    final lastMonth = _addedIn(DateTime(now.year, now.month - 1));
    final monthDelta = thisMonth - lastMonth;

    return Scaffold(
      backgroundColor: cs.muted,
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _header(theme),
                  const SizedBox(height: 16),
                  // Section cards (2x2)
                  Row(children: [
                    Expanded(
                        child: _statCard(theme, 'Total bidets', '${_bidets.length}',
                            Icons.wc_outlined,
                            badge: 'Cebu')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _statCard(theme, 'Avg rating',
                            _avgRating.toStringAsFixed(1), Icons.star_outline,
                            badge: '$_topRated top')),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _statCard(theme, 'Added this month', '$thisMonth',
                            Icons.trending_up,
                            badge: monthDelta >= 0 ? '+$monthDelta' : '$monthDelta',
                            badgePositive: monthDelta >= 0)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _statCard(theme, 'Highly rated', '$_topRated',
                            Icons.verified_outlined,
                            badge: '≥ 4.0★')),
                  ]),
                  const SizedBox(height: 16),
                  _criteriaCard(theme),
                  const SizedBox(height: 16),
                  _chartCard(theme),
                  const SizedBox(height: 16),
                  _tableCard(theme),
                  const SizedBox(height: 16),
                  _ctaRow(),
                  const SizedBox(height: 8),
                ],
              ),
      ),
    );
  }

  Widget _header(ShadThemeData theme) {
    final name = _auth.currentUsername ?? 'there';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard',
                  style: theme.textTheme.h3.copyWith(height: 1.1)),
              const SizedBox(height: 2),
              Text('Welcome back, $name', style: theme.textTheme.muted),
            ],
          ),
        ),
        ShadButton.ghost(
          onPressed: () async {
            await _auth.signOut();
            if (!mounted) return;
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
          child: const Text('Sign out'),
        ),
      ],
    );
  }

  Widget _statCard(ShadThemeData theme, String label, String value, IconData icon,
      {required String badge, bool badgePositive = true}) {
    final cs = theme.colorScheme;
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.mutedForeground),
              const Spacer(),
              badgePositive
                  ? ShadBadge.secondary(child: Text(badge))
                  : ShadBadge.destructive(child: Text(badge)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: cs.foreground,
                  height: 1)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.muted),
        ],
      ),
    );
  }

  Widget _criteriaCard(ShadThemeData theme) {
    Widget bar(String label, double value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.small)),
                Text('${value.toStringAsFixed(1)} / 5',
                    style: theme.textTheme.muted),
              ],
            ),
            const SizedBox(height: 6),
            ShadProgress(value: (value / 5).clamp(0, 1), minHeight: 8),
          ],
        ),
      );
    }

    return ShadCard(
      title: const Text('Ratings by criteria'),
      description: const Text('Community averages across all rated bidets'),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            bar('Cleanliness', _criteriaAvg((b) => b.cleanlinessRating)),
            bar('Water pressure', _criteriaAvg((b) => b.pressureRating)),
            bar('Accessibility', _criteriaAvg((b) => b.accessibilityRating)),
            bar('Privacy', _criteriaAvg((b) => b.privacyRating)),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(ShadThemeData theme) {
    final cs = theme.colorScheme;
    final months = _last6Months;
    final maxCount =
        months.map((m) => m.count).fold(0, (a, b) => a > b ? a : b);

    return ShadCard(
      title: const Text('Bidets added'),
      description: const Text('Last 6 months'),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in months)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${m.count}', style: theme.textTheme.muted),
                      const SizedBox(height: 4),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        height: maxCount == 0
                            ? 4
                            : 8 + (84 * m.count / maxCount),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(m.label, style: theme.textTheme.muted),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableCard(ShadThemeData theme) {
    final cs = theme.colorScheme;
    const tabs = ['Recent', 'Top rated', 'All'];
    final rows = _tableData;

    return ShadCard(
      title: const Text('Bidets'),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            // Segmented control (stands in for shadcn Tabs)
            Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0),
                      child: _tab == i
                          ? ShadButton(
                              size: ShadButtonSize.sm,
                              onPressed: () => setState(() => _tab = i),
                              child: Text(tabs[i]),
                            )
                          : ShadButton.ghost(
                              size: ShadButtonSize.sm,
                              onPressed: () => setState(() => _tab = i),
                              child: Text(tabs[i]),
                            ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Header
            Row(
              children: [
                Expanded(
                    flex: 5,
                    child: Text('Place',
                        style: theme.textTheme.muted
                            .copyWith(fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 3,
                    child: Text('Type',
                        style: theme.textTheme.muted
                            .copyWith(fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 2,
                    child: Text('★',
                        style: theme.textTheme.muted
                            .copyWith(fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 3,
                    child: Text('Added',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.muted
                            .copyWith(fontWeight: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: 4),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No bidets yet.', style: theme.textTheme.muted),
              )
            else
              for (final b in rows) ...[
                Divider(height: 18, color: cs.border),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(b.placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.small),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ShadBadge.outline(child: Text(b.typeLabel)),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(b.rating.toStringAsFixed(1),
                          style: theme.textTheme.small),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(_fmtDate(b.createdAt),
                          textAlign: TextAlign.end,
                          style: theme.textTheme.muted),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _ctaRow() {
    return Row(
      children: [
        Expanded(
          child: ShadButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MapScreen())),
            child: const Text('Open the map'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ShadButton.outline(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BidetAddScreen())),
            child: const Text('Add a bidet'),
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) => '${_monthAbbr(d.month)} ${d.day}';

  String _monthAbbr(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][(m - 1) % 12];
}
