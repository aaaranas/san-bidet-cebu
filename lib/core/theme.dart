import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Colour comes from shadcn's slate scheme (see [AppTheme]); this file only
/// carries the tokens shadcn does not provide — spacing, radii, and the few
/// brand/semantic values the map and markers need.
///
/// Deliberately *not* a competing palette: an earlier draft shipped an
/// `AppPalette` ThemeExtension, which duplicated what ShadTheme already
/// exposes. Read colours from `ShadTheme.of(context).colorScheme`.
abstract final class AppColors {
  /// Slate-900. Matches ShadSlateColorScheme's primary.
  static const slate = Color(0xFF0F172A);

  /// Map pin colours — these are data encodings, not theme colours, so they
  /// stay fixed across light and dark for legibility over map tiles.
  static const pin = Color(0xFF1A6B3C);
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
        colorScheme: const ShadSlateColorScheme.light(),
      );

  /// Dark mode was missing entirely before; shadcn ships the matching scheme.
  static ShadThemeData dark() => ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadSlateColorScheme.dark(),
      );

  /// Keeps the Material widgets (AppBar, SnackBar, dialogs) on the same slate
  /// palette as the shadcn ones.
  static ThemeData materialFrom(BuildContext context, ThemeData base) {
    final shad = ShadTheme.of(context).colorScheme;
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.slate,
        brightness: base.brightness,
      ).copyWith(surface: shad.background),
      scaffoldBackgroundColor: shad.background,
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
    );
  }
}
