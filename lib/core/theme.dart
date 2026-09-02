import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// The app's palette and type.
///
/// Structure: the surfaces are **neutral** and the saturated colours are spent
/// only on things that carry meaning — the primary action, a rating, a bidet
/// type, a status. The previous version tinted every neutral toward the brand
/// green, so the whole app read as green-on-green and the accent had nothing
/// left to stand out against.
abstract final class AppColors {
  // --- Neutrals -----------------------------------------------------------
  // A true neutral ramp with the faintest warm cast, so white surfaces sit on
  // it without looking blue. These carry the interface; nothing here is brand.
  static const canvas = Color(0xFFF7F7F6);
  static const surface = Color(0xFFFFFFFF);
  static const subtle = Color(0xFFF1F1F0);
  static const line = Color(0xFFE3E3E1);
  static const ink = Color(0xFF1B1B19);
  static const inkMuted = Color(0xFF71716C);

  static const darkCanvas = Color(0xFF0C0C0B);
  static const darkSurface = Color(0xFF171716);
  static const darkSubtle = Color(0xFF1F1F1D);
  static const darkLine = Color(0xFF2C2C29);
  static const darkInk = Color(0xFFF2F2F0);
  static const darkInkMuted = Color(0xFF9C9C95);

  // --- Accents ------------------------------------------------------------
  // Saturated, and used sparingly: a primary action, a live figure, an alert.
  /// Primary action / brand. Brighter than the old #1A6B3C, because it now
  /// appears on a neutral ground instead of a green one.
  static const green = Color(0xFF14875A);
  static const greenDark = Color(0xFF0E6544);
  static const greenMid = Color(0xFF17A06A);
  static const greenBright = Color(0xFF2DD48A);
  static const darkGreen = Color(0xFF34D399);

  /// Ratings and highlights.
  static const amber = Color(0xFFE0A210);

  // --- Data encoding ------------------------------------------------------
  // One fixed hue per bidet type, shared by the list icon, the chip and the
  // map pin so the colour is learnable. Fixed across themes: these sit on map
  // tiles as often as on app surfaces.
  static const typeSpray = Color(0xFF0E9488);
  static const typeSeat = Color(0xFF7C5CD6);
  static const typeTabo = Color(0xFF2A7FD4);

  static const pin = Color(0xFF14875A);
  static const pinSelected = Color(0xFFE2571B);
  static const userDot = Color(0xFF2A7FD4);
}

/// Spacing scale — replaces ad-hoc SizedBox values.
abstract final class Insets {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;

  /// Width cap so phone-shaped layouts stay readable in a wide browser.
  static const contentMaxWidth = 560.0;
}

abstract final class Radii {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
  static const pill = 30.0;
}

/// Typography.
///
/// Bricolage Grotesque carries the headings — it has real character in the
/// letterforms, which the stock system font did not. Plus Jakarta Sans does
/// the reading: warm, high x-height, legible at small sizes.
abstract final class AppType {
  static TextStyle display({
    double size = 42,
    FontWeight weight = FontWeight.w800,
    Color? color,
    double height = 1.08,
    double tracking = -1.0,
  }) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: tracking,
      );

  static TextStyle heading({
    double size = 20,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double height = 1.2,
  }) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: -0.4,
      );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.5,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  /// Numbers that line up in a column — distances, ratings, counts.
  static TextStyle figure({
    double size = 14,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Small uppercase label for section headers and metadata.
  static TextStyle label({
    double size = 11.5,
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.2,
        letterSpacing: 0.6,
      );
}

extension ThemeContext on BuildContext {
  ShadColorScheme get shad => ShadTheme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;

  /// Layout breakpoints. The app ships as both a phone APK and a desktop web
  /// build, so screens need to know which one they are running on.
  bool get isCompact => MediaQuery.sizeOf(this).width < 600;
  bool get isExpanded => MediaQuery.sizeOf(this).width >= 1000;
}

abstract final class AppTheme {
  static ShadThemeData light() => ShadThemeData(
        brightness: Brightness.light,
        colorScheme: _light,
        textTheme: _shadText(AppColors.ink, AppColors.inkMuted),
      );

  static ShadThemeData dark() => ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: _dark,
        textTheme: _shadText(AppColors.darkInk, AppColors.darkInkMuted),
      );

  /// shadcn's own text scale, so ShadCard titles and ShadButton labels pick up
  /// the new faces instead of falling back to the framework default.
  static ShadTextTheme _shadText(Color ink, Color muted) => ShadTextTheme(
        family: GoogleFonts.plusJakartaSans().fontFamily,
        h1Large: AppType.display(size: 44, color: ink),
        h1: AppType.display(size: 34, color: ink),
        h2: AppType.heading(size: 26, color: ink),
        h3: AppType.heading(size: 21, color: ink),
        h4: AppType.heading(size: 17, color: ink),
        p: AppType.body(size: 14.5, color: ink),
        lead: AppType.body(size: 16, color: muted, height: 1.55),
        large: AppType.body(size: 15.5, weight: FontWeight.w700, color: ink),
        small: AppType.body(size: 13, weight: FontWeight.w600, color: ink),
        muted: AppType.body(size: 13, color: muted),
      );

  /// Built by overriding the stock scheme rather than hand-writing all ~25
  /// shadcn slots, so future shadcn additions still resolve.
  static final _light = const ShadSlateColorScheme.light().copyWith(
    background: AppColors.canvas,
    foreground: AppColors.ink,
    card: AppColors.surface,
    cardForeground: AppColors.ink,
    popover: AppColors.surface,
    popoverForeground: AppColors.ink,
    primary: AppColors.green,
    primaryForeground: Colors.white,
    secondary: AppColors.subtle,
    secondaryForeground: AppColors.ink,
    muted: AppColors.subtle,
    mutedForeground: AppColors.inkMuted,
    accent: AppColors.subtle,
    accentForeground: AppColors.ink,
    border: AppColors.line,
    input: AppColors.line,
    ring: AppColors.green,
  );

  static final _dark = const ShadSlateColorScheme.dark().copyWith(
    background: AppColors.darkCanvas,
    foreground: AppColors.darkInk,
    card: AppColors.darkSurface,
    cardForeground: AppColors.darkInk,
    popover: AppColors.darkSurface,
    popoverForeground: AppColors.darkInk,
    primary: AppColors.darkGreen,
    primaryForeground: const Color(0xFF04231A),
    secondary: AppColors.darkSubtle,
    secondaryForeground: AppColors.darkInk,
    muted: AppColors.darkSubtle,
    mutedForeground: AppColors.darkInkMuted,
    accent: AppColors.darkSubtle,
    accentForeground: AppColors.darkInk,
    border: AppColors.darkLine,
    input: AppColors.darkLine,
    ring: AppColors.darkGreen,
  );

  /// Keeps the Material widgets (AppBar, SnackBar, dialogs, form fields) on the
  /// same palette and type as the shadcn ones.
  static ThemeData materialFrom(BuildContext context, ThemeData base) {
    final shad = ShadTheme.of(context).colorScheme;
    final dark = base.brightness == Brightness.dark;
    final ink = dark ? AppColors.darkInk : AppColors.ink;
    final muted = dark ? AppColors.darkInkMuted : AppColors.inkMuted;

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        brightness: base.brightness,
      ).copyWith(
        primary: shad.primary,
        onPrimary: shad.primaryForeground,
        secondary: AppColors.amber,
        surface: shad.background,
        onSurface: shad.foreground,
      ),
      scaffoldBackgroundColor: shad.background,
      textTheme: _materialText(ink, muted),
      dividerTheme: DividerThemeData(color: shad.border, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: shad.background,
        foregroundColor: shad.foreground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.heading(size: 18, color: ink),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? AppColors.darkSubtle : AppColors.ink,
        contentTextStyle: AppType.body(size: 13.5, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: shad.primary),
    );
  }

  static TextTheme _materialText(Color ink, Color muted) => TextTheme(
        displaySmall: AppType.display(size: 42, color: ink),
        headlineMedium: AppType.heading(size: 28, color: ink),
        titleLarge: AppType.heading(size: 19, color: ink),
        titleMedium:
            AppType.body(size: 14.5, weight: FontWeight.w700, color: ink),
        bodyLarge: AppType.body(size: 14.5, color: ink),
        bodyMedium: AppType.body(size: 13.5, color: muted),
        bodySmall: AppType.body(size: 12, color: muted, height: 1.4),
        labelLarge: AppType.body(size: 14, weight: FontWeight.w700, color: ink),
        labelMedium: AppType.label(color: muted),
      );
}
