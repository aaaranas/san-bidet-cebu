import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/bidet/bidet_add_screen.dart';
import '../features/bidet/bidet_detail_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/home/home_screen.dart';
import '../features/map/map_screen.dart';
import 'app_scope.dart';
import 'theme.dart';

abstract final class Routes {
  static const home = '/';
  static const map = '/map';
  static const login = '/login';
  static const adminLogin = '/login/admin';
  static const signup = '/signup';
  static const dashboard = '/dashboard';
  static const addBidet = '/add';
  static const admin = '/admin';

  static String bidet(String id) => '/bidet/$id';
}

/// Declarative routing, replacing imperative Navigator.push calls.
///
/// This is what gives the web build real URLs — `/bidet/<id>` is now
/// bookmarkable and shareable — and it is the same mechanism Android App
/// Links hand off to, so one shared link works on both targets.
GoRouter buildRouter(SessionController session) {
  return GoRouter(
    initialLocation: Routes.home,
    // Re-evaluates redirects whenever auth state changes, so signing out drops
    // the user off a guarded page without any screen having to handle it.
    refreshListenable: session,
    redirect: (context, state) {
      // Hold everything until the persisted session is restored, otherwise a
      // web refresh flashes the landing page before bouncing onward.
      if (!session.isReady) return null;

      final path = state.matchedLocation;
      final signedIn = session.isSignedIn;

      const guarded = {Routes.addBidet, Routes.dashboard};
      if (guarded.contains(path) && !signedIn) {
        return '${Routes.login}?from=${Uri.encodeComponent(state.uri.toString())}';
      }

      if (path == Routes.admin && !session.isAdmin) {
        return signedIn ? Routes.dashboard : Routes.adminLogin;
      }

      // Already signed in? Skip the auth screens.
      if (signedIn &&
          (path == Routes.login ||
              path == Routes.signup ||
              path == Routes.adminLogin)) {
        return session.isAdmin ? Routes.admin : Routes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
      GoRoute(path: Routes.map, builder: (_, __) => const MapScreen()),
      GoRoute(
        path: Routes.dashboard,
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, state) => LoginScreen(
          redirectTo: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: Routes.adminLogin,
        builder: (_, __) => const LoginScreen(adminMode: true),
      ),
      GoRoute(path: Routes.signup, builder: (_, __) => const SignupScreen()),
      GoRoute(path: Routes.addBidet, builder: (_, __) => const BidetAddScreen()),
      GoRoute(path: Routes.admin, builder: (_, __) => const AdminScreen()),
      GoRoute(
        path: '/bidet/:id',
        builder: (_, state) => BidetDetailScreen(
          bidetId: state.pathParameters['id']!,
          // Present when navigated from the map, absent on a cold deep link.
          initial: state.extra as BidetDetailArgs?,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.explore_off_outlined,
                  size: 52,
                  color: context.shad.mutedForeground,
                ),
                const SizedBox(height: Insets.md),
                Text(
                  'Page not found',
                  style: context.texts.titleLarge,
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  state.uri.toString(),
                  style: TextStyle(color: context.shad.mutedForeground),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Insets.xl),
                FilledButton(
                  onPressed: () => context.go(Routes.home),
                  child: const Text('Go home'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
