import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CheckerboardPattern extends StatelessWidget {
  const CheckerboardPattern({super.key, this.height = 20, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.fromHeight(height),
      painter: _CheckerboardPainter(color ?? AppColors.checkerPink),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  _CheckerboardPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double cellSize = size.height / 2;
    final Paint pinkPaint = Paint()..color = color;
    final Paint whitePaint = Paint()..color = Colors.white;

    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final bool isPink =
            ((x / cellSize).floor() + (y / cellSize).floor()).isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isPink ? pinkPaint : whitePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter old) =>
      old.color != color;
}
