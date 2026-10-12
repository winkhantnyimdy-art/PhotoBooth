import 'dart:math' as math;

import 'dart:ui' as ui;

import '../../features/decorate/decoration_model.dart';
import '../theme/app_colors.dart';

/// Paper and border treatments drawn around a photo strip.
///
/// The same painters run on the Decorate preview and inside the PNG renderer,
/// so the frame a user picks is the frame that gets printed. All sizes are
/// derived from the target rectangle, which keeps the chrome proportional at
/// any preview scale or at full export resolution.
abstract final class FrameDecorations {
  /// Dispatches to the painter for [style], sized relative to [rect].
  static void paintFrame(ui.Canvas canvas, ui.Rect rect, FrameStyle style) {
    switch (style) {
      case FrameStyle.polkaDot:
        paintPolkaDotFrame(canvas, rect);
      case FrameStyle.filmEdge:
        paintFilmEdgeFrame(canvas, rect);
      case FrameStyle.scallop:
        paintScallopFrame(canvas, rect);
      case FrameStyle.minimal:
        paintMinimalFrame(canvas, rect);
    }
  }

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

  /// Vintage film rails down both long edges, with sprocket holes.
  static void paintFilmEdgeFrame(ui.Canvas canvas, ui.Rect rect) {
    final double rail = math.max(6, rect.width * 0.0135);
    final ui.Paint railPaint = ui.Paint()
      ..color = AppColors.popInk
      ..style = ui.PaintingStyle.fill;

    canvas.drawRect(
      ui.Rect.fromLTWH(rect.left, rect.top, rail, rect.height),
      railPaint,
    );
    canvas.drawRect(
      ui.Rect.fromLTWH(rect.right - rail, rect.top, rail, rect.height),
      railPaint,
    );

    final ui.Paint holePaint = ui.Paint()
      ..color = AppColors.surface
      ..style = ui.PaintingStyle.fill;
    final double hole = rail * 0.5;
    final double step = hole * 2.4;
    for (double y = rect.top + step; y < rect.bottom - step; y += step) {
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromCenter(
            center: ui.Offset(rect.left + rail / 2, y),
            width: hole,
            height: hole,
          ),
          ui.Radius.circular(hole * 0.25),
        ),
        holePaint,
      );
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromCenter(
            center: ui.Offset(rect.right - rail / 2, y),
            width: hole,
            height: hole,
          ),
          ui.Radius.circular(hole * 0.25),
        ),
        holePaint,
      );
    }
  }

  /// A scalloped pink border, like a doily edge.
  static void paintScallopFrame(ui.Canvas canvas, ui.Rect rect) {
    final ui.Paint pink = ui.Paint()
      ..color = AppColors.popPink
      ..style = ui.PaintingStyle.fill;
    final double band = math.max(6, rect.width * 0.014);

    // Solid band framing the strip.
    canvas.drawPath(
      ui.Path()
        ..addRRect(ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(16)))
        ..addRRect(
          ui.RRect.fromRectAndRadius(
            rect.deflate(band),
            const ui.Radius.circular(12),
          ),
        )
        ..fillType = ui.PathFillType.evenOdd,
      pink,
    );

    // Punch a row of surface-coloured circles along the band for the scallop.
    final ui.Paint cut = ui.Paint()
      ..color = AppColors.surface
      ..style = ui.PaintingStyle.fill;
    final double radius = band * 0.42;
    final double spacing = radius * 2.4;
    for (double x = rect.left + spacing; x < rect.right - spacing; x += spacing) {
      canvas.drawCircle(ui.Offset(x, rect.top + band / 2), radius, cut);
      canvas.drawCircle(ui.Offset(x, rect.bottom - band / 2), radius, cut);
    }
    for (double y = rect.top + spacing; y < rect.bottom - spacing; y += spacing) {
      canvas.drawCircle(ui.Offset(rect.left + band / 2, y), radius, cut);
      canvas.drawCircle(ui.Offset(rect.right - band / 2, y), radius, cut);
    }
  }

  /// A thin solid border in the brand pink.
  static void paintMinimalFrame(ui.Canvas canvas, ui.Rect rect) {
    final ui.Paint paint = ui.Paint()
      ..color = AppColors.popPink
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = math.max(2, rect.width * 0.006)
      ..strokeJoin = ui.StrokeJoin.round;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        rect.deflate(paint.strokeWidth / 2),
        const ui.Radius.circular(14),
      ),
      paint,
    );
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
