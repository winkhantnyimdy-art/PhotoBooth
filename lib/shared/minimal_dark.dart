import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// Shared Minimal Dark page scaffold.
///
/// Use this as the single wrapper for dark screens so padding, background,
/// and safe-area behaviour stay consistent.
class MinimalDarkScaffold extends StatelessWidget {
  const MinimalDarkScaffold({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: S.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Minimal dark icon button with a consistent 48dp touch target.
class MinimalIconButton extends StatelessWidget {
  const MinimalIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 22,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip ?? '',
        child: SizedBox(
          width: S.touchTarget,
          height: S.touchTarget,
          child: Material(
            color: enabled ? AppColors.darkElevated : Colors.transparent,
            shape: const CircleBorder(side: BorderSide(color: AppColors.darkLine)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Icon(
                icon,
                size: size,
                color: enabled ? AppColors.onDark : AppColors.darkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary white action button.
class MinimalPrimaryButton extends StatelessWidget {
  const MinimalPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon == null
            ? const SizedBox.shrink()
            : Icon(icon, color: AppColors.darkBackground),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.onDark,
          foregroundColor: AppColors.darkBackground,
          disabledBackgroundColor: AppColors.darkElevated,
          disabledForegroundColor: AppColors.darkMuted,
          shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
          textStyle: AppText.button,
        ),
      ),
    );
  }
}

/// Secondary outlined button for less important actions.
class MinimalSecondaryButton extends StatelessWidget {
  const MinimalSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null
            ? const SizedBox.shrink()
            : Icon(icon, size: 18, color: AppColors.onDark),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onDark,
          side: const BorderSide(color: AppColors.darkLine),
          backgroundColor: AppColors.darkElevated,
          shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
          textStyle: AppText.buttonSmall,
        ),
      ),
    );
  }
}

/// Rounded section heading with a secondary subtitle.
class MinimalSectionHeading extends StatelessWidget {
  const MinimalSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: AppText.heading.copyWith(color: AppColors.onDark)),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(subtitle!, style: AppText.caption.copyWith(color: AppColors.darkMuted)),
        ],
      ],
    );
  }
}