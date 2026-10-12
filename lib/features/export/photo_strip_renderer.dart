import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../core/art/frame_theme_painter.dart';
import '../../core/art/sticker_artwork.dart';
import '../../core/art/text_overlay.dart';
import '../../core/filters/film_grain.dart';
import '../../core/filters/photo_filter.dart';
import '../../core/media/photo_source.dart';
import '../../core/theme/app_colors.dart';
import '../camera/camera_geometry.dart';
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
/// Retro Pop presentation: white paper, a pink polka-dot border and the same
/// illustrated stickers the Decorate preview draws ([StickerArtwork]).
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

    // Decoded photos are owned by the recorded picture until it has been
    // rasterised. Releasing them any earlier makes CanvasKit draw blank cells,
    // so they are collected here and freed at the very end.
    final List<ui.Image> decodedPhotos = <ui.Image>[];

    try {
      // 1. Frame background — the chosen premium theme paints paper + border +
      // wordmark. The same FrameThemePainter runs in the Decorate preview, so
      // the export is pixel-faithful to what the user saw.
      FrameThemePainter.paint(
        canvas,
        ui.Rect.fromLTWH(0, 0, exportWidth, height),
        decorationState.frameTheme,
        wordmarkSize: 36,
      );

      // The colour matrix shared by the preview and this export. Identity when
      // the user is on Original at 0 strength, which skips the filter entirely.
      final List<double> matrix = buildMatrix(
        decorationState.filter,
        decorationState.filterIntensity,
        decorationState.adjustments,
      );
      final ui.ColorFilter? colorFilter = isIdentityMatrix(matrix)
          ? null
          : ui.ColorFilter.matrix(matrix);

      // 3. Photo cells, row-major in capture order.
      for (int i = 0; i < photos.length; i++) {
        if (i >= layout.photoCount) break;
        final ui.Rect cell = PhotoStripGeometry.cellRect(layout, i);
        final ui.Image image = await _decodeImage(
          photos[i],
          // 2x the cell width keeps the strip crisp on a retina export
          // without decoding four full-resolution camera frames.
          (cell.width * 2).round().clamp(1, 4096),
        );
        decodedPhotos.add(image);
        _drawFramedImage(canvas, image, cell, colorFilter);
      }

    // 3b. Film grain sits over the photos only, inside the frame border.
    if (decorationState.filter.hasGrain &&
          decorationState.filterIntensity > 0) {
        final ui.Rect content = ui.Rect.fromLTWH(
          PhotoStripGeometry.outerPadding,
          PhotoStripGeometry.outerPadding,
          exportWidth - (PhotoStripGeometry.outerPadding * 2),
          gridHeight - (PhotoStripGeometry.outerPadding * 2),
        );
        FilmGrain.paint(
          canvas,
          content,
          decorationState.filterIntensity,
          seed: exportWidth.toInt(),
        );
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
      // the Decorate preview exactly. Artwork is shared via StickerArtwork.
      // Scale and rotation are applied so the export matches the preview.
      for (final sticker in decorationState.stickers) {
        final double size = PhotoStripGeometry.stickerSize * sticker.scale;
        final ui.Offset center =
            ui.Offset(sticker.x * exportWidth, sticker.y * gridHeight);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(sticker.rotation);
        _renderSticker(canvas, sticker.type, ui.Offset.zero, size);
        canvas.restore();
      }

      // 5b. User captions, drawn with the same routine as the live preview.
      for (final TextPlacement text in decorationState.texts) {
        TextOverlayRenderer.paint(
          canvas,
          text,
          ui.Size(exportWidth, height),
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
      picture.dispose();
      final ByteData? byteData = await img.toByteData(
        format: ui.ImageByteFormat.png,
      );
      img.dispose();
      if (byteData == null) throw Exception('Failed to encode image to PNG');

      return byteData.buffer.asUint8List();
    } finally {
      // Only safe now that the picture has been rasterised.
      for (final ui.Image image in decodedPhotos) {
        image.dispose();
      }
    }
  }

  /// Draws one photo into its cell with a **cover** crop.
  ///
  /// The previous implementation stretched the whole photo into the cell, which
  /// squashed faces whenever the cell shape and the camera frame disagreed.
  /// Now the cell's aspect and the photo's own aspect decide the crop through
  /// [CameraGeometry.coverRect] - the same maths the live viewfinder uses, so
  /// the framing the user saw is the framing that is exported.
  ///
  /// [colorFilter], when provided, is the shared preset/strength matrix, so the
  /// exported pixels match the previewed pixels exactly.
  void _drawFramedImage(
    ui.Canvas canvas,
    ui.Image image,
    ui.Rect cell, [
    ui.ColorFilter? colorFilter,
  ]) {
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

    final ui.Rect source = CameraGeometry.sourceRectForCover(
      source: Size(image.width.toDouble(), image.height.toDouble()),
      target: cell.size,
    );

    canvas.save();
    canvas.clipRRect(target);
    canvas.drawImageRect(
      image,
      source,
      cell,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.medium
        ..colorFilter = colorFilter,
    );
    canvas.restore();
  }

  /// Decodes one captured photo into a [ui.Image], preserving its own aspect.
  ///
  /// Only `targetWidth` is supplied: the codec derives the height from the real
  /// aspect. Passing both dimensions - as the old code did - forced the frame
  /// into the cell's shape *before* the cover crop ran, which is exactly how
  /// faces got stretched. Decoding wide enough for the cell (2x for retina)
  /// keeps quality high without decoding four full-resolution frames.
  ///
  /// Uses [ui.instantiateImageCodecFromBuffer] rather than the older
  /// [ui.instantiateImageCodec]. This is load-bearing on the web: the
  /// byte-array overload does not decode reliably there and silently yields
  /// blank frames. The buffer overload is the same entry point the image
  /// pipeline uses on every platform.
  ///
  /// Nothing here touches `PaintingBinding`, so the renderer remains usable from
  /// a plain `test()` with no widget binding.
  Future<ui.Image> _decodeImage(XFile photo, int targetWidth) async {
    // Works on Android/iOS (file read) and on the web (blob re-hydration).
    final Uint8List bytes = await readPhotoBytes(photo);
    // The codec takes ownership of the buffer and releases it on dispose, so
    // the buffer is deliberately not disposed here.
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
      bytes,
    );
    final ui.Codec codec = await ui.instantiateImageCodecFromBuffer(
      buffer,
      targetWidth: targetWidth,
    );
    try {
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
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
  // Drawn with the shared Retro Pop sticker artwork so the exported strip and
  // the live Decorate preview are pixel-identical.
  void _renderSticker(
    ui.Canvas canvas,
    StickerType type,
    ui.Offset center,
    double size,
  ) {
    StickerArtwork.paintSticker(canvas, type, center, size);
  }

  /// Retro Pop paper edge is now style-selectable; see [FrameDecorations].
  // ---------------------------------------------------------------------------
  // Branding footer
  // ---------------------------------------------------------------------------

  /// Retro Pop footer: the frame theme's wordmark centred in the strip's
  /// caption band, with an optional date beneath.
  ///
  /// The wordmark comes from [FrameThemePainter.paintWordmark] so the export
  /// and the Decorate preview show the same branding.
  void _renderBranding(
    ui.Canvas canvas,
    ui.Rect footer,
    DecorationState decorationState,
    bool onDark,
  ) {
    final bool hasDate = decorationState.showDate;

    // Delegate wordmark painting to the theme painter so the footer matches
    // the preview exactly.
    FrameThemePainter.paintWordmark(
      canvas,
      footer,
      decorationState.frameTheme,
      36,
    );

    if (hasDate) {
      final ui.Color ink = onDark ? AppColors.onDark : AppColors.popInk;
      final double dateFontSize = 20;
      final TextPainter date = _textPainter(
        formatExportDate(decorationState.displayDate),
        TextStyle(
          fontSize: dateFontSize,
          fontWeight: FontWeight.w600,
          color: ink.withValues(alpha: 0.75),
          letterSpacing: 2,
        ),
      );
      // Position the date just below the wordmark block.
      date.paint(
        canvas,
        Offset(
          footer.center.dx - date.width / 2,
          footer.center.dy + 24,
        ),
      );
    }
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
