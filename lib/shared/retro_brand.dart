import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// The PhotoBooth wordmark, drawn as a decal.
///
/// Concept C sets the logo in heavy coral with a white outline sitting on the
/// pale yellow chrome. Flutter cannot stroke text directly, so the halo is
/// faked by painting a slightly larger white copy behind the coral one — the
/// same two-pass trick the PNG renderer uses for the exported caption band, so
/// the brand looks the same on screen and on the print.
class PhotoBoothWordmark extends StatelessWidget {
  const PhotoBoothWordmark({super.key, this.fontSize = 26, this.color});

  /// Cap height of the coral wordmark.
  final double fontSize;

  /// Overrides the coral (defaults to the brand coral).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color face = color ?? AppColors.accent;
    final TextStyle base = AppText.wordmark.copyWith(
      fontSize: fontSize,
      color: face,
    );
    // A ~7% larger white pass reads as a clean outline at any size.
    final TextStyle halo = base.copyWith(
      fontSize: fontSize * 1.07,
      color: AppColors.surface,
      fontWeight: FontWeight.w900,
    );

    return Semantics(
      header: true,
      label: 'PhotoBooth',
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Text('PhotoBooth', style: halo),
          Text('PhotoBooth', style: base),
        ],
      ),
    );
  }
}

/// A small navy-outlined sticker dot used as playful filler around chrome.
class RetroSparkleDot extends StatelessWidget {
  const RetroSparkleDot({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.square(size),
        painter: _DotPainter(color ?? AppColors.popBlue),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2;
    final Path star = Path();
    for (int i = 0; i < 8; i++) {
      final double angle = (i * math.pi / 4) - (math.pi / 2);
      final double rr = i.isEven ? r : r * 0.38;
      final Offset p = Offset(
        c.dx + rr * math.cos(angle),
        c.dy + rr * math.sin(angle),
      );
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    canvas.drawPath(
      star,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill
        ..color = color,
    );
    canvas.drawPath(
      star,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.popNavy,
    );
  }

  @override
  bool shouldRepaint(covariant _DotPainter old) => old.color != color;
}
