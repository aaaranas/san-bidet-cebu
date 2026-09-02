import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// The app's own palette.
///
/// shadcn stays as the component substrate, but the colours are the project's
/// rather than the library's. The stock `ShadSlateColorScheme` was the single
/// most generic thing in the build — it is the default every shadcn project
/// ships with, and it made SanBidet look like any other dashboard while the
/// landing page still carried the real green identity.
abstract final class AppColors {
  /// SanBidet green. The brand the project started with.
  static const green = Color(0xFF1A6B3C);
  static const greenDark = Color(0xFF0E4F2A);
  static const greenMid = Color(0xFF237D49);
  static const greenBright = Color(0xFF34C77B);

  /// Neutrals biased toward the brand instead of a stock cool grey, so the
  /// whole surface reads as one family rather than green-on-slate.
  static const canvas = Color(0xFFF4F8F5);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFD9E4DC);
  static const ink = Color(0xFF13251B);
  static const inkMuted = Color(0xFF5A6B60);

  static const darkCanvas = Color(0xFF0B1310);
  static const darkSurface = Color(0xFF13201A);
  static const darkLine = Color(0xFF25382D);
  static const darkInk = Color(0xFFE4EDE7);
  static const darkInkMuted = Color(0xFF93A69A);
  static const darkGreen = Color(0xFF4FBF83);

  /// Map pin colours — data encodings, not theme colours, so they stay fixed
  /// across light and dark for legibility over map tiles.
  static const pin = green;
  static const pinSelected = Color(0xFFE65100);
  static const userDot = Color(0xFF2C7BB6);
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
      );

  static ShadThemeData dark() => ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: _dark,
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
    secondary: const Color(0xFFE7F1EA),
    secondaryForeground: AppColors.greenDark,
    muted: const Color(0xFFECF3EE),
    mutedForeground: AppColors.inkMuted,
    accent: const Color(0xFFE7F1EA),
    accentForeground: AppColors.greenDark,
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
    primaryForeground: const Color(0xFF06210F),
    secondary: const Color(0xFF1A2C22),
    secondaryForeground: AppColors.darkInk,
    muted: const Color(0xFF17251E),
    mutedForeground: AppColors.darkInkMuted,
    accent: const Color(0xFF1A2C22),
    accentForeground: AppColors.darkInk,
    border: AppColors.darkLine,
    input: AppColors.darkLine,
    ring: AppColors.darkGreen,
  );

  /// Keeps the Material widgets (AppBar, SnackBar, dialogs) on the same palette
  /// as the shadcn ones.
  static ThemeData materialFrom(BuildContext context, ThemeData base) {
    final shad = ShadTheme.of(context).colorScheme;
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        brightness: base.brightness,
      ).copyWith(
        primary: shad.primary,
        onPrimary: shad.primaryForeground,
        surface: shad.background,
        onSurface: shad.foreground,
      ),
      scaffoldBackgroundColor: shad.background,
      dividerTheme: DividerThemeData(color: shad.border, thickness: 1),
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
    );
  }
}
