import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color;

import '../theme/app_colors.dart';
import '../../features/decorate/decoration_model.dart';

/// Retro Pop decal artwork — the recognisable identity of the reference.
///
/// Every shape is a **flat fill finished with a thick navy outline**, the
/// "sticker" treatment used throughout Concept C (hearts, stars, smileys,
/// cherries, sparkles and speech bubbles all sit on the same white paper with
/// a bold `#2A4B9B` contour).
///
/// This module deliberately draws on a plain `dart:ui` [Canvas] so that the
/// exact same code paints:
///
/// * the live Decorate preview (via a `CustomPainter`), and
/// * the exported PNG (via `PhotoStripRenderer`).
///
/// That is what guarantees the on-screen preview and the saved strip show
/// identical artwork — previously they diverged, with Material icons on screen
/// and unrelated custom paths in the export.
abstract final class RetroArtwork {
  /// Stroke width as a fraction of the sticker size.
  static const double outlineRatio = 0.11;

  /// Paints one sticker centred on [center] with an overall height of [size].
  static void paintSticker(
    ui.Canvas canvas,
    StickerType type,
    ui.Offset center,
    double size,
  ) {
    final double stroke = size * outlineRatio;
    switch (type) {
      case StickerType.heart:
        _heart(canvas, center, size, AppColors.popPink, stroke);
      case StickerType.star:
        _star(canvas, center, size * 0.5, AppColors.popYellow, stroke);
      case StickerType.sparkle:
        _sparkle(canvas, center, size * 0.5, AppColors.popBlue, stroke);
      case StickerType.flower:
        _flower(canvas, center, size * 0.5, stroke);
      case StickerType.ribbon:
        _bow(canvas, center, size * 0.5, AppColors.popPink, stroke);
      case StickerType.smile:
        _smiley(canvas, center, size * 0.5, AppColors.popYellow, stroke);
      case StickerType.speechBubble:
        _speechBubble(canvas, center, size * 0.5, AppColors.surface, stroke);
      case StickerType.cuteSymbol:
        _cherries(canvas, center, size * 0.5, stroke);
    }
  }

  // ---------------------------------------------------------------------------
  // Shared path builders (also used for the frame decorations)
  // ---------------------------------------------------------------------------

  /// A five-pointed star path centred on [center] with outer [radius].
  static ui.Path starPath(ui.Offset center, double radius) {
    final ui.Path path = ui.Path();
    for (int i = 0; i < 10; i++) {
      final double r = i.isEven ? radius : radius * 0.45;
      final double angle = (i * math.pi / 5) - (math.pi / 2);
      final ui.Offset p = ui.Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  /// A four-point sparkle (concave star) centred on [center].
  static ui.Path sparklePath(ui.Offset center, double radius) {
    final ui.Path path = ui.Path();
    final List<ui.Offset> tips = <ui.Offset>[
      ui.Offset(center.dx, center.dy - radius),
      ui.Offset(center.dx + radius, center.dy),
      ui.Offset(center.dx, center.dy + radius),
      ui.Offset(center.dx - radius, center.dy),
    ];
    path.moveTo(tips[0].dx, tips[0].dy);
    for (int i = 0; i < 4; i++) {
      final ui.Offset a = tips[i];
      final ui.Offset b = tips[(i + 1) % 4];
      path.quadraticBezierTo(
        (a.dx + b.dx) / 2,
        (a.dy + b.dy) / 2,
        b.dx,
        b.dy,
      );
    }
    // Pinch the corners in so it reads as a sparkle, not a blob.
    path.close();
    return path;
  }

  // ---------------------------------------------------------------------------
  // Individual decals
  // ---------------------------------------------------------------------------

  static void _heart(
    ui.Canvas canvas,
    ui.Offset c,
    double size,
    Color fill,
    double stroke,
  ) {
    final ui.Path p = ui.Path()
      ..moveTo(c.dx, c.dy + size * 0.38)
      ..cubicTo(
        c.dx - size * 0.62,
        c.dy - size * 0.08,
        c.dx - size * 0.30,
        c.dy - size * 0.46,
        c.dx,
        c.dy - size * 0.16,
      )
      ..cubicTo(
        c.dx + size * 0.30,
        c.dy - size * 0.46,
        c.dx + size * 0.62,
        c.dy - size * 0.08,
        c.dx,
        c.dy + size * 0.38,
      )
      ..close();
    _decal(canvas, p, fill, stroke);
  }

  static void _star(
    ui.Canvas canvas,
    ui.Offset c,
    double radius,
    Color fill,
    double stroke,
  ) {
    _decal(canvas, starPath(c, radius), fill, stroke);
  }

  static void _sparkle(
    ui.Canvas canvas,
    ui.Offset c,
    double radius,
    Color fill,
    double stroke,
  ) {
    _decal(canvas, sparklePath(c, radius), fill, stroke);
  }

  static void _flower(ui.Canvas canvas, ui.Offset c, double radius, double stroke) {
    final ui.Paint petalFill = _fill(AppColors.popPink);
    final ui.Paint petalEdge = _edge(stroke);
    for (int i = 0; i < 5; i++) {
      final double angle = (i * math.pi * 2 / 5) - (math.pi / 2);
      canvas.drawCircle(
        ui.Offset(
          c.dx + radius * 0.62 * math.cos(angle),
          c.dy + radius * 0.62 * math.sin(angle),
        ),
        radius * 0.46,
        petalFill,
      );
      canvas.drawCircle(
        ui.Offset(
          c.dx + radius * 0.62 * math.cos(angle),
          c.dy + radius * 0.62 * math.sin(angle),
        ),
        radius * 0.46,
        petalEdge,
      );
    }
    canvas.drawCircle(c, radius * 0.40, _fill(AppColors.popYellow));
    canvas.drawCircle(c, radius * 0.40, _edge(stroke));
  }

  static void _bow(
    ui.Canvas canvas,
    ui.Offset c,
    double radius,
    Color fill,
    double stroke,
  ) {
    final ui.Path left = ui.Path()
      ..moveTo(c.dx, c.dy)
      ..quadraticBezierTo(
        c.dx - radius * 1.15,
        c.dy - radius * 0.95,
        c.dx - radius * 0.95,
        c.dy + radius * 0.30,
      )
      ..quadraticBezierTo(
        c.dx - radius * 0.45,
        c.dy + radius * 0.40,
        c.dx,
        c.dy,
      )
      ..close();
    final ui.Path right = ui.Path()
      ..moveTo(c.dx, c.dy)
      ..quadraticBezierTo(
        c.dx + radius * 1.15,
        c.dy - radius * 0.95,
        c.dx + radius * 0.95,
        c.dy + radius * 0.30,
      )
      ..quadraticBezierTo(
        c.dx + radius * 0.45,
        c.dy + radius * 0.40,
        c.dx,
        c.dy,
      )
      ..close();
    _decal(canvas, left, fill, stroke);
    _decal(canvas, right, fill, stroke);
    canvas.drawCircle(c, radius * 0.30, _fill(AppColors.accent));
    canvas.drawCircle(c, radius * 0.30, _edge(stroke));
  }

  static void _smiley(
    ui.Canvas canvas,
    ui.Offset c,
    double radius,
    Color fill,
    double stroke,
  ) {
    canvas.drawCircle(c, radius, _fill(fill));
    canvas.drawCircle(c, radius, _edge(stroke));

    final ui.Paint ink = _fill(AppColors.popInk);
    canvas.drawCircle(
      ui.Offset(c.dx - radius * 0.34, c.dy - radius * 0.20),
      radius * 0.11,
      ink,
    );
    canvas.drawCircle(
      ui.Offset(c.dx + radius * 0.34, c.dy - radius * 0.20),
      radius * 0.11,
      ink,
    );
    canvas.drawArc(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx, c.dy + radius * 0.16),
        width: radius * 1.05,
        height: radius * 0.80,
      ),
      0.30,
      2.54,
      false,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = stroke * 0.9
        ..strokeCap = ui.StrokeCap.round
        ..color = AppColors.popInk,
    );
  }

