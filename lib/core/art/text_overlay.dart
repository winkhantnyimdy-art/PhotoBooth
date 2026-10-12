import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../features/decorate/decoration_model.dart';

/// Draws user captions identically on the Decorate preview and the export.
///
/// Both surfaces route through [paintCentered], so a caption cannot drift
/// between what the user sees and what is saved.
abstract final class TextOverlayRenderer {
  /// Font size for [placement] on a strip [stripWidth] logical pixels wide.
  static double fontSizeFor(TextPlacement placement, double stripWidth) =>
      placement.scale * stripWidth;

  /// The fill type for [placement].
  static TextStyle styleFor(TextPlacement placement, double stripWidth) {
    return TextStyle(
      fontSize: fontSizeFor(placement, stripWidth),
      fontWeight: FontWeight.w800,
      color: placement.color,
      height: 1.12,
      letterSpacing: 0.4,
    );
  }

  /// A contrasting outline colour so text stays legible over any photo.
  static Color _haloColor(Color fill) =>
      fill.computeLuminance() > 0.5
          ? const Color(0xCC201C20)
          : const Color(0xE6FFFFFF);

  static TextPainter _layout(
    TextPlacement placement,
    double stripWidth,
    TextStyle style,
  ) {
    return TextPainter(
      text: TextSpan(text: placement.text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
    )..layout();
  }

  /// The on-strip bounding box of [placement], centre-anchored at its position.
  static Size measure(TextPlacement placement, double stripWidth) {
    if (placement.text.trim().isEmpty) return Size.zero;
    final TextPainter fill = _layout(
      placement,
      stripWidth,
      styleFor(placement, stripWidth),
    );
    return Size(fill.width + 12, fill.height + 10);
  }

  /// Paints [placement] centred inside [box] using [stripWidth] for sizing.
  static void paintCentered(
    ui.Canvas canvas,
    TextPlacement placement,
    double stripWidth,
    ui.Rect box,
  ) {
    if (placement.text.trim().isEmpty) return;

    final TextPainter halo = _layout(
      placement,
      stripWidth,
      styleFor(placement, stripWidth).copyWith(
        color: _haloColor(placement.color),
        fontWeight: FontWeight.w900,
        letterSpacing: 2.6,
      ),
    );
    final TextPainter fill = _layout(
      placement,
      stripWidth,
      styleFor(placement, stripWidth),
    );

    final double left = box.left + ((box.width - fill.width) / 2);
    final double top = box.top + ((box.height - fill.height) / 2);
    halo.paint(canvas, ui.Offset(left - 1, top - 1));
    fill.paint(canvas, ui.Offset(left, top));
  }

  /// Paints [placement] at its normalised position within [stripSize].
  ///
  /// This is the exporter entry point; the preview positions a widget instead
  /// and calls [paintCentered] with the widget's own box.
  static void paint(
    ui.Canvas canvas,
    TextPlacement placement,
    ui.Size stripSize,
  ) {
    if (placement.text.trim().isEmpty) return;
    final Size measured = measure(placement, stripSize.width);
    final ui.Rect box = ui.Rect.fromCenter(
      center: ui.Offset(
        placement.x * stripSize.width,
        placement.y * stripSize.height,
      ),
      width: measured.width,
      height: measured.height,
    );
    paintCentered(canvas, placement, stripSize.width, box);
  }
}

/// Paints a single caption for the live preview, sharing the export painter.
class TextOverlay extends StatelessWidget {
  const TextOverlay({
    super.key,
    required this.placement,
    required this.stripWidth,
  });

  final TextPlacement placement;
  final double stripWidth;

  @override
  Widget build(BuildContext context) {
    final Size size = TextOverlayRenderer.measure(placement, stripWidth);
    return CustomPaint(
      size: size,
      painter: _TextOverlayPainter(
        placement: placement,
        stripWidth: stripWidth,
      ),
    );
  }
}

class _TextOverlayPainter extends CustomPainter {
  const _TextOverlayPainter({required this.placement, required this.stripWidth});

  final TextPlacement placement;
  final double stripWidth;

  @override
  void paint(Canvas canvas, Size size) {
    TextOverlayRenderer.paintCentered(
      canvas,
      placement,
      stripWidth,
      Offset.zero & size,
    );
  }

  @override
  bool shouldRepaint(covariant _TextOverlayPainter old) =>
      old.placement != placement || old.stripWidth != stripWidth;
}
