import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../home/layout_model.dart';
import '../decorate/decoration_model.dart';

/// A renderer that creates a high-resolution PNG of the PhotoBooth composition.
///
/// It is deterministic and independent of the device's screen size.
class PhotoStripRenderer {
  /// Target export width in pixels.
  static const double exportWidth = 1200.0;

  /// Height of the branding footer in pixels.
  static const double footerHeight = 150.0;

  /// Renders the composition to PNG bytes.
  Future<Uint8List> render({
    required PhotoLayout layout,
    required List<XFile> photos,
    required DecorationState decorationState,
  }) async {
    final double height = _calculateTotalHeight(layout);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    // 1. Background
    final ui.Paint bgPaint = ui.Paint()..color = decorationState.background.color;
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, exportWidth, height),
      bgPaint,
    );

    // 2. Border (3px)
    final ui.Paint borderPaint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = decorationState.background == BackgroundChoice.charcoal
          ? AppColors.line
          : decorationState.background.color.withValues(alpha: 0.3);

    canvas.drawRect(
      ui.Rect.fromLTWH(1.5, 1.5, exportWidth - 3.0, height - 3.0),
      borderPaint,
    );

    // 3. Photos Grid
    final double gridHeight = height - footerHeight;
    final int cols = layout.cols;
    final int rows = layout.rows;
    final double cellPadding = S.sm * 2.0;
    final double availableGridWidth = exportWidth - (cellPadding * 2);
    final double availableGridHeight = gridHeight - (cellPadding * 2);

    final double cellWidth = (availableGridWidth - (cols - 1) * cellPadding) / cols;
    final double cellHeight = (availableGridHeight - (rows - 1) * cellPadding) / rows;

    for (int i = 0; i < photos.length; i++) {
      if (i >= cols * rows) break;

      final int r = i ~/ cols;
      final int c = i % cols;

      final double left = cellPadding + c * (cellWidth + cellPadding);
      final double top = cellPadding + r * (cellHeight + cellPadding);

      final ui.Image image = await _decodeAndCropImage(photos[i].path, cellWidth, cellHeight);

      canvas.drawImage(image, ui.Offset(left, top), ui.Paint());
    }

    // 4. Decorative Styles (Overlay)
    if (decorationState.style != DecorativeStyle.clean) {
      _renderStyleOverlay(canvas, decorationState.style, decorationState.background, gridHeight);
    }

    // 5. Stickers
    for (final sticker in decorationState.stickers) {
      final double sx = sticker.x * exportWidth;
      final double sy = sticker.y * gridHeight;
      _renderStickerIcon(canvas, sticker.type, ui.Offset(sx, sy), decorationState.background);
    }

    // 6. Branding & Date
    _renderBranding(canvas, height, decorationState);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(exportWidth.toInt(), height.toInt());
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to encode image to PNG');

    return byteData.buffer.asUint8List();
  }

  double _calculateTotalHeight(PhotoLayout layout) {
    double contentHeight;
    if (layout == PhotoLayout.cut4) {
      contentHeight = 2000.0;
    } else {
      contentHeight = 1200.0;
    }
    return contentHeight + footerHeight;
  }

  Future<ui.Image> _decodeAndCropImage(String path, double targetW, double targetH) async {
    final Uint8List bytes = await File(path).readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetW.toInt(),
      targetHeight: targetH.toInt(),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }

  void _renderStyleOverlay(ui.Canvas canvas, DecorativeStyle style, BackgroundChoice background, double height) {
    final ui.Paint paint = ui.Paint()
      ..style = ui.PaintingStyle.fill
      ..color = background == BackgroundChoice.charcoal
          ? Colors.white.withValues(alpha: 0.15)
          : AppColors.accentDeep.withValues(alpha: 0.1);

    if (style == DecorativeStyle.hearts) {
      _drawHearts(canvas, paint, height);
    } else if (style == DecorativeStyle.stars) {
      _drawStars(canvas, paint, height);
    } else if (style == DecorativeStyle.sparkle) {
      _drawSparkles(canvas, paint, height);
    }
  }

  void _drawHearts(ui.Canvas canvas, ui.Paint paint, double height) {
    final double heartSize = exportWidth * 0.05;
    final double spacing = exportWidth * 0.2;
    for (double y = heartSize; y < height - heartSize; y += spacing) {
      for (double x = heartSize; x < exportWidth - heartSize; x += spacing) {
        final Path path = Path();
        path.moveTo(x, y + heartSize * 0.3);
        path.quadraticBezierTo(x - heartSize * 0.4, y - heartSize * 0.3, x, y + heartSize * 0.1);
        path.quadraticBezierTo(x + heartSize * 0.4, y - heartSize * 0.3, x, y + heartSize * 0.3);
        path.quadraticBezierTo(x - heartSize * 0.4, y + heartSize * 0.8, x, y + heartSize * 1.2);
        path.quadraticBezierTo(x + heartSize * 0.4, y + heartSize * 0.8, x, y + heartSize * 0.3);
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawStars(ui.Canvas canvas, ui.Paint paint, double height) {
    final double starSize = exportWidth * 0.04;
    final double spacing = exportWidth * 0.25;
    for (double y = starSize; y < height - starSize; y += spacing) {
      for (double x = starSize; x < exportWidth - starSize; x += spacing) {
      final Path path = Path();
      path.moveTo(x, y - starSize);
      path.lineTo(x + starSize * 0.2, y - starSize * 0.3);
      path.lineTo(x + starSize, y - starSize);
      path.lineTo(x + starSize * 0.3, y + starSize * 0.2);
      path.lineTo(x + starSize * 0.5, y + starSize);
      path.lineTo(x, y + starSize * 0.3);
      path.lineTo(x - starSize * 0.5, y + starSize);
      path.lineTo(x - starSize * 0.3, y + starSize * 0.2);
      path.lineTo(x - starSize, y - starSize);
      path.lineTo(x - starSize * 0.2, y - starSize * 0.3);
      path.close();
      canvas.drawPath(path, paint);
    }
    }
  }

  void _drawSparkles(ui.Canvas canvas, ui.Paint paint, double height) {
    final double sparkleSize = exportWidth * 0.04;
    final double spacing = exportWidth * 0.3;
    for (double y = sparkleSize; y < height - sparkleSize; y += spacing) {
      for (double x = sparkleSize; x < exportWidth - sparkleSize; x += spacing) {
        canvas.drawRect(ui.Rect.fromCenter(center: Offset(x, y), width: sparkleSize * 0.2, height: sparkleSize * 1.2), paint);
        canvas.drawRect(ui.Rect.fromCenter(center: Offset(x, y), width: sparkleSize * 1.2, height: sparkleSize * 0.2), paint);
        canvas.drawCircle(Offset(x, y), sparkleSize * 0.5, paint);
      }
    }
  }

  void _renderStickerIcon(ui.Canvas canvas, StickerType type, ui.Offset offset, BackgroundChoice background) {
    final ui.Paint paint = ui.Paint()
      ..color = background == BackgroundChoice.charcoal
          ? Colors.white
          : AppColors.accentDeep;

    // High-res representative shape for each sticker type
    if (type == StickerType.heart) {
      final Path path = Path();
      path.moveTo(offset.dx, offset.dy + 10);
      path.quadraticBezierTo(offset.dx - 10, offset.dy - 10, offset.dx, offset.dy + 2);
      path.quadraticBezierTo(offset.dx + 10, offset.dy - 10, offset.dx, offset.dy + 10);
      canvas.drawPath(path, paint);
    } else if (type == StickerType.star) {
      canvas.drawCircle(Offset(offset.dx, offset.dy), 10, paint);
    } else if (type == StickerType.smile) {
      canvas.drawCircle(Offset(offset.dx, offset.dy), 10, paint);
      canvas.drawCircle(Offset(offset.dx - 4, offset.dy - 2), 2, paint);
      canvas.drawCircle(Offset(offset.dx + 4, offset.dy - 2), 2, paint);
    }
  }

  void _renderBranding(ui.Canvas canvas, double totalHeight, DecorationState decorationState) {
    final ui.Paint footerPaint = ui.Paint()
      ..color = decorationState.background == BackgroundChoice.charcoal
          ? Colors.black54
          : Colors.black38;

    canvas.drawRect(
      ui.Rect.fromLTWH(0, totalHeight - footerHeight, exportWidth, footerHeight),
      footerPaint,
    );

    final TextPainter brandingPainter = TextPainter(
      text: TextSpan(
        text: 'PHOTOBOOTH',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    brandingPainter.layout();
    brandingPainter.paint(canvas, Offset((exportWidth - brandingPainter.width) / 2, totalHeight - footerHeight + (footerHeight - brandingPainter.height) / 2));

    if (decorationState.showDate) {
      final TextPainter datePainter = TextPainter(
        text: TextSpan(
          text: '${decorationState.displayDate.year}-${decorationState.displayDate.month.toString().padLeft(2, '0')}-${decorationState.displayDate.day.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white70,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      datePainter.layout();
      datePainter.paint(canvas, Offset((exportWidth - datePainter.width) / 2, totalHeight - footerHeight + (footerHeight + brandingPainter.height) / 2));
    }
  }
}