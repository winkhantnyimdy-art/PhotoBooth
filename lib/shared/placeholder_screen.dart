import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';

/// A shared, dependency-free placeholder screen used by feature stubs that
/// are scaffolded but not yet implemented.
///
/// It deliberately stays visually quiet: no chrome beyond a title and a
/// status line, so a stub can never be mistaken for a finished screen.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.hint,
    this.icon = Icons.construction,
    this.onGetStarted,
  });

  /// Feature name shown large in the center.
  final String title;

  /// One-line note describing what will appear here later.
  final String hint;

  /// Icon drawn above the title.
  final IconData icon;

  /// Optional primary action. Leave null for a pure placeholder.
  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(S.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: R.all(R.lg),
                ),
                child: Icon(icon, size: 44, color: AppColors.textMuted),
              ),
              const SizedBox(height: S.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: S.sm),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textMuted, height: 1.5),
              ),
              if (onGetStarted != null) ...[
                const SizedBox(height: S.lg),
                FilledButton(
                  onPressed: onGetStarted,
                  child: const Text('Get started'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
