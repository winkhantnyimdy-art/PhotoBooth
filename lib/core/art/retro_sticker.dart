import 'package:flutter/material.dart';

import '../../features/decorate/decoration_model.dart';
import 'retro_artwork.dart';

/// Paints one Retro Pop decal.
///
/// Delegates straight to [RetroArtwork], so a sticker looks identical in the
/// picker, in the live composition preview and in the exported PNG.
class RetroStickerPainter extends CustomPainter {
  const RetroStickerPainter({
    required this.type,
    required this.size,
    this.rotation = 0,
  });

  final StickerType type;

  /// Overall sticker height in logical pixels.
  final double size;

  /// Playful tilt in radians — the reference never places a sticker dead flat.
  final double rotation;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final Offset center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    if (rotation != 0) {
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(rotation)
        ..translate(-center.dx, -center.dy);
    }
    RetroArtwork.paintSticker(canvas, type, center, size);
    if (rotation != 0) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RetroStickerPainter old) =>
      old.type != type || old.size != size || old.rotation != rotation;
}

/// A single Retro Pop sticker, centred in the space it is given.
class RetroSticker extends StatelessWidget {
  const RetroSticker({
    super.key,
    required this.type,
    this.size = 24,
    this.rotation = 0,
  });

  final StickerType type;
  final double size;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: RetroStickerPainter(type: type, size: size, rotation: rotation),
      ),
    );
  }
}

/// Paints a whole list of placed stickers over a composition.
///
/// Coordinate mapping is identical to the exporter: `x` spans the strip width
/// and `y` spans the photo-grid height only (never the caption band), so a
/// sticker never drifts between the preview and the saved PNG.
class RetroStickerLayerPainter extends CustomPainter {
  const RetroStickerLayerPainter({
    required this.stickers,
    required this.gridHeight,
    required this.size,
  });

  final List<StickerPlacement> stickers;

  /// Height of the photo-grid area in the target's coordinate space.
  final double gridHeight;

  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final StickerPlacement sticker in stickers) {
      RetroArtwork.paintSticker(
        canvas,
        sticker.type,
        Offset(sticker.x * canvasSize.width, sticker.y * gridHeight),
        size,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RetroStickerLayerPainter old) =>
      old.gridHeight != gridHeight ||
      old.size != size ||
      !identical(old.stickers, stickers);
}
