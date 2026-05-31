import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import '../map/map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF1A6B3C);
  static const _greenDark = Color(0xFF0E4F2A);
  static const _accent = Color(0xFF34C77B);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF8),
      body: Stack(
        children: [
          // Gradient hero background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_greenDark, _green, Color(0xFF237D49)],
              ),
            ),
            height: MediaQuery.of(context).size.height * 0.60,
          ),
          // Decorative translucent circles
          Positioned(
            top: -60,
            right: -50,
            child: _blob(200, Colors.white.withValues(alpha: 0.08)),
          ),
          Positioned(
            top: 120,
            left: -70,
            child: _blob(180, Colors.white.withValues(alpha: 0.06)),
          ),
          // Floating water-drop accents
          const Positioned(
            top: 150,
            right: 40,
            child: Icon(Icons.water_drop,
                color: Colors.white24, size: 26),
          ),
          const Positioned(
            top: 240,
            left: 36,
            child: Icon(Icons.water_drop_outlined,
                color: Colors.white24, size: 18),
          ),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _logoPill(),
                        const SizedBox(height: 40),
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
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 14.5,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _heroStatsRow(),
                        const SizedBox(height: 26),
                        _featureCard(),
                        const SizedBox(height: 18),
                        _ctaButtons(context),
                      ],
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
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.water_drop, color: Colors.white, size: 16),
          SizedBox(width: 7),
          Text('SanBidet Cebu',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }

  Widget _heroStatsRow() {
    return Row(
      children: [
        _heroStat('Spray hose', 'Tabo · Seat'),
        const SizedBox(width: 12),
        _heroStat('Rated', 'by locals'),
        const SizedBox(width: 12),
        _heroStat('Live map', 'updated'),
      ],
    );
  }

  Widget _heroStat(String top, String bottom) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(top,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(bottom,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10.5)),
          ],
        ),
      ),
    );
  }

  Widget _featureCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _greenDark.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _featureRow(Icons.near_me_outlined, 'Nearby first',
              'Sorted by real distance from you'),
          const Divider(height: 24),
          _featureRow(Icons.star_outline_rounded, 'Detailed ratings',
              'Cleanliness, pressure, privacy & more'),
          const Divider(height: 24),
          _featureRow(Icons.add_location_alt_outlined, 'Add your finds',
              'Help the community grow the map'),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _green, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2B22))),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ctaButtons(BuildContext context) {
    return Column(
      children: [
        // Browse map (primary)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MapScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: _accent.withValues(alpha: 0.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 19),
                SizedBox(width: 9),
                Text('Browse the map',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen())),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: const BorderSide(color: _green, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Sign in',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14.5)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const LoginScreen(isAdmin: true))),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade500,
                  backgroundColor: const Color(0xFFEFF3F0),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.admin_panel_settings_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('Admin',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
