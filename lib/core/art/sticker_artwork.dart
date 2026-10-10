import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../features/decorate/decoration_model.dart';

abstract final class StickerArtwork {
  static const double outlineRatio = 0.08;

  static void paintSticker(
    ui.Canvas canvas,
    StickerType type,
    ui.Offset center,
    double size,
  ) {
    switch (type) {
      case StickerType.heart:
        _heart(canvas, center, size);
      case StickerType.star:
        _star(canvas, center, size);
      case StickerType.sparkle:
        _sparkle(canvas, center, size);
      case StickerType.cherry:
        _cherry(canvas, center, size);
      case StickerType.bow:
        _bow(canvas, center, size);
      case StickerType.smiley:
        _smiley(canvas, center, size);
      case StickerType.bear:
        _bear(canvas, center, size);
      case StickerType.crown:
        _crown(canvas, center, size);
      case StickerType.car:
        _car(canvas, center, size);
      case StickerType.rainbow:
        _rainbow(canvas, center, size);
      case StickerType.strawberry:
        _strawberry(canvas, center, size);
      case StickerType.cloud:
        _cloud(canvas, center, size);
      case StickerType.flower:
        _flower(canvas, center, size);
      case StickerType.love:
        _loveText(canvas, center, size);
      case StickerType.cuteText:
        _cuteText(canvas, center, size);
      case StickerType.hiBubble:
        _hiBubble(canvas, center, size);
      case StickerType.bunny:
        _bunny(canvas, center, size);
    }
  }

  static void _heart(ui.Canvas canvas, ui.Offset c, double size) {
    final ui.Path path = ui.Path()
      ..moveTo(c.dx, c.dy + size * 0.35)
      ..cubicTo(
        c.dx - size * 0.55,
        c.dy - size * 0.05,
        c.dx - size * 0.30,
        c.dy - size * 0.45,
        c.dx,
        c.dy - size * 0.15,
      )
      ..cubicTo(
        c.dx + size * 0.30,
        c.dy - size * 0.45,
        c.dx + size * 0.55,
        c.dy - size * 0.05,
        c.dx,
        c.dy + size * 0.35,
      )
      ..close();
    _decal(canvas, path, AppColors.popPink, size * outlineRatio);
  }

