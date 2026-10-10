import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/art/bubble_logo.dart';
import '../../core/art/checkerboard.dart';
import '../../core/art/frame_decorations.dart';
import '../../core/art/retro_sticker.dart';
import '../../core/theme/app_colors.dart';
import '../decorate/decoration_model.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pressable.dart';
import '../decorate/decorate_screen.dart';
import '../home/layout_geometry.dart';
import '../home/layout_model.dart';

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
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: S.lg),
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: S.md),
                    _StripPreview(
                      layout: layout,
                      photos: photos,
                    ),
                    const SizedBox(height: S.lg),
                    _ThumbnailRow(
                      photos: photos,
                      selectedIndex: 0,
                    ),
                    const SizedBox(height: S.lg),
                  ],
                ),
              ),
            ),
            _buildActions(context),
            const CheckerboardPattern(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
      child: Row(
        children: <Widget>[
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: Text('Review', style: AppText.title),
            ),
          ),
          _CircleButton(
            icon: Icons.delete_outline_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(S.lg, S.md, S.lg, S.md),
      decoration: const BoxDecoration(
        color: AppColors.background,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: PressableScale(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.replay_rounded, size: 20),
                label: const Text('Retake'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.popNavy, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
                ),
              ),
            ),
          ),
          const SizedBox(width: S.md),
          Expanded(
            child: PressableScale(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DecorateScreen(
                        layout: layout,
                        photos: photos,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: const Text('Next'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.hotPink,
                  shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StripPreview extends StatelessWidget {
  const _StripPreview({
    required this.layout,
    required this.photos,
  });

  final PhotoLayout layout;
  final List<XFile> photos;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: -8,
          top: -8,
          child: RetroSticker(type: StickerType.cherry, size: 36),
        ),
        Positioned(
          right: -4,
          top: 12,
          child: RetroSticker(type: StickerType.sparkle, size: 20),
        ),
        Positioned(
          right: -12,
          bottom: 40,
          child: RetroSticker(type: StickerType.heart, size: 24),
        ),
        Positioned(
          left: -12,
          bottom: 20,
          child: RetroSticker(type: StickerType.star, size: 22),
        ),
        Positioned(
          right: 20,
          bottom: -8,
          child: RetroSticker(type: StickerType.smiley, size: 28),
        ),
        Positioned(
          left: 16,
          bottom: -4,
          child: RetroSticker(type: StickerType.bear, size: 32),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.lifted,
          ),
          child: AspectRatio(
            aspectRatio: PhotoStripGeometry.aspectRatio(layout),
            child: CustomPaint(
              foregroundPainter: _PolkaDotFramePainter(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _PhotoGrid(
                  layout: layout,
                  photos: photos,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: Center(
            child: SizedBox(
              width: 120,
              child: PhotoBoothBubbleLogo(width: 120),
            ),
          ),
        ),
      ],
    );
  }
}

class _PolkaDotFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    FrameDecorations.paintPolkaDotFrame(
      canvas,
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderWidth: 10,
      dotSpacing: 18,
      dotRadius: 3.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.layout,
    required this.photos,
  });

  final PhotoLayout layout;
  final List<XFile> photos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;
        final double gutter = 6.0;

        final double cellWidth = layout.cols > 1
            ? (maxWidth - gutter * (layout.cols - 1)) / layout.cols
            : maxWidth;
        final double cellHeight = layout.rows > 1
            ? (maxHeight - gutter * (layout.rows - 1)) / layout.rows
            : maxHeight;

        return Wrap(
          spacing: gutter,
          runSpacing: gutter,
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          children: <Widget>[
            for (int i = 0; i < photos.length; i++)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: cellWidth,
                  height: cellHeight,
                  child: Image.file(
                    File(photos[i].path),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThumbnailRow extends StatelessWidget {
  const _ThumbnailRow({
    required this.photos,
    required this.selectedIndex,
  });

  final List<XFile> photos;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < photos.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.fast),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: i == selectedIndex
                      ? AppColors.hotPink
                      : AppColors.line,
                  width: i == selectedIndex ? 3 : 1.5,
                ),
                boxShadow: i == selectedIndex
                    ? <BoxShadow>[
                        BoxShadow(
                          color: AppColors.hotPink.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.file(
                  File(photos[i].path),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Material(
      color: enabled ? AppColors.surface : AppColors.surfaceMuted,
      shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? AppColors.popNavy : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
