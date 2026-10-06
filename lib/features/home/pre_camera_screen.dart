import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'layout_model.dart';
import 'layout_preview.dart';

/// Lightweight pre-camera screen showing the selected layout.
class PreCameraScreen extends StatelessWidget {
  const PreCameraScreen({super.key, required this.layout});

  final PhotoLayout layout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ready to shoot'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(S.lg),
          child: Column(
            children: [
              const Text(
                'Your layout',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: S.md),
              LayoutPreview(layout: layout, selected: true),
              const SizedBox(height: S.xl),
              const Text(
                'Tap the shutter when ready',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
