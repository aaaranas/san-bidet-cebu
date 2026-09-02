import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:san_bidet_cebu/core/app_scope.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:san_bidet_cebu/core/theme.dart';
import 'package:san_bidet_cebu/data/auth_repository.dart';
import 'package:san_bidet_cebu/data/models/bidet.dart';
import 'package:san_bidet_cebu/services/location_service.dart';
import 'package:san_bidet_cebu/widgets/app_widgets.dart';
import 'package:san_bidet_cebu/widgets/bidet_card.dart';
import 'package:san_bidet_cebu/features/dashboard/dashboard_screen.dart';
import 'package:san_bidet_cebu/features/bidet/bidet_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fakes.dart';

/// Wraps a widget in the theme + DI scope it expects. This is only possible
/// because screens now resolve their dependencies from AppScope instead of
/// constructing a Supabase client themselves.
Widget wrap(
  Widget child, {
  FakeBidetRepository? bidets,
  FakeAuthRepository? auth,
  Size size = const Size(400, 800),
}) {
  final bidetRepo = bidets ?? FakeBidetRepository();
  final authRepo = auth ?? FakeAuthRepository();
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: AppScope(
      bidets: bidetRepo,
      auth: authRepo,
      session: SessionController(authRepo),
      location: const LocationService(),
      child: ShadApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  // Tests have no network; without this google_fonts logs a fetch failure for
  // every style resolved and slows the suite down. The fallback face is fine
  // for layout assertions.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('DashboardScreen', () {
    testWidgets('renders the shadcn blocks against live data', (tester) async {
      final bidets = FakeBidetRepository(bidets: [
        makeBidet(id: 'a', placeName: 'SM City Cebu', rating: 4.4, ratingCount: 9),
        makeBidet(
          id: 'b',
          placeName: 'Ayala Center',
          type: BidetType.bidetSeat,
          rating: 4.9,
          ratingCount: 3,
        ),
        makeBidet(id: 'c', placeName: 'Robinsons', type: BidetType.tabo),
      ]);
      final auth = FakeAuthRepository(
        user: const AppUser(id: 'u1', email: 'a@b.com', username: 'tester'),
      );
      addTearDown(() {
        bidets.dispose();
        auth.dispose();
      });

      await tester.pumpWidget(
        wrap(const DashboardScreen(),
            bidets: bidets, auth: auth, size: const Size(900, 1600)),
      );
      await tester.pumpAndSettle();

      // Header and section cards are above the fold.
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Welcome back, tester'), findsOneWidget);
      expect(find.text('Bidets mapped'), findsOneWidget);
      expect(find.text('Added per month'), findsOneWidget);

      // The ListView builds lazily, so the lower blocks need scrolling to.
      await tester.scrollUntilVisible(find.text('Browse'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('Browse'), findsOneWidget);
      expect(find.text('SM City Cebu'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('switching a tab reorders the table', (tester) async {
      final bidets = FakeBidetRepository(bidets: [
        makeBidet(id: 'a', placeName: 'Zebra Mall', rating: 2.0, ratingCount: 4),
        makeBidet(id: 'b', placeName: 'Alpha Mall', rating: 4.9, ratingCount: 4),
      ]);
      final auth = FakeAuthRepository(
        user: const AppUser(id: 'u1', username: 'tester'),
      );
      addTearDown(() {
        bidets.dispose();
        auth.dispose();
      });

      await tester.pumpWidget(
        wrap(const DashboardScreen(),
            bidets: bidets, auth: auth, size: const Size(900, 1600)),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Top rated'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Top rated'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Alpha Mall'), findsWidgets);
    });
  });

  group('BidetDetailScreen', () {
    testWidgets('shows access, cost, attribution and directions',
        (tester) async {
      final bidet = makeBidet(id: 'a', rating: 4.4, ratingCount: 6).copyWith(
        accessType: AccessType.customer,
        hoursNote: 'Mall hours',
        feeNote: 'PHP 5',
        submittedByUsername: 'bidet_hunter',
      );
      final bidets = FakeBidetRepository(bidets: [bidet]);
      addTearDown(bidets.dispose);

      await tester.pumpWidget(
        wrap(
          BidetDetailScreen(
            bidetId: 'a',
            initial: BidetDetailArgs(bidet: bidet, distance: '350m'),
          ),
          bidets: bidets,
          size: const Size(500, 1400),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Customers only'), findsWidgets);
      expect(find.text('Mall hours'), findsOneWidget);
      expect(find.text('PHP 5'), findsOneWidget);
      expect(find.text('@bidet_hunter'), findsOneWidget);
      expect(find.text('Directions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('offers to change an existing rating', (tester) async {
      final bidet = makeBidet(id: 'a', rating: 4.0, ratingCount: 2);
      final bidets = FakeBidetRepository(bidets: [bidet]);
      bidets.myRatings['a'] = const BidetRating(
        cleanliness: 4,
        pressure: 4,
        accessibility: 4,
        privacy: 4,
      );
      final auth = FakeAuthRepository(
        user: const AppUser(id: 'u1', username: 'tester'),
      );
      addTearDown(() {
        bidets.dispose();
        auth.dispose();
      });

      await tester.pumpWidget(
        wrap(
          BidetDetailScreen(
            bidetId: 'a',
            initial: BidetDetailArgs(bidet: bidet, distance: '350m'),
          ),
          bidets: bidets,
          auth: auth,
          size: const Size(500, 1400),
        ),
      );
      await tester.pumpAndSettle();

      // Reading your own rating back is what turns the blank form into an edit.
      expect(find.text('Change your rating'), findsOneWidget);
      expect(find.textContaining('You rated this'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('BidetCard', () {
    testWidgets('shows name, rating and distance', (tester) async {
      await tester.pumpWidget(
        wrap(
          BidetCard(
            bidet: makeBidet(rating: 4.2, ratingCount: 8),
            distance: '350m',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('SM City Cebu'), findsOneWidget);
      expect(find.text('4.2'), findsOneWidget);
      expect(find.text('350m'), findsOneWidget);
    });

    testWidgets('labels an unrated bidet instead of showing 0.0',
        (tester) async {
      await tester.pumpWidget(
        wrap(BidetCard(bidet: makeBidet(), distance: '', onTap: () {})),
      );

      expect(find.text('Unrated'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('gives each bidet type its own icon', (tester) async {
      // The old card switched on a 'hotel' type that never existed, so bidet
      // seats silently fell through to the generic default.
      for (final (type, icon) in [
        (BidetType.bidetSeat, Icons.event_seat_outlined),
        (BidetType.tabo, Icons.water_drop_outlined),
        (BidetType.sprayHose, Icons.shower_outlined),
      ]) {
        await tester.pumpWidget(
          wrap(
            BidetCard(
              bidet: makeBidet(type: type),
              distance: '',
              onTap: () {},
            ),
          ),
        );
        expect(find.byIcon(icon), findsOneWidget, reason: '$type');
      }
    });

    testWidgets('marks a bidet the user already rated', (tester) async {
      await tester.pumpWidget(
        wrap(BidetCard(
          bidet: makeBidet(rating: 4.0, ratingCount: 3),
          distance: '120m',
          rated: true,
          onTap: () {},
        )),
      );
      expect(find.text('Rated'), findsOneWidget);
    });

    testWidgets('reports taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          BidetCard(
            bidet: makeBidet(),
            distance: '',
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(BidetCard));
      expect(tapped, isTrue);
    });
  });

  group('shared widgets', () {
    testWidgets('EmptyState renders its title, message and action',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          EmptyState(
            icon: Icons.wc_outlined,
            title: 'Nothing here',
            message: 'Try again later.',
            action: OutlinedButton(onPressed: () {}, child: const Text('Retry')),
          ),
        ),
      );

      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Try again later.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('AppTextField toggles password visibility', (tester) async {
      var obscured = true;
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => AppTextField(
              label: 'Password',
              controller: TextEditingController(),
              obscure: obscured,
              onToggleObscure: () => setState(() => obscured = !obscured),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('StarRow renders five stars', (tester) async {
      await tester.pumpWidget(wrap(const StarRow(rating: 3)));

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
    });
  });

  group('theme', () {
    test('light and dark are both built on the slate scheme', () {
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
    });

    test('dark scheme actually differs from light', () {
      // Dark mode was missing entirely before the merge.
      final light = AppTheme.light().colorScheme;
      final dark = AppTheme.dark().colorScheme;
      expect(dark.background, isNot(equals(light.background)));
      expect(dark.foreground, isNot(equals(light.foreground)));
    });
  });

  group('SessionController', () {
    test('starts signed out and follows the auth stream', () async {
      final auth = FakeAuthRepository();
      final session = SessionController(auth);
      addTearDown(() {
        session.dispose();
        auth.dispose();
      });

      await Future<void>.delayed(Duration.zero);
      expect(session.isSignedIn, isFalse);
      expect(session.isReady, isTrue);

      await auth.signIn('a@b.com', 'pw');
      await Future<void>.delayed(Duration.zero);
      expect(session.isSignedIn, isTrue);
      expect(session.user?.username, 'tester');

      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(session.isSignedIn, isFalse);
    });

    test('restores an already-signed-in user immediately', () async {
      final auth = FakeAuthRepository(
        user: const AppUser(id: 'u1', email: 'a@b.com', username: 'tester'),
      );
      final session = SessionController(auth);
      addTearDown(() {
        session.dispose();
        auth.dispose();
      });

      await Future<void>.delayed(Duration.zero);
      expect(session.isSignedIn, isTrue);
    });
  });

  group('AppUser', () {
    test('falls back to the email local part when no username is set', () {
      const user = AppUser(id: 'u1', email: 'juan@example.com');
      expect(user.displayName, 'juan');
    });

    test('prefers the username', () {
      const user = AppUser(id: 'u1', email: 'j@e.com', username: 'bidet_hunter');
      expect(user.displayName, 'bidet_hunter');
    });
  });
}