  static void _speechBubble(
    ui.Canvas canvas,
    ui.Offset c,
    double radius,
    Color fill,
    double stroke,
  ) {
    final ui.RRect body = ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx, c.dy - radius * 0.22),
        width: radius * 1.9,
        height: radius * 1.25,
      ),
      ui.Radius.circular(radius * 0.42),
    );
    canvas.drawRRect(body, _fill(fill));
    canvas.drawRRect(body, _edge(stroke));
    final ui.Path tail = ui.Path()
      ..moveTo(c.dx - radius * 0.34, c.dy + radius * 0.24)
      ..lineTo(c.dx - radius * 0.62, c.dy + radius * 1.05)
      ..lineTo(c.dx + radius * 0.02, c.dy + radius * 0.34)
      ..close();
    canvas.drawPath(tail, _fill(fill));
    canvas.drawPath(tail, _edge(stroke));
  }

  static void _cherries(ui.Canvas canvas, ui.Offset c, double radius, double stroke) {
    // Stems
    final ui.Paint stem = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = stroke * 1.1
      ..strokeCap = ui.StrokeCap.round
      ..color = AppColors.popNavy;
    final ui.Path s1 = ui.Path()
      ..moveTo(c.dx - radius * 0.45, c.dy + radius * 0.30)
      ..quadraticBezierTo(
        c.dx - radius * 0.10,
        c.dy - radius * 0.75,
        c.dx + radius * 0.30,
        c.dy - radius * 0.95,
      );
    final ui.Path s2 = ui.Path()
      ..moveTo(c.dx + radius * 0.45, c.dy + radius * 0.30)
      ..quadraticBezierTo(
        c.dx + radius * 0.25,
        c.dy - radius * 0.70,
        c.dx + radius * 0.30,
        c.dy - radius * 0.95,
      );
    canvas.drawPath(s1, stem);
    canvas.drawPath(s2, stem);
    // Leaf
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx + radius * 0.62, c.dy - radius * 0.92),
        width: radius * 0.62,
        height: radius * 0.30,
      ),
      _fill(const Color(0xFF6BBF59)),
    );
    // Fruit
    for (final double dx in <double>[-0.45, 0.45]) {
      final ui.Offset p = ui.Offset(c.dx + radius * dx, c.dy + radius * 0.52);
      canvas.drawCircle(p, radius * 0.42, _fill(AppColors.accent));
      canvas.drawCircle(p, radius * 0.42, _edge(stroke));
    }
  }

  // ---------------------------------------------------------------------------
  // Paint helpers
  // ---------------------------------------------------------------------------

  /// Flat fill with no shading — the decal look.
  static ui.Paint _fill(Color color) => ui.Paint()
    ..isAntiAlias = true
    ..style = ui.PaintingStyle.fill
    ..color = color;

  /// The thick navy contour that every decal is finished with.
  static ui.Paint _edge(double width) => ui.Paint()
    ..isAntiAlias = true
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = ui.StrokeJoin.round
    ..color = AppColors.popNavy;

  static void _decal(
    ui.Canvas canvas,
    ui.Path path,
    Color fill,
    double stroke,
  ) {
    canvas.drawPath(path, _fill(fill));
    canvas.drawPath(path, _edge(stroke));
  }
}
