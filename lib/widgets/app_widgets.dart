import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The green rounded-bottom hero header, previously copy-pasted into the
/// login, signup and admin screens with drifting details.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onBack,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final p = context.shad;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.xxl,
            Insets.xl,
            Insets.xxl,
            Insets.xxl,
          ),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: Insets.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onBack != null || actions.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (onBack != null)
                        GlassIconButton(
                          icon: Icons.arrow_back,
                          onPressed: onBack,
                          tooltip: 'Back',
                        )
                      else
                        const SizedBox.shrink(),
                      Row(mainAxisSize: MainAxisSize.min, children: actions),
                    ],
                  ),
                if (icon != null) ...[
                  const SizedBox(height: Insets.xl),
                  Icon(icon, color: p.primaryForeground, size: 40),
                ],
                const SizedBox(height: Insets.md),
                Text(
                  title,
                  style: context.texts.headlineMedium?.copyWith(
                    color: p.primaryForeground,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: Insets.xs + 2),
                  Text(
                    subtitle!,
                    style: context.texts.bodyLarge?.copyWith(
                      color: p.primaryForeground.withValues(alpha: 0.78),
                    ),
                  ),
                ],
                if (bottom != null) ...[
                  const SizedBox(height: Insets.xl),
                  bottom!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Translucent square icon button used on the brand-coloured headers.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = context.shad;
    final button = Material(
      color: p.primaryForeground.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.all(Insets.sm),
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(p.primaryForeground),
                  ),
                )
              : Icon(icon, color: p.primaryForeground, size: 18),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// The brand pill with the water-drop mark.
class BrandPill extends StatelessWidget {
  const BrandPill({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.shad;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? Insets.md : 14,
        vertical: compact ? 6 : 9,
      ),
      decoration: BoxDecoration(
        color: p.primaryForeground.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: p.primaryForeground.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.water_drop, color: p.primaryForeground, size: compact ? 14 : 16),
          const SizedBox(width: 7),
          Text(
            'SanBidet Cebu',
            style: TextStyle(
              color: p.primaryForeground,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled form field. Replaces three near-identical private `_field` /
/// `_buildField` / `_inputDecoration` helpers.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.prefixText,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? prefixText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.texts.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    tooltip: obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                      color: context.shad.mutedForeground,
                      size: 20,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Inline error banner shared by the auth screens.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: error, size: 16),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: context.texts.bodyMedium?.copyWith(color: error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty / error placeholder, replacing four ad-hoc column-of-icon-and-text
/// blocks.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.shad;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: p.mutedForeground.withValues(alpha: 0.6)),
            const SizedBox(height: Insets.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.texts.titleMedium?.copyWith(
                color: p.mutedForeground,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: Insets.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.texts.bodyMedium,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Insets.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Caps body width on wide screens so the phone-first layouts stay readable
/// in a desktop browser.
class CenteredBody extends StatelessWidget {
  const CenteredBody({
    super.key,
    required this.child,
    this.maxWidth = Insets.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Read-only star row.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.rating,
    this.size = 18,
    this.color,
  });

  final double rating;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.amber.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = rating >= i + 1;
        final half = !filled && rating > i;
        return Icon(
          half
              ? Icons.star_half_rounded
              : filled
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
          color: c,
          size: size,
        );
      }),
    );
  }
}

/// Tappable 1–5 star selector used by the rating sheet.
class StarSelector extends StatelessWidget {
  const StarSelector({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: context.texts.bodyMedium),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final selected = i < value;
            return IconButton(
              onPressed: () => onChanged(i + 1),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              tooltip: '${i + 1} of 5',
              icon: Icon(
                selected ? Icons.star_rounded : Icons.star_outline_rounded,
                color: selected
                    ? Colors.amber.shade500
                    : context.shad.mutedForeground,
                size: 26,
              ),
            );
          }),
        ),
      ],
    );
  }
}
