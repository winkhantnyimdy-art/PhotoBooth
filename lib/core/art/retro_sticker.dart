import 'package:flutter/material.dart';

import '../../features/decorate/decoration_model.dart';
import 'sticker_artwork.dart';

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
        painter: _StickerPainter(type: type, size: size, rotation: rotation),
      ),
    );
  }
}

class _StickerPainter extends CustomPainter {
  const _StickerPainter({required this.type, required this.size, required this.rotation});

  final StickerType type;
  final double size;
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
    StickerArtwork.paintSticker(canvas, type, center, size);
    if (rotation != 0) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StickerPainter old) =>
      old.type != type || old.size != size || old.rotation != rotation;
}

class RetroStickerLayerPainter extends CustomPainter {
  const RetroStickerLayerPainter({
    required this.stickers,
    required this.gridHeight,
    required this.size,
  });

  final List<StickerPlacement> stickers;
  final double gridHeight;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final StickerPlacement sticker in stickers) {
      StickerArtwork.paintSticker(
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
