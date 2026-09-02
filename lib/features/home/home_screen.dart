import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/router.dart';
import '../../core/theme.dart';

/// Landing page.
///
/// Keeps the gradient hero the project started with, but drops the decoration
/// that was carrying no information: two translucent blobs, two floating
/// water-drop icons, and a row of three "stats" whose values were hardcoded
/// strings ("Rated / by locals", "Live map / updated") rather than anything
/// measured. Colours now come from the shared scheme, so the landing and the
/// auth screens read as the same product.
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
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
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
      body: Stack(
        children: [
          // Hero. Sized from the viewport so it still covers the fold on a
          // short phone and a tall desktop.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height *
                (context.isCompact ? 0.56 : 0.66),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.greenDark,
                    AppColors.green,
                    AppColors.greenMid,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: Insets.contentMaxWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _logoPill(),
                            const SizedBox(height: 36),
                            const Text(
                              'Find a bidet\nnear you.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                height: 1.12,
                                letterSpacing: -1.2,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Crowdsourced bidet locations across Cebu — '
                              'mapped, rated and verified by the community.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14.5,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 30),
                            _featureCard(context),
                            const SizedBox(height: 18),
                            _ctaButtons(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.water_drop, color: Colors.white, size: 16),
          SizedBox(width: 7),
          Text(
            'SanBidet Cebu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureCard(BuildContext context) {
    final shad = context.shad;
    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: shad.card,
        borderRadius: BorderRadius.circular(Radii.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.greenDark.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _featureRow(
            context,
            Icons.near_me_outlined,
            'Nearby first',
            'Sorted by real distance from you',
          ),
          Divider(height: 26, color: shad.border),
          _featureRow(
            context,
            Icons.star_outline_rounded,
            'Four separate ratings',
            'Cleanliness, water pressure, accessibility and privacy',
          ),
          Divider(height: 26, color: shad.border),
          _featureRow(
            context,
            Icons.add_location_alt_outlined,
            'Added by locals',
            'Anyone can submit a find; a moderator checks it first',
          ),
        ],
      ),
    );
  }

  Widget _featureRow(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final shad = context.shad;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: shad.secondary,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Icon(icon, color: shad.primary, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: shad.foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  color: shad.mutedForeground,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ctaButtons(BuildContext context) {
    final shad = context.shad;
    final session = context.session;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final signedIn = session.isSignedIn;
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go(Routes.map),
                style: ElevatedButton.styleFrom(
                  backgroundColor: shad.primary,
                  foregroundColor: shad.primaryForeground,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, size: 19),
                    SizedBox(width: 9),
                    Text(
                      'Browse the map',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push(
                      signedIn ? Routes.dashboard : Routes.login,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: shad.primary,
                      backgroundColor: shad.card,
                      side: BorderSide(color: shad.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.lg),
                      ),
                    ),
                    child: Text(
                      signedIn ? 'Dashboard' : 'Sign in',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: TextButton(
                    onPressed: () => context.push(
                      session.isAdmin ? Routes.admin : Routes.adminLogin,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: shad.mutedForeground,
                      backgroundColor: shad.muted,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.lg),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.admin_panel_settings_outlined, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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
