import 'dart:ui' as ui;

import 'deco_shapes.dart';

/// Scatters blossoms and hearts along a frame rail.
///
/// Called as a repeated painter (one shape per call site) so the caller decides
/// the spacing. The `seed` varies the shape slightly so a run of petals is not
/// mechanically identical, while staying fully deterministic.
class PetalPainter {
  const PetalPainter({required this.color, required this.seed});

  final ui.Color color;
  final int seed;

  void paint(ui.Canvas canvas, ui.Offset center, double size) {
    if (size <= 0) return;
    // Alternate blossom and heart so the rail has two motifs.
    if ((seed + center.dx.round() + center.dy.round()) % 3 == 0) {
      Deco.heart(canvas, center, size, color);
    } else {
      Deco.blossom(canvas, center, size, color);
    }
  }
}

/// Deterministic confetti scatter across a rect.
///
/// The positions come from a seeded [DecoRandom] iterated in a fixed order, so
/// the same rect and seed always yield the same confetti - essential because
/// the Decorate preview and the PNG renderer both call this.
class ConfettiPainter {
  const ConfettiPainter({required this.rect, required this.seed});

  final ui.Rect rect;
  final int seed;

  void paint(ui.Canvas canvas) {
    if (rect.width <= 0 || rect.height <= 0) return;
    final DecoRandom random = DecoRandom(seed);
    final List<ui.Color> colors = <ui.Color>[
      const ui.Color(0xFFFF5D8F),
      const ui.Color(0xFF5AC8FA),
      const ui.Color(0xFFFFD759),
      const ui.Color(0xFF7ED957),
      const ui.Color(0xFFC08BFF),
    ];

    // Density scales with area but is capped so a very tall strip does not
    // become an unreadable mess of confetti.
    final int count = (rect.width * rect.height / 24000).clamp(12, 90).round();
    final double maxSize = _mathMin(rect.width, rect.height) * 0.012;

    for (int i = 0; i < count; i++) {
      final double x = random.range(rect.left, rect.right);
      final double y = random.range(rect.top, rect.bottom);
      final double size = random.range(maxSize * 0.6, maxSize);
      final double angle = random.range(0, 6.2832);
      final ui.Color color = colors[i % colors.length];

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      // Alternate a rectangle and a disc.
      if (i.isEven) {
        canvas.drawRect(
          ui.Rect.fromCenter(
            center: ui.Offset.zero,
            width: size,
            height: size * 0.45,
          ),
          ui.Paint()..color = color,
        );
      } else {
        canvas.drawCircle(ui.Offset.zero, size * 0.35, ui.Paint()..color = color);
      }
      canvas.restore();
    }
  }
}

double _mathMin(double a, double b) => a < b ? a : b;