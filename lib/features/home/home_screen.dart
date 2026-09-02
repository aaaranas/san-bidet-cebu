import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/app_scope.dart';
import '../../core/router.dart';
import '../../core/theme.dart';

/// Landing page.
///
/// The full-bleed green gradient is gone: it filled two thirds of the viewport,
/// which left the accent nothing to stand against. The page now sits on the
/// neutral canvas and spends colour only where it means something — the type
/// chips, the rating figure, and the primary action.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shad = context.shad;

    return Scaffold(
      backgroundColor: shad.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: Insets.contentMaxWidth),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Wordmark(),
                        const SizedBox(height: 40),
                        Text(
                          'Find a bidet\nnear you.',
                          style: AppType.display(
                            size: context.isCompact ? 40 : 52,
                            color: shad.foreground,
                          ),
                        ),
                        const SizedBox(height: Insets.lg),
                        Text(
                          'A community directory of public bidets across Cebu, '
                          'mapped and rated by the people who use them.',
                          style: AppType.body(
                            size: 15,
                            color: shad.mutedForeground,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: Insets.xl),
                        const _TypeLegend(),
                        const SizedBox(height: Insets.xxl),
                        const _FeatureList(),
                        const SizedBox(height: Insets.xxl),
                        _actions(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final session = context.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final signedIn = session.isSignedIn;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShadButton(
              size: ShadButtonSize.lg,
              onPressed: () => context.go(Routes.map),
              leading: const Icon(Icons.map_outlined, size: 18),
              child: const Text('Browse the map'),
            ),
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    size: ShadButtonSize.lg,
                    onPressed: () => context.push(
                      signedIn ? Routes.dashboard : Routes.login,
                    ),
                    child: Text(signedIn ? 'Dashboard' : 'Sign in'),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: ShadButton.ghost(
                    size: ShadButtonSize.lg,
                    onPressed: () => context.push(
                      session.isAdmin ? Routes.admin : Routes.adminLogin,
                    ),
                    child: const Text('Moderator'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The mark. A small saturated block instead of a translucent pill on a
/// coloured field — it reads as the one branded element on a neutral page.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final shad = context.shad;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: const Icon(Icons.water_drop, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 9),
        Text(
          'SanBidet',
          style: AppType.heading(size: 16, color: shad.foreground),
        ),
        const SizedBox(width: 5),
        Text(
          'Cebu',
          style: AppType.body(size: 15, color: shad.mutedForeground),
        ),
      ],
    );
  }
}

/// The three bidet types, in the colours the map and list use for them. This
/// is where the saturated colour earns its place — it teaches the encoding
/// before the user reaches the map.
class _TypeLegend extends StatelessWidget {
  const _TypeLegend();

  static const _entries = [
    ('Spray hose', AppColors.typeSpray),
    ('Bidet seat', AppColors.typeSeat),
    ('Tabo', AppColors.typeTabo),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final (label, color) in _entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: AppType.body(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  static const _entries = [
    (
      Icons.near_me_outlined,
      'Nearest first',
      'Sorted by real distance from wherever you are standing.',
    ),
    (
      Icons.star_outline_rounded,
      'Four separate ratings',
      'Cleanliness, water pressure, accessibility and privacy.',
    ),
    (
      Icons.add_location_alt_outlined,
      'Added by locals',
      'Anyone can submit a find; a moderator checks it first.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final shad = context.shad;
    return ShadCard(
      width: double.infinity,
      child: Column(
        children: [
          for (var i = 0; i < _entries.length; i++) ...[
            if (i > 0) Divider(height: 24, color: shad.border),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: shad.muted,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Icon(
                    _entries[i].$1,
                    size: 17,
                    color: shad.mutedForeground,
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _entries[i].$2,
                        style: AppType.body(
                          size: 14.5,
                          weight: FontWeight.w700,
                          color: shad.foreground,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _entries[i].$3,
                        style: AppType.body(
                          size: 13,
                          color: shad.mutedForeground,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
