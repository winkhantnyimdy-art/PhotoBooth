import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PhotoBoothBubbleLogo extends StatelessWidget {
  const PhotoBoothBubbleLogo({super.key, this.width = 200});

  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 0.55),
      painter: const _BubbleLogoPainter(),
    );
  }
}

class _BubbleLogoPainter extends CustomPainter {
  const _BubbleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double fontSize = size.width * 0.14;

    _drawBubbleText(
      canvas,
      'PHOTO',
      size.width * 0.5,
      size.height * 0.28,
      fontSize,
      AppColors.bubblePink,
    );
    _drawBubbleText(
      canvas,
      'BOOTH',
      size.width * 0.5,
      size.height * 0.72,
      fontSize,
      AppColors.bubbleBlue,
    );
  }

  void _drawBubbleText(
    Canvas canvas,
    String text,
    double cx,
    double cy,
    double fontSize,
    Color fill,
  ) {
    final TextPainter outlinePainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize * 1.15,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    outlinePainter.layout();
    outlinePainter.paint(
      canvas,
      Offset(
        cx - outlinePainter.width / 2,
        cy - outlinePainter.height / 2,
      ),
    );

    final TextPainter fillPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: fill,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    fillPainter.layout();
    fillPainter.paint(
      canvas,
      Offset(
        cx - fillPainter.width / 2,
        cy - fillPainter.height / 2,
      ),
    );

    final TextPainter highlightPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize * 0.85,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: 0.35),
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    highlightPainter.layout();
    highlightPainter.paint(
      canvas,
      Offset(
        cx - highlightPainter.width / 2 - fontSize * 0.02,
        cy - highlightPainter.height / 2 - fontSize * 0.02,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
