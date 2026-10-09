import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pressable.dart';
import '../decorate/decorate_screen.dart';
import '../home/layout_model.dart';

/// Review screen for a completed PhotoBooth session.
///
/// Presents the captured photos in a keepsake card that mirrors the chosen
/// layout, then offers Retake or Continue to decoration. Photo order and
/// session data are untouched — this screen only presents them.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({
    super.key,
    required this.layout,
    required this.photos,
    this.aspectRatio,
  });

  final PhotoLayout layout;
  final List<XFile> photos;

  /// Preview aspect ratio reported by the camera, if available. Accepted for
  /// session continuity; the grid uses the shared square-cell geometry.
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Review'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxHeight < 620;
            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: S.lg),
                  child: Column(
                    children: <Widget>[
                      SizedBox(height: compact ? S.sm : S.md),
                      Text(
                        'Looking good!',
                        textAlign: TextAlign.center,
                        style: AppText.display,
                      ),
                      const SizedBox(height: S.xs),
                      Text(
                        'All ${photos.length} photos are ready for a frame.',
                        textAlign: TextAlign.center,
                        style: AppText.body,
                      ),
                      SizedBox(height: compact ? S.sm : S.md),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: S.lg),
                    child: _Keepsake(layout: layout, photos: photos),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    S.lg,
                    S.md,
                    S.lg,
                    S.md + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: _Actions(layout: layout, photos: photos),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// White keepsake card holding the session photos in their chosen grid.
class _Keepsake extends StatelessWidget {
  const _Keepsake({required this.layout, required this.photos});

  final PhotoLayout layout;
  final List<XFile> photos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: R.all(R.lg),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.lifted,
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: _PhotoGrid(layout: layout, photos: photos),
          ),
          const SizedBox(height: S.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: AppColors.accentInk,
              ),
              const SizedBox(width: 6),
              // Flexible so long copy truncates instead of overflowing on
              // narrow screens.
              Flexible(
                child: Text(
                  'Next: add a frame, style and stickers',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Arranges the captured photos in row-major order using the same square cells
/// as the exported strip, so nothing is reordered or reshaped on the way to
/// the final PNG.
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.layout, required this.photos});

  final PhotoLayout layout;
  final List<XFile> photos;

  static const double _gap = S.sm;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cell = _cellSize(constraints, layout);
        if (cell <= 0) return const SizedBox.shrink();

        return Center(
          child: Wrap(
            spacing: _gap,
            runSpacing: _gap,
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            children: <Widget>[
              for (int i = 0; i < photos.length; i++)
                _PhotoTile(
                  photo: photos[i],
                  size: cell,
                  number: i + 1,
                  total: photos.length,
                ),
            ],
          ),
        );
      },
    );
  }

  /// Largest square cell that fits the layout's grid in the available box.
  static double _cellSize(BoxConstraints constraints, PhotoLayout layout) {
    final double byWidth =
        (constraints.maxWidth - (_gap * (layout.cols - 1))) / layout.cols;
    final double byHeight =
        (constraints.maxHeight - (_gap * (layout.rows - 1))) / layout.rows;
    final double cell = byWidth < byHeight ? byWidth : byHeight;
    return cell.isFinite && cell > 0 ? cell : 0;
  }
}

/// One captured photo inside a soft frame.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.size,
    required this.number,
    required this.total,
  });

  final XFile photo;
  final double size;
  final int number;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Photo $number of $total',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: R.all(R.sm),
          border: Border.all(color: AppColors.line),
        ),
        child: ClipRRect(
          borderRadius: R.all(R.xs),
          child: Image.file(File(photo.path), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

/// Continue (primary) and Retake (secondary) actions.
class _Actions extends StatelessWidget {
  const _Actions({required this.layout, required this.photos});

  final PhotoLayout layout;
  final List<XFile> photos;

  void _continue(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DecorateScreen(layout: layout, photos: photos),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PressableScale(
          child: FilledButton.icon(
            onPressed: () => _continue(context),
            icon: const Icon(Icons.brush_rounded, size: 20),
            label: const Text('Continue to Decorate'),
          ),
        ),
        const SizedBox(height: S.sm + S.xs),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.replay_rounded, size: 20),
          label: const Text('Retake'),
        ),
      ],
    );
  }
}
