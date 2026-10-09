import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../core/theme/app_colors.dart';
import '../home/layout_geometry.dart';
import '../home/layout_model.dart';
import '../decorate/decoration_model.dart';

/// A renderer that creates a high-resolution PNG of the PhotoBooth composition.
///
/// It is deterministic and independent of the device's screen size: the canvas
/// is always [exportWidth] pixels wide and the grid comes from
/// [PhotoStripGeometry], the same geometry the in-app previews use. That is
/// what guarantees the Home card, the Decorate preview and the exported PNG
/// show the same arrangement — and that captured photos are never stretched,
/// because each photo is decoded into a cell of the strip's own aspect.
class PhotoStripRenderer {
  /// Target export width in pixels.
  static const double exportWidth = PhotoStripGeometry.exportWidth;

  /// Height of the branding footer in pixels.
  static const double footerHeight = PhotoStripGeometry.footerHeight;

  /// Renders the composition to PNG bytes.
  Future<Uint8List> render({
    required PhotoLayout layout,
    required List<XFile> photos,
    required DecorationState decorationState,
  }) async {
    final double height = PhotoStripGeometry.totalHeight(layout);
    final double gridHeight = PhotoStripGeometry.contentHeight(layout);
    final bool onDark = decorationState.background == BackgroundChoice.charcoal;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    // 1. Frame background
    final ui.Paint bgPaint = ui.Paint()
      ..color = decorationState.background.color;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, exportWidth, height), bgPaint);

    // 2. Hairline frame edge
    final ui.Paint borderPaint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = onDark
          ? AppColors.line.withValues(alpha: 0.55)
          : decorationState.background.color.withValues(alpha: 0.22);
    canvas.drawRect(
      ui.Rect.fromLTWH(2, 2, exportWidth - 4, height - 4),
      borderPaint,
    );

    // 3. Photo cells, row-major in capture order.
    for (int i = 0; i < photos.length; i++) {
      if (i >= layout.photoCount) break;
      final ui.Rect cell = PhotoStripGeometry.cellRect(layout, i);
      final ui.Image image = await _decodeImage(
        photos[i].path,
        cell.width.round(),
        cell.height.round(),
      );
      _drawFramedImage(canvas, image, cell);
      image.dispose();
    }

    // 4. Decorative style overlay across the grid area.
    if (decorationState.style != DecorativeStyle.clean) {
      _renderStyleOverlay(
        canvas,
        decorationState.style,
        onDark,
        ui.Rect.fromLTWH(0, 0, exportWidth, gridHeight),
      );
    }

    // 5. Stickers — normalised coordinates map onto the grid area, matching
    // the Decorate preview exactly.
    final ui.Paint stickerPaint = ui.Paint()
      ..color = onDark ? AppColors.onDark : AppColors.accentDeep;
    for (final sticker in decorationState.stickers) {
      _renderSticker(
        canvas,
        sticker.type,
        ui.Offset(sticker.x * exportWidth, sticker.y * gridHeight),
        stickerPaint,
      );
    }

    // 6. Branding footer with optional date.
    _renderBranding(
      canvas,
      ui.Rect.fromLTWH(0, gridHeight, exportWidth, footerHeight),
      decorationState,
      onDark,
    );

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(
      exportWidth.toInt(),
      height.toInt(),
    );
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    img.dispose();
    if (byteData == null) throw Exception('Failed to encode image to PNG');

    return byteData.buffer.asUint8List();
  }

  /// Draws one photo with a subtle white rim so frames read as prints.
  void _drawFramedImage(ui.Canvas canvas, ui.Image image, ui.Rect cell) {
    final double radius = 10;
    final ui.RRect target = ui.RRect.fromRectAndRadius(
      cell,
      ui.Radius.circular(radius),
    );
    // White rim behind the photo gives the cell definition on light frames.
    canvas.drawRRect(
      target.inflate(3),
      ui.Paint()..color = AppColors.surface.withValues(alpha: 0.9),
    );
    canvas.save();
    canvas.clipRRect(target);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      cell,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    canvas.restore();
  }

  Future<ui.Image> _decodeImage(
    String path,
    int targetWidth,
    int targetHeight,
  ) async {
    final Uint8List bytes = await File(path).readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  // ---------------------------------------------------------------------------
  // Decorative overlay
  // ---------------------------------------------------------------------------

  void _renderStyleOverlay(
    ui.Canvas canvas,
    DecorativeStyle style,
    bool onDark,
    ui.Rect area,
  ) {
    final ui.Paint paint = ui.Paint()
      ..style = ui.PaintingStyle.fill
      ..color = onDark
          ? AppColors.onDark.withValues(alpha: 0.16)
          : AppColors.accentDeep.withValues(alpha: 0.13);

    switch (style) {
      case DecorativeStyle.clean:
        return;
      case DecorativeStyle.hearts:
        _tile(area, area.shortestSide * 0.055, area.shortestSide * 0.2, (
          Offset center,
          double size,
        ) {
          canvas.drawPath(_heartPath(center, size * 1.6), paint);
        });
      case DecorativeStyle.stars:
        _tile(area, area.shortestSide * 0.04, area.shortestSide * 0.24, (
          Offset center,
          double size,
        ) {
          canvas.drawPath(_starPath(center, size), paint);
        });
      case DecorativeStyle.sparkle:
        _tile(area, area.shortestSide * 0.035, area.shortestSide * 0.28, (
          Offset center,
          double size,
        ) {
          canvas.drawPath(_sparklePath(center, size), paint);
        });
    }
  }

  /// Lays a glyph on a regular grid across [area], fully deterministic.
  void _tile(
    ui.Rect area,
    double size,
    double spacing,
    void Function(Offset center, double size) draw,
  ) {
    for (double y = size; y < area.height - size * 0.5; y += spacing) {
      for (double x = size; x < area.width - size * 0.5; x += spacing) {
        draw(Offset(x, y), size);
      }
    }
  }

  static ui.Path _heartPath(Offset center, double size) {
    final ui.Path path = ui.Path();
    path.moveTo(center.dx, center.dy + size * 0.38);
    path.quadraticBezierTo(
      center.dx - size * 0.6,
      center.dy - size * 0.28,
      center.dx,
      center.dy + size * 0.02,
    );
    path.quadraticBezierTo(
      center.dx + size * 0.6,
      center.dy - size * 0.28,
      center.dx,
      center.dy + size * 0.38,
    );
    path.close();
    return path;
  }

  static ui.Path _starPath(Offset center, double radius) {
    final ui.Path path = ui.Path();
    for (int i = 0; i < 10; i++) {
      final double r = i.isEven ? radius : radius * 0.45;
      final double angle = (i * 3.141592653589793 / 5) - 1.5707963267948966;
      final Offset point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  static ui.Path _sparklePath(Offset center, double size) {
    final ui.Path path = ui.Path();
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(
      center.dx + size * 0.22,
      center.dy - size * 0.22,
      center.dx + size,
      center.dy,
    );
    path.quadraticBezierTo(
      center.dx + size * 0.22,
      center.dy + size * 0.22,
      center.dx,
      center.dy + size,
    );
    path.quadraticBezierTo(
      center.dx - size * 0.22,
      center.dy + size * 0.22,
      center.dx - size,
      center.dy,
    );
    path.quadraticBezierTo(
      center.dx - size * 0.22,
      center.dy - size * 0.22,
      center.dx,
      center.dy - size,
    );
    path.close();
    return path;
  }

  // ---------------------------------------------------------------------------
  // Stickers
  // ---------------------------------------------------------------------------

  /// Draws every [StickerType]. Previously only heart, star and smile had
  /// artwork, so the other five options were silently dropped from the export
  /// even though the Decorate screen offered them.
  void _renderSticker(
    ui.Canvas canvas,
    StickerType type,
    ui.Offset center,
    ui.Paint paint,
  ) {
    const double size = 34;
    switch (type) {
      case StickerType.heart:
        canvas.drawPath(_heartPath(center, size), paint);
      case StickerType.star:
        canvas.drawPath(_starPath(center, size * 0.95), paint);
      case StickerType.sparkle:
        canvas.drawPath(_sparklePath(center, size * 0.85), paint);
      case StickerType.flower:
        for (int i = 0; i < 5; i++) {
          final double angle = (i * 3.141592653589793 / 5) - 1.5707963267948966;
          canvas.drawCircle(
            Offset(
              center.dx + size * 0.55 * math.cos(angle),
              center.dy + size * 0.55 * math.sin(angle),
            ),
            size * 0.38,
            paint,
          );
        }
        canvas.drawCircle(center, size * 0.32, paint);
      case StickerType.ribbon:
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromCenter(
              center: center,
              width: size * 1.4,
              height: size * 0.9,
            ),
            ui.Radius.circular(size * 0.2),
          ),
          paint,
        );
        canvas.drawPath(
          ui.Path()
            ..moveTo(center.dx - size * 0.5, center.dy + size * 0.35)
            ..lineTo(center.dx - size * 0.75, center.dy + size * 0.95)
            ..lineTo(center.dx - size * 0.1, center.dy + size * 0.7)
            ..close(),
          paint,
        );
        canvas.drawPath(
          ui.Path()
            ..moveTo(center.dx + size * 0.5, center.dy + size * 0.35)
            ..lineTo(center.dx + size * 0.75, center.dy + size * 0.95)
            ..lineTo(center.dx + size * 0.1, center.dy + size * 0.7)
            ..close(),
          paint,
        );
      case StickerType.smile:
        canvas.drawCircle(center, size, paint);
        final ui.Paint face = ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = size * 0.13
          ..strokeCap = ui.StrokeCap.round
          ..color = AppColors.surface;
        canvas.drawCircle(
          Offset(center.dx - size * 0.35, center.dy - size * 0.2),
          size * 0.1,
          ui.Paint()..color = AppColors.surface,
        );
        canvas.drawCircle(
          Offset(center.dx + size * 0.35, center.dy - size * 0.2),
          size * 0.1,
          ui.Paint()..color = AppColors.surface,
        );
        canvas.drawArc(
          ui.Rect.fromCenter(
            center: Offset(center.dx, center.dy + size * 0.12),
            width: size * 1.1,
            height: size * 0.8,
          ),
          0.35,
          2.44,
          false,
          face,
        );
      case StickerType.speechBubble:
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromCenter(
              center: Offset(center.dx, center.dy - size * 0.15),
              width: size * 1.6,
              height: size * 1.15,
            ),
            ui.Radius.circular(size * 0.35),
          ),
          paint,
        );
        canvas.drawPath(
          ui.Path()
            ..moveTo(center.dx - size * 0.3, center.dy + size * 0.3)
            ..lineTo(center.dx - size * 0.55, center.dy + size * 0.95)
            ..lineTo(center.dx + size * 0.05, center.dy + size * 0.4)
            ..close(),
          paint,
        );
      case StickerType.cuteSymbol:
        canvas.drawCircle(center, size * 1.05, paint);
        canvas.drawPath(
          _heartPath(Offset(center.dx, center.dy - size * 0.05), size * 0.62),
          ui.Paint()..color = AppColors.surface,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Branding footer
  // ---------------------------------------------------------------------------

  /// Refined footer: a hairline rule, letterspaced wordmark and an optional
  /// date. Replaces the flat translucent grey bar, which read as a debug
  /// overlay rather than part of the print.
  void _renderBranding(
    ui.Canvas canvas,
    ui.Rect footer,
    DecorationState decorationState,
    bool onDark,
  ) {
    final ui.Color ink = onDark ? AppColors.onDark : AppColors.textPrimary;

    canvas.drawRect(
      ui.Rect.fromLTWH(footer.left, footer.top, footer.width, 2),
      ui.Paint()..color = ink.withValues(alpha: 0.12),
    );

    final bool hasDate = decorationState.showDate;
    final double brandFontSize = 26;
    final double dateFontSize = 18;

    final TextPainter brand = _textPainter(
      'PHOTOBOOTH',
      TextStyle(
        fontSize: brandFontSize,
        fontWeight: FontWeight.w600,
        color: ink,
        letterSpacing: 6,
      ),
    );
    final TextPainter? date = hasDate
        ? _textPainter(
            formatExportDate(decorationState.displayDate),
            TextStyle(
              fontSize: dateFontSize,
              fontWeight: FontWeight.w400,
              color: ink.withValues(alpha: 0.7),
              letterSpacing: 2,
            ),
          )
        : null;

    final double blockHeight =
        brand.height + (date == null ? 0 : date.height + 8);
    double top = footer.center.dy - (blockHeight / 2);

    brand.paint(canvas, Offset((footer.center.dx - brand.width / 2), top));
    top += brand.height + 8;
    date?.paint(canvas, Offset((footer.center.dx - date.width / 2), top));

    // Small accent rule under the wordmark ties the footer to the palette.
    final double ruleWidth = brand.width * 0.18;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromCenter(
          center: Offset(footer.center.dx, top + (date == null ? 16 : 6)),
          width: ruleWidth,
          height: 3,
        ),
        ui.Radius.circular(2),
      ),
      ui.Paint()..color = AppColors.accent.withValues(alpha: 0.9),
    );
  }

  static TextPainter _textPainter(String text, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    );
    painter.layout();
    return painter;
  }
}
