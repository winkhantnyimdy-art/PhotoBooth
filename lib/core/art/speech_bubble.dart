import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum SpeechBubbleTail { bottomLeft, bottomRight, topLeft, topRight }

class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.child,
    this.tail = SpeechBubbleTail.bottomRight,
  });

  final Widget child;
  final SpeechBubbleTail tail;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _SpeechBubblePainter(tail),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: child,
      ),
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  _SpeechBubblePainter(this.tail);

  final SpeechBubbleTail tail;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()..color = Colors.white;
    final Paint strokePaint = Paint()
      ..color = AppColors.popNavy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 14),
      const Radius.circular(16),
    );
    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, strokePaint);

    final Path tailPath = Path();
    switch (tail) {
      case SpeechBubbleTail.bottomRight:
        tailPath.moveTo(size.width * 0.65, size.height - 14);
        tailPath.lineTo(size.width * 0.88, size.height);
        tailPath.lineTo(size.width * 0.45, size.height - 14);
      case SpeechBubbleTail.bottomLeft:
        tailPath.moveTo(size.width * 0.35, size.height - 14);
        tailPath.lineTo(size.width * 0.12, size.height);
        tailPath.lineTo(size.width * 0.55, size.height - 14);
      case SpeechBubbleTail.topLeft:
        tailPath.moveTo(size.width * 0.35, 14);
        tailPath.lineTo(size.width * 0.12, 0);
        tailPath.lineTo(size.width * 0.55, 14);
      case SpeechBubbleTail.topRight:
        tailPath.moveTo(size.width * 0.65, 14);
        tailPath.lineTo(size.width * 0.88, 0);
        tailPath.lineTo(size.width * 0.45, 14);
    }
    tailPath.close();
    canvas.drawPath(tailPath, fillPaint);
    canvas.drawPath(tailPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter old) =>
      old.tail != tail;
}
