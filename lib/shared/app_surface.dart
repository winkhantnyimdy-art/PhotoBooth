import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// A rounded, softly elevated surface — the app's single card primitive.
///
/// Selection is expressed as a pink border plus a pink glow, and the transition
/// is animated through [AppMotion] so a screen's chosen state reads clearly
/// without any screen having to hand-roll a border or shadow.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.all(S.md),
    this.margin,
    this.color,
    this.borderRadius,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Draws the selected treatment: accent border and accent glow.
  final bool selected;

  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Duration duration = AppMotion.of(context, AppMotion.fast);
    final BorderRadius radius = borderRadius ?? R.all(R.lg);

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      selected: selected,
      child: AnimatedContainer(
        duration: duration,
        curve: AppMotion.curve,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : (color ?? AppColors.surface),
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.line,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? AppShadows.selected : AppShadows.card,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: onTap, borderRadius: radius, child: child),
        ),
      ),
    );
  }
}

/// Small uppercase eyebrow that introduces a group of controls.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(), style: AppText.overline);
  }
}

/// A softly tinted container used to group related content inside a page.
class SoftPanel extends StatelessWidget {
  const SoftPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(S.md),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceMuted,
        borderRadius: R.all(R.md),
      ),
      child: child,
    );
  }
}
