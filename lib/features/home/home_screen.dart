import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import '../map/map_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _green = Color(0xFF1A6B3C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Top green background shape
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.52,
            child: Container(
              decoration: const BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.water_drop,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text('SanBidet Cebu',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Find a bidet\nnear you.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Crowdsourced bidet locations\nacross Cebu — mapped by the community.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom content
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            top: MediaQuery.of(context).size.height * 0.46,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Stat chips
                  Row(
                    children: [
                      _statChip(Icons.wc_outlined, 'Bidets mapped'),
                      const SizedBox(width: 10),
                      _statChip(Icons.people_outline, 'Community'),
                      const SizedBox(width: 10),
                      _statChip(Icons.verified_outlined, 'Verified'),
                    ],
                  ),

                  const Spacer(),

                  // Browse map (guest)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MapScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Browse the map',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // User login
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen())),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        side: const BorderSide(color: _green, width: 1.5),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Sign in as user',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Admin login (subtle)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const LoginScreen(isAdmin: true))),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade400,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.admin_panel_settings_outlined,
                              size: 15,
                              color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          const Text('Admin login',
                              style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F8F3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: _green, size: 18),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: _green)),
          ],
        ),
      ),
    );
  }
}