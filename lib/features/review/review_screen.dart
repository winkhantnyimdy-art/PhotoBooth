import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../decorate/decorate_screen.dart';
import '../home/layout_model.dart';

/// Functional review screen for a completed PhotoBooth session.
///
/// Shows the captured photos in a booth-style grid matching the
/// selected [layout]. Includes Retake and Continue actions.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({
    super.key,
    required this.layout,
    required this.photos,
    this.aspectRatio,
  });

  final PhotoLayout layout;
  final List<XFile> photos;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Looking good!'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(S.md),
          child: Column(
            children: [
              _layoutBadge(),
              const SizedBox(height: S.sm),
              Text(
                '${photos.length} shot${photos.length == 1 ? '' : 's'} — ${layout.label}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: S.md),
              Expanded(child: _photoGrid()),
              const SizedBox(height: S.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: S.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                DecorateScreen(layout: layout, photos: photos),
                          ),
                        );
                      },
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _layoutBadge() => Align(
    alignment: Alignment.topRight,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xs),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: R.all(R.sm),
      ),
      child: Text(
        layout.label,
        style: const TextStyle(
          color: AppColors.onAccent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _photoGrid() {
    final cols = layout.cols;
    final rows = layout.rows;
    final items = photos.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight - S.xl;
        final cellHeight = availableHeight / rows;
        final cellWidth = cellHeight * (aspectRatio ?? 0.56);
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: S.sm,
            crossAxisSpacing: S.sm,
            childAspectRatio: cellWidth / cellHeight,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final file = File(items[index].path);
            return ClipRRect(
              borderRadius: R.all(R.sm),
              child: Image.file(file, fit: BoxFit.cover),
            );
          },
        );
      },
    );
  }
}
