import 'dart:math' as math;

import 'dart:ui' as ui;

import '../theme/app_colors.dart';

abstract final class FrameDecorations {
  static void paintPolkaDotFrame(
    ui.Canvas canvas,
    ui.Rect rect, {
    double borderWidth = 12,
    double dotSpacing = 20,
    double dotRadius = 4,
  }) {
    final ui.Paint borderPaint = ui.Paint()
      ..color = AppColors.popPink
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = ui.StrokeCap.round;

    final ui.Paint dotPaint = ui.Paint()
      ..color = AppColors.surface
      ..style = ui.PaintingStyle.fill;

    final ui.RRect rrect = ui.RRect.fromRectAndRadius(
      rect,
      const ui.Radius.circular(16),
    );
    canvas.drawRRect(rrect, borderPaint);

    final ui.RRect inner = ui.RRect.fromRectAndRadius(
      rect.deflate(borderWidth / 2),
      const ui.Radius.circular(10),
    );

    for (double y = inner.top + dotSpacing / 2; y < inner.bottom; y += dotSpacing) {
      for (double x = inner.left + dotSpacing / 2; x < inner.right; x += dotSpacing) {
        if (inner.contains(ui.Offset(x, y))) {
          canvas.drawCircle(ui.Offset(x, y), dotRadius, dotPaint);
        }
      }
    }
  }

  static void paintGinghamFrame(
    ui.Canvas canvas,
    ui.Rect rect, {
    double borderWidth = 14,
    double cellSize = 10,
  }) {
    final ui.Paint pinkPaint = ui.Paint()
      ..color = AppColors.popPink
      ..style = ui.PaintingStyle.fill;

    final ui.Paint whitePaint = ui.Paint()
      ..color = AppColors.surface
      ..style = ui.PaintingStyle.fill;

    final ui.RRect outer = ui.RRect.fromRectAndRadius(
      rect,
      const ui.Radius.circular(16),
    );
    canvas.drawRRect(outer, pinkPaint);

    final ui.RRect inner = ui.RRect.fromRectAndRadius(
      rect.deflate(borderWidth),
      const ui.Radius.circular(8),
    );

    for (double y = inner.top; y < inner.bottom; y += cellSize) {
      for (double x = inner.left; x < inner.right; x += cellSize) {
        final bool isPink =
            ((x - inner.left) / cellSize).floor().isEven ==
                ((y - inner.top) / cellSize).floor().isEven;
        final ui.Rect cell = ui.Rect.fromLTWH(
          x,
          y,
          math.min(cellSize, inner.right - x),
          math.min(cellSize, inner.bottom - y),
        );
        canvas.drawRect(cell, isPink ? pinkPaint : whitePaint);
      }
    }
  }
}