  static void _star(ui.Canvas canvas, ui.Offset c, double size) {
    final ui.Path path = ui.Path();
    for (int i = 0; i < 10; i++) {
      final double r = i.isEven ? size * 0.5 : size * 0.225;
      final double angle = (i * math.pi / 5) - (math.pi / 2);
      final ui.Offset p = ui.Offset(
        c.dx + r * math.cos(angle),
        c.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    _decal(canvas, path, AppColors.popYellow, size * outlineRatio);
  }

  static void _sparkle(ui.Canvas canvas, ui.Offset c, double size) {
    final ui.Path path = ui.Path();
    final List<ui.Offset> tips = <ui.Offset>[
      ui.Offset(c.dx, c.dy - size * 0.5),
      ui.Offset(c.dx + size * 0.5, c.dy),
      ui.Offset(c.dx, c.dy + size * 0.5),
      ui.Offset(c.dx - size * 0.5, c.dy),
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
    path.close();
    _decal(canvas, path, AppColors.popPink, size * outlineRatio * 0.75);
  }

  static void _cherry(ui.Canvas canvas, ui.Offset c, double size) {
    final ui.Paint stemPaint = ui.Paint()
      ..color = AppColors.cherryStem
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = size * 0.06
      ..strokeCap = ui.StrokeCap.round;

    final ui.Path stem1 = ui.Path()
      ..moveTo(c.dx - size * 0.2, c.dy + size * 0.25)
      ..quadraticBezierTo(
        c.dx,
        c.dy - size * 0.35,
        c.dx + size * 0.25,
        c.dy - size * 0.4,
      );
    canvas.drawPath(stem1, stemPaint);

    final ui.Path stem2 = ui.Path()
      ..moveTo(c.dx + size * 0.2, c.dy + size * 0.25)
      ..quadraticBezierTo(
        c.dx + size * 0.1,
        c.dy - size * 0.3,
        c.dx + size * 0.25,
        c.dy - size * 0.4,
      );
    canvas.drawPath(stem2, stemPaint);

    for (final double dx in <double>[-0.2, 0.2]) {
      final ui.Offset p = ui.Offset(c.dx + size * dx, c.dy + size * 0.25);
      canvas.drawCircle(p, size * 0.22, _fill(AppColors.cherry));
      canvas.drawCircle(p, size * 0.22, _edge(size * outlineRatio * 0.75));
    }
  }

  static void _bow(ui.Canvas canvas, ui.Offset c, double size) {
    final ui.Path leftWing = ui.Path()
      ..moveTo(c.dx, c.dy)
      ..quadraticBezierTo(
        c.dx - size * 0.6,
        c.dy - size * 0.5,
        c.dx - size * 0.5,
        c.dy + size * 0.15,
      )
      ..quadraticBezierTo(
        c.dx - size * 0.2,
        c.dy + size * 0.2,
        c.dx,
        c.dy,
      )
      ..close();

    final ui.Path rightWing = ui.Path()
      ..moveTo(c.dx, c.dy)
      ..quadraticBezierTo(
        c.dx + size * 0.6,
        c.dy - size * 0.5,
        c.dx + size * 0.5,
        c.dy + size * 0.15,
      )
      ..quadraticBezierTo(
        c.dx + size * 0.2,
        c.dy + size * 0.2,
        c.dx,
        c.dy,
      )
      ..close();

    _decal(canvas, leftWing, AppColors.popPink, size * outlineRatio * 0.75);
    _decal(canvas, rightWing, AppColors.popPink, size * outlineRatio * 0.75);

    canvas.drawCircle(c, size * 0.15, _fill(AppColors.accentDeep));
    canvas.drawCircle(c, size * 0.15, _edge(size * outlineRatio * 0.5));
  }

  static void _smiley(ui.Canvas canvas, ui.Offset c, double size) {
    canvas.drawCircle(c, size * 0.5, _fill(AppColors.popYellow));
    canvas.drawCircle(c, size * 0.5, _edge(size * outlineRatio));

    final ui.Paint ink = _fill(AppColors.popInk);
    canvas.drawCircle(
      ui.Offset(c.dx - size * 0.17, c.dy - size * 0.1),
      size * 0.06,
      ink,
    );
    canvas.drawCircle(
      ui.Offset(c.dx + size * 0.17, c.dy - size * 0.1),
      size * 0.06,
      ink,
    );

    canvas.drawArc(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx, c.dy + size * 0.08),
        width: size * 0.5,
        height: size * 0.4,
      ),
      0.3,
      2.5,
      false,
      ui.Paint()
        ..color = AppColors.popInk
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = size * 0.06
        ..strokeCap = ui.StrokeCap.round,
    );
  }

  static void _bear(ui.Canvas canvas, ui.Offset c, double size) {
    canvas.drawCircle(
      ui.Offset(c.dx - size * 0.3, c.dy - size * 0.3),
      size * 0.2,
      _fill(AppColors.bearBrown),
    );
    canvas.drawCircle(
      ui.Offset(c.dx + size * 0.3, c.dy - size * 0.3),
      size * 0.2,
      _fill(AppColors.bearBrown),
    );

    canvas.drawCircle(c, size * 0.45, _fill(AppColors.bearBrown));
    canvas.drawCircle(c, size * 0.45, _edge(size * outlineRatio));

    canvas.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx, c.dy + size * 0.1),
        width: size * 0.4,
        height: size * 0.3,
      ),
      _fill(AppColors.surfaceMuted),
    );

    final ui.Paint ink = _fill(AppColors.popInk);
    canvas.drawCircle(
      ui.Offset(c.dx - size * 0.15, c.dy - size * 0.1),
      size * 0.05,
      ink,
    );
    canvas.drawCircle(
      ui.Offset(c.dx + size * 0.15, c.dy - size * 0.1),
      size * 0.05,
      ink,
    );
    canvas.drawCircle(
      ui.Offset(c.dx, c.dy + size * 0.05),
      size * 0.06,
      ink,
    );
  }

  static void _crown(ui.Canvas canvas, ui.Offset c, double size) {
    final ui.Path path = ui.Path()
      ..moveTo(c.dx - size * 0.5, c.dy + size * 0.3)
      ..lineTo(c.dx - size * 0.5, c.dy - size * 0.1)
      ..lineTo(c.dx - size * 0.25, c.dy + size * 0.05)
      ..lineTo(c.dx, c.dy - size * 0.4)
      ..lineTo(c.dx + size * 0.25, c.dy + size * 0.05)
      ..lineTo(c.dx + size * 0.5, c.dy - size * 0.1)
      ..lineTo(c.dx + size * 0.5, c.dy + size * 0.3)
      ..close();

    _decal(canvas, path, AppColors.crownGold, size * outlineRatio);

    canvas.drawCircle(
      ui.Offset(c.dx, c.dy + size * 0.15),
      size * 0.08,
      _fill(AppColors.popPink),
    );
    canvas.drawCircle(
      ui.Offset(c.dx - size * 0.25, c.dy + size * 0.15),
      size * 0.06,
      _fill(AppColors.popBlue),
    );
    canvas.drawCircle(
      ui.Offset(c.dx + size * 0.25, c.dy + size * 0.15),
      size * 0.06,
      _fill(AppColors.popBlue),
    );
  }

  static void _car(ui.Canvas canvas, ui.Offset c, double size) {
    final ui.RRect body = ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx, c.dy + size * 0.1),
        width: size * 1.2,
        height: size * 0.5,
      ),
      ui.Radius.circular(size * 0.15),
    );
    canvas.drawRRect(body, _fill(AppColors.popPink));
    canvas.drawRRect(body, _edge(size * outlineRatio * 0.75));

    final ui.RRect top = ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx, c.dy - size * 0.15),
        width: size * 0.7,
        height: size * 0.35,
      ),
      ui.Radius.circular(size * 0.12),
    );
    canvas.drawRRect(top, _fill(AppColors.popPink));
    canvas.drawRRect(top, _edge(size * outlineRatio * 0.75));

    canvas.drawCircle(
      ui.Offset(c.dx - size * 0.3, c.dy + size * 0.35),
      size * 0.12,
      _fill(AppColors.popInk),
    );
    canvas.drawCircle(
      ui.Offset(c.dx + size * 0.3, c.dy + size * 0.35),
      size * 0.12,
      _fill(AppColors.popInk),
    );
  }

  static void _rainbow(ui.Canvas canvas, ui.Offset c, double size) {
    final List<Color> colors = <Color>[
      AppColors.rainbowRed,
      AppColors.rainbowOrange,
      AppColors.rainbowYellow,
      AppColors.rainbowGreen,
      AppColors.rainbowBlue,
      AppColors.rainbowPurple,
    ];

    for (int i = 0; i < colors.length; i++) {
      final double radius = size * 0.5 - (i * size * 0.08);
      canvas.drawArc(
        ui.Rect.fromCenter(
          center: ui.Offset(c.dx, c.dy + size * 0.3),
          width: radius * 2,
          height: radius * 2,
        ),
        math.pi,
        math.pi,
        false,
        ui.Paint()
          ..color = colors[i]
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = size * 0.08
          ..strokeCap = ui.StrokeCap.round,
      );
    }
  }

  static void _strawberry(ui.Canvas canvas, ui.Offset c, double size) {
    final ui.Path path = ui.Path()
      ..moveTo(c.dx, c.dy + size * 0.45)
      ..quadraticBezierTo(
        c.dx - size * 0.5,
        c.dy + size * 0.1,
        c.dx - size * 0.35,
        c.dy - size * 0.2,
      )
      ..quadraticBezierTo(
        c.dx,
        c.dy - size * 0.35,
        c.dx + size * 0.35,
        c.dy - size * 0.2,
      )
      ..quadraticBezierTo(
        c.dx + size * 0.5,
        c.dy + size * 0.1,
        c.dx,
        c.dy + size * 0.45,
      )
      ..close();

    _decal(canvas, path, AppColors.strawberry, size * outlineRatio * 0.75);

    final ui.Paint seedPaint = _fill(AppColors.popYellow);
    for (int i = 0; i < 5; i++) {
      final double angle = (i * math.pi * 2 / 5) - (math.pi / 2);
      canvas.drawCircle(
        ui.Offset(
          c.dx + size * 0.15 * math.cos(angle),
          c.dy + size * 0.1 + size * 0.15 * math.sin(angle),
        ),
        size * 0.03,
        seedPaint,
      );
    }

    final ui.Path leaves = ui.Path()
      ..moveTo(c.dx, c.dy - size * 0.3)
      ..lineTo(c.dx - size * 0.2, c.dy - size * 0.5)
      ..lineTo(c.dx - size * 0.1, c.dy - size * 0.35)
      ..lineTo(c.dx, c.dy - size * 0.5)
      ..lineTo(c.dx + size * 0.1, c.dy - size * 0.35)
      ..lineTo(c.dx + size * 0.2, c.dy - size * 0.5)
      ..close();
    canvas.drawPath(leaves, _fill(AppColors.cherryStem));
  }

  static void _cloud(ui.Canvas canvas, ui.Offset c, double size) {
    final ui.Paint paint = _fill(AppColors.cloudWhite);
    final ui.Paint outline = _edge(size * outlineRatio * 0.75);

    canvas.drawCircle(
      ui.Offset(c.dx - size * 0.25, c.dy + size * 0.05),
      size * 0.25,
      paint,
    );
    canvas.drawCircle(
      ui.Offset(c.dx, c.dy - size * 0.1),
      size * 0.3,
      paint,
    );
    canvas.drawCircle(
      ui.Offset(c.dx + size * 0.25, c.dy + size * 0.05),
      size * 0.25,
      paint,
    );

    canvas.drawRect(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx, c.dy + size * 0.15),
        width: size * 0.8,
        height: size * 0.2,
      ),
      paint,
    );

    canvas.drawCircle(
      ui.Offset(c.dx - size * 0.25, c.dy + size * 0.05),
      size * 0.25,
      outline,
    );
    canvas.drawCircle(
      ui.Offset(c.dx, c.dy - size * 0.1),
      size * 0.3,
      outline,
    );
    canvas.drawCircle(
      ui.Offset(c.dx + size * 0.25, c.dy + size * 0.05),
      size * 0.25,
      outline,
    );
  }

  static void _flower(ui.Canvas canvas, ui.Offset c, double size) {
    final ui.Paint petalFill = _fill(AppColors.popPink);
    final ui.Paint petalEdge = _edge(size * outlineRatio * 0.6);

    for (int i = 0; i < 5; i++) {
      final double angle = (i * math.pi * 2 / 5) - (math.pi / 2);
      final ui.Offset petalCenter = ui.Offset(
        c.dx + size * 0.25 * math.cos(angle),
        c.dy + size * 0.25 * math.sin(angle),
      );
      canvas.drawCircle(petalCenter, size * 0.18, petalFill);
      canvas.drawCircle(petalCenter, size * 0.18, petalEdge);
    }

    canvas.drawCircle(c, size * 0.15, _fill(AppColors.popYellow));
    canvas.drawCircle(c, size * 0.15, _edge(size * outlineRatio * 0.6));
  }

  static void _loveText(ui.Canvas canvas, ui.Offset c, double size) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: 'LOVE',
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w900,
          color: AppColors.popPink,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    painter.layout();
    painter.paint(
      canvas,
      ui.Offset(c.dx - painter.width / 2, c.dy - painter.height / 2),
    );
  }

  static void _cuteText(ui.Canvas canvas, ui.Offset c, double size) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: 'Cute!',
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w900,
          color: AppColors.popBlue,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    painter.layout();
    painter.paint(
      canvas,
      ui.Offset(c.dx - painter.width / 2, c.dy - painter.height / 2),
    );
  }

  static void _hiBubble(ui.Canvas canvas, ui.Offset c, double size) {
    final ui.RRect bubble = ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx, c.dy - size * 0.1),
        width: size * 0.9,
        height: size * 0.5,
      ),
      const ui.Radius.circular(12),
    );
    canvas.drawRRect(bubble, _fill(AppColors.surface));
    canvas.drawRRect(bubble, _edge(size * outlineRatio * 0.5));

    final ui.Path tail = ui.Path()
      ..moveTo(c.dx - size * 0.15, c.dy + size * 0.1)
      ..lineTo(c.dx - size * 0.3, c.dy + size * 0.35)
      ..lineTo(c.dx + size * 0.05, c.dy + size * 0.12)
      ..close();
    canvas.drawPath(tail, _fill(AppColors.surface));
    canvas.drawPath(tail, _edge(size * outlineRatio * 0.5));

    final TextPainter text = TextPainter(
      text: TextSpan(
        text: 'Hi!',
        style: TextStyle(
          fontSize: size * 0.25,
          fontWeight: FontWeight.w900,
          color: AppColors.popNavy,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    text.layout();
    text.paint(
      canvas,
      ui.Offset(
        c.dx - text.width / 2,
        c.dy - size * 0.1 - text.height / 2,
      ),
    );
  }

  static void _bunny(ui.Canvas canvas, ui.Offset c, double size) {
    final ui.Paint paint = _fill(AppColors.surface);
    final ui.Paint outline = _edge(size * outlineRatio * 0.5);

    canvas.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx - size * 0.15, c.dy - size * 0.35),
        width: size * 0.2,
        height: size * 0.4,
      ),
      paint,
    );
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx + size * 0.15, c.dy - size * 0.35),
        width: size * 0.2,
        height: size * 0.4,
      ),
      paint,
    );

    canvas.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx - size * 0.15, c.dy - size * 0.35),
        width: size * 0.1,
        height: size * 0.25,
      ),
      _fill(AppColors.popPink),
    );
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx + size * 0.15, c.dy - size * 0.35),
        width: size * 0.1,
        height: size * 0.25,
      ),
      _fill(AppColors.popPink),
    );

    canvas.drawCircle(c, size * 0.35, paint);

    final ui.Paint ink = _fill(AppColors.popInk);
    canvas.drawCircle(
      ui.Offset(c.dx - size * 0.12, c.dy - size * 0.05),
      size * 0.04,
      ink,
    );
    canvas.drawCircle(
      ui.Offset(c.dx + size * 0.12, c.dy - size * 0.05),
      size * 0.04,
      ink,
    );

    canvas.drawCircle(
      ui.Offset(c.dx, c.dy + size * 0.08),
      size * 0.03,
      _fill(AppColors.popPink),
    );

    canvas.drawArc(
      ui.Rect.fromCenter(
        center: ui.Offset(c.dx, c.dy + size * 0.12),
        width: size * 0.2,
        height: size * 0.1,
      ),
      0.3,
      2.5,
      false,
      ui.Paint()
        ..color = AppColors.popInk
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = size * 0.03
        ..strokeCap = ui.StrokeCap.round,
    );

    canvas.drawCircle(c, size * 0.35, outline);
  }

  static ui.Paint _fill(Color color) => ui.Paint()
    ..isAntiAlias = true
    ..style = ui.PaintingStyle.fill
    ..color = color;

  static ui.Paint _edge(double width) => ui.Paint()
    ..isAntiAlias = true
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = ui.StrokeJoin.round
    ..color = AppColors.surface;

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
