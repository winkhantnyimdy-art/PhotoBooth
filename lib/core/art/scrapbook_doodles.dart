import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Sparse hand-drawn hearts, cherries and sparkles scattered over the Home
/// scrapbook canvas. Purely decorative (callers wrap it in [IgnorePointer]) so
/// it can never eat taps destined for the CTA or layout cards.
class ScrapbookDoodles extends StatelessWidget {
  const ScrapbookDoodles({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: const _ScrapbookDoodlePainter(),
      ),
    );
  }
}

class _ScrapbookDoodlePainter extends CustomPainter {
  const _ScrapbookDoodlePainter();

  Color _withAlpha(Color color, double alpha) {
    final int a = ((color.a * alpha).clamp(0, 1) * 255).round();
    return Color.fromARGB(a, color.r.round(), color.g.round(), color.b.round());
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double side = size.shortestSide;

    // Heart cluster, top right.
    _drawHeart(
      canvas,
      Offset(size.width * 0.90, size.height * 0.09),
      side * 0.045,
      0.0,
    );
    _drawHeart(
      canvas,
      Offset(size.width * 0.97, size.height * 0.16),
      side * 0.032,
      math.pi / 6,
    );
    _drawHeart(
      canvas,
      Offset(size.width * 0.82, size.height * 0.17),
      side * 0.026,
      -math.pi / 8,
    );

    // Sparkle near the wordmark.
    _drawSparkle(
      canvas,
      Offset(size.width * 0.10, size.height * 0.20),
      side * 0.030,
    );

    // Cherry pair, bottom left.
    _drawCherries(
      canvas,
      Offset(size.width * 0.11, size.height * 0.86),
      side * 0.042,
    );

    // Small heart, bottom right.
    _drawHeart(
      canvas,
      Offset(size.width * 0.92, size.height * 0.88),
      side * 0.028,
      -math.pi / 12,
    );

    // Tiny sparkles upper-left, balancing the cluster.
    _drawSparkle(
      canvas,
      Offset(size.width * 0.22, size.height * 0.08),
      side * 0.018,
    );
  }

  void _drawHeart(Canvas canvas, Offset center, double size, double rotation) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final Path path = _heartPath(size);
    canvas.drawPath(path, Paint()..color = _withAlpha(AppColors.popPink, 0.9));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.12
        ..color = _withAlpha(AppColors.accentDeep, 0.8),
    );
    canvas.restore();
  }

  Path _heartPath(double size) {
    final Path path = Path();
    final double w = size;
    final double h = size * 0.92;
    path.moveTo(0, h * 0.28);
    path.cubicTo(-w * 0.62, -h * 0.28, -w * 0.24, -h * 0.86, 0, -h * 0.42);
    path.cubicTo(w * 0.24, -h * 0.86, w * 0.62, -h * 0.28, 0, h * 0.28);
    path.close();
    return path;
  }

  void _drawSparkle(Canvas canvas, Offset center, double size) {
    final Paint fill = Paint()..color = _withAlpha(AppColors.popYellow, 0.95);
    final Path path = Path();
    const int points = 8;
    for (int i = 0; i < points; i++) {
      final double radius = i.isEven ? size : size * 0.28;
      final double angle = (i / points) * 2 * math.pi - math.pi / 2;
      final Offset p = center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
  }

  void _drawCherries(Canvas canvas, Offset center, double size) {
    final Paint stem = Paint()
      ..color = _withAlpha(AppColors.cherryStem, 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size * 0.10)
      ..strokeCap = StrokeCap.round;
    final Offset left = center + Offset(-size * 0.5, size * 0.55);
    final Offset right = center + Offset(size * 0.55, size * 0.5);
    final Offset top = center + Offset(0, -size * 0.35);

    // Two stems into a shared spur.
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..quadraticBezierTo(
          top.dx - size * 0.15,
          top.dy + size * 0.25,
          top.dx,
          top.dy,
        ),
      stem,
    );
    canvas.drawPath(
      Path()
        ..moveTo(right.dx, right.dy)
        ..quadraticBezierTo(
          top.dx + size * 0.15,
          top.dy + size * 0.25,
          top.dx,
          top.dy,
        ),
      stem,
    );

    // Leaf on the spur.
    final Offset leafTip = top + Offset(-size * 0.55, -size * 0.30);
    final Path leaf = Path()
      ..moveTo(top.dx, top.dy - size * 0.08)
      ..quadraticBezierTo(
        top.dx - size * 0.45,
        top.dy - size * 0.05,
        leafTip.dx,
        leafTip.dy,
      )
      ..quadraticBezierTo(
        top.dx - size * 0.35,
        top.dy + size * 0.10,
        top.dx,
        top.dy - size * 0.08,
      )
      ..close();
    canvas.drawPath(leaf, Paint()..color = _withAlpha(AppColors.cherryStem, 0.9));

    // Two cherries.
    for (final Offset c in <Offset>[left, right]) {
      canvas.drawCircle(
        c,
        size * 0.42,
        Paint()..color = _withAlpha(AppColors.cherry, 0.92),
      );
      canvas.drawCircle(
        c + Offset(-size * 0.14, -size * 0.16),
        size * 0.16,
        Paint()..color = _withAlpha(Colors.white, 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScrapbookDoodlePainter oldDelegate) => false;
}