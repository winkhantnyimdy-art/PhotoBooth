import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'layout_model.dart';

/// Flutter-drawn preview of a [PhotoLayout] inside a selectable card.
class LayoutPreview extends StatelessWidget {
  const LayoutPreview({
    super.key,
    required this.layout,
    this.selected = false,
    this.onTap,
  });

  final PhotoLayout layout;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label:
            '${layout.label} layout${layout.badge != null ? ', ${layout.badge}' : ''}',
        child: Container(
          padding: const EdgeInsets.all(S.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: R.all(R.md),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GridPreview(layout: layout),
              const SizedBox(height: S.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    layout.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.accentDeep
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (layout.badge != null) ...[
                    const SizedBox(width: S.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: S.xs,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: R.all(R.xs),
                      ),
                      child: Text(
                        layout.badge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws a miniature grid representing the layout using Flutter shapes.
class _GridPreview extends StatelessWidget {
  const _GridPreview({required this.layout});

  final PhotoLayout layout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: R.all(R.sm),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double cellW = constraints.maxWidth / layout.cols;
          final double cellH = constraints.maxHeight / layout.rows;
          return CustomPaint(
            painter: _GridPainter(
              cols: layout.cols,
              rows: layout.rows,
              cellW: cellW,
              cellH: cellH,
            ),
          );
        },
      ),
    );
  }
}

/// Paints a grid of rounded rectangles to represent the layout.
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.cols,
    required this.rows,
    required this.cellW,
    required this.cellH,
  });

  final int cols;
  final int rows;
  final double cellW;
  final double cellH;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(c * cellW + 1, r * cellH + 1, cellW - 2, cellH - 2),
          const Radius.circular(4),
        );
        canvas.drawRRect(rect, paint);
        canvas.drawRRect(rect, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.cols != cols ||
      old.rows != rows ||
      old.cellW != cellW ||
      old.cellH != cellH;
}
