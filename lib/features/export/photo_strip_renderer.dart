import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../core/art/retro_artwork.dart';
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
///
/// Retro Pop presentation: white paper, a navy dashed border and the same
/// decal stickers the Decorate preview draws ([RetroArtwork]).
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
    final bool onDark =
        decorationState.background == BackgroundChoice.charcoal;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    // 1. Frame background
    final ui.Paint bgPaint = ui.Paint()
      ..color = decorationState.background.color;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, exportWidth, height), bgPaint);

    // 2. Navy dashed paper edge — the Retro Pop "sticker sheet" signature.
    _drawDashedFrame(canvas, ui.Size(exportWidth, height), onDark);

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
    // the Decorate preview exactly. Artwork is shared via RetroArtwork.
    for (final sticker in decorationState.stickers) {
      _renderSticker(
        canvas,
        sticker.type,
        ui.Offset(sticker.x * exportWidth, sticker.y * gridHeight),
        PhotoStripGeometry.stickerSize,
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
  //
  // Drawn with the shared Retro Pop decal artwork so the exported strip and
  // the live Decorate preview are pixel-identical.
  void _renderSticker(
    ui.Canvas canvas,
    StickerType type,
    ui.Offset center,
    double size,
  ) {
    RetroArtwork.paintSticker(canvas, type, center, size);
  }

  /// Retro Pop paper edge: a navy dashed inset border, exactly the sticker
  /// sheet treatment in the reference. Deterministic — the dash pattern is
  /// fixed, never random.
  void _drawDashedFrame(ui.Canvas canvas, ui.Size size, bool onDark) {
    final double inset = 14;
    final double thickness = 7;
    final double dash = 26;
    final double gap = 18;
    final ui.Rect frame = ui.Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    final ui.Paint paint = ui.Paint()
      ..isAntiAlias = true
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = ui.StrokeCap.round
      ..color = onDark
          ? AppColors.popBlue.withValues(alpha: 0.75)
          : AppColors.popNavy;

    void run(ui.Offset from, ui.Offset to) {
      final double length = (to - from).distance;
      if (length <= 0) return;
      final ui.Offset dir = (to - from) / length;
      for (double d = 0; d < length; d += dash + gap) {
        final double end = d + dash < length ? d + dash : length;
        canvas.drawLine(from + dir * d, from + dir * end, paint);
      }
    }

    run(frame.topLeft, frame.topRight);
    run(frame.topRight, frame.bottomRight);
    run(frame.bottomRight, frame.bottomLeft);
    run(frame.bottomLeft, frame.topLeft);
  }


  // ---------------------------------------------------------------------------
  // Branding footer
  // ---------------------------------------------------------------------------

  /// Retro Pop footer: a coral, white-outlined "PHOTOBOOTH" wordmark centred in
  /// the strip's caption band, with an optional date beneath.
  ///
  /// The wordmark is drawn twice — a thick white pass then the coral pass — to
  /// reproduce the decal treatment used on the app's own header logo.
  void _renderBranding(
    ui.Canvas canvas,
    ui.Rect footer,
    DecorationState decorationState,
    bool onDark,
  ) {
    final ui.Color ink = onDark ? AppColors.onDark : AppColors.popInk;

    final bool hasDate = decorationState.showDate;
    final double brandFontSize = 34;
    final double dateFontSize = 20;

    final TextPainter brand = _textPainter(
      'PHOTOBOOTH',
      TextStyle(
        fontSize: brandFontSize,
        fontWeight: FontWeight.w900,
        color: AppColors.accent,
        letterSpacing: 3,
      ),
    );
    final TextPainter? date = hasDate
        ? _textPainter(
            formatExportDate(decorationState.displayDate),
            TextStyle(
              fontSize: dateFontSize,
              fontWeight: FontWeight.w600,
              color: ink.withValues(alpha: 0.75),
              letterSpacing: 2,
            ),
          )
        : null;

    final double blockHeight =
        brand.height + (date == null ? 0 : date.height + 10);
    double top = footer.center.dy - (blockHeight / 2);

    // White halo pass, then the coral wordmark on top.
    final TextPainter halo = _textPainter(
      'PHOTOBOOTH',
      TextStyle(
        fontSize: brandFontSize,
        fontWeight: FontWeight.w900,
        color: AppColors.surface,
        letterSpacing: 3,
      ),
    );
    halo.paint(
      canvas,
      Offset(footer.center.dx - halo.width / 2, top - 4),
    );
    brand.paint(canvas, Offset(footer.center.dx - brand.width / 2, top));

    top += brand.height + 10;
    date?.paint(canvas, Offset(footer.center.dx - date.width / 2, top));
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
