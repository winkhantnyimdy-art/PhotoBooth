import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import 'layout_model.dart';
import 'layout_preview.dart';
import 'pre_camera_screen.dart';

/// The Home screen: layout selection and start flow.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PhotoLayout _selected = PhotoLayout.cut4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.md),
          child: Column(
            children: [
              const SizedBox(height: S.lg),
              const _BrandMark(),
              const SizedBox(height: S.lg),
              const Text(
                AppTheme.brand,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: S.xs),
              const Text(
                'Choose your layout',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: S.lg),
              Expanded(
                child: ListView(
                  children: [
                    LayoutPreview(
                      layout: PhotoLayout.cut4,
                      selected: _selected == PhotoLayout.cut4,
                      onTap: () => setState(() => _selected = PhotoLayout.cut4),
                    ),
                    const SizedBox(height: S.md),
                    LayoutPreview(
                      layout: PhotoLayout.cut2,
                      selected: _selected == PhotoLayout.cut2,
                      onTap: () => setState(() => _selected = PhotoLayout.cut2),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + S.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PreCameraScreen(layout: _selected),
                        ),
                      );
                    },
                    child: const Text('Start Photo Booth'),
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

/// The brand mark tile.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: R.all(R.xl),
      ),
      child: const Icon(
        Icons.photo_camera_rounded,
        size: 42,
        color: AppColors.onAccent,
      ),
    );
  }
}
