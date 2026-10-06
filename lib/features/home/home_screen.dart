import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

/// The initial Home screen: branding only.
///
/// This is intentionally the app shell, not the final interface. The layout
/// picker, capture flow, and everything else arrive in later checkpoints.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(S.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BrandMark(),
              const SizedBox(height: S.xl),
              const Text(
                AppTheme.brand,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: S.sm),
              const Text(
                'Photo booth, on your phone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: S.xxl),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: S.md,
                  vertical: S.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: R.pillRadius,
                ),
                child: const Text(
                  'Layout, capture, and decoration are coming next.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The brand mark: a rounded tile holding a camera glyph.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: R.all(R.xl),
      ),
      child: const Icon(
        Icons.photo_camera_rounded,
        size: 52,
        color: AppColors.onAccent,
      ),
    );
  }
}
