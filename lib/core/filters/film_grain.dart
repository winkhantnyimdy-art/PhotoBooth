import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Procedural film grain, shared by the Decorate preview and the PNG export.
///
/// The noise is generated from a fixed seed, so the same inputs always produce
/// the same grain on screen and on the printed strip. At intensity 0 nothing is
/// painted at all, which is what lets "strength 0 == Original" hold for the
/// Film Grain preset.
abstract final class FilmGrain {
  /// Mixes light and dark specks, the way silver-halide grain reads on print.
  static void paint(
    ui.Canvas canvas,
    ui.Rect area,
    double intensity, {
    int seed = 0,
  }) {
    final double amount = intensity.clamp(0.0, 1.0);
    if (amount <= 0 || area.isEmpty) return;

    // Density tracks area but is capped so large cells never stall a frame.
    final int specks = ((area.width * area.height) / 220)
        .round()
        .clamp(0, 2600);
    if (specks == 0) return;

    final math.Random random = math.Random(0x5EED + seed);
    final ui.Paint light = ui.Paint()
      ..style = ui.PaintingStyle.fill
      ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.10 * amount);
    final ui.Paint dark = ui.Paint()
      ..style = ui.PaintingStyle.fill
      ..color = const ui.Color(0xFF000000).withValues(alpha: 0.12 * amount);

    for (int i = 0; i < specks; i++) {
      final double dx = area.left + (random.nextDouble() * area.width);
      final double dy = area.top + (random.nextDouble() * area.height);
      final double radius = 0.5 + (random.nextDouble() * 0.9);
      canvas.drawCircle(
        ui.Offset(dx, dy),
        radius,
        random.nextBool() ? light : dark,
      );
    }
  }
}

/// Paints [FilmGrain] over a region — the preview half of the shared effect.
class FilmGrainOverlay extends StatelessWidget {
  const FilmGrainOverlay({
    super.key,
    required this.intensity,
    this.seed = 0,
  });

  final double intensity;
  final int seed;

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FilmGrainPainter(intensity: intensity, seed: seed),
      ),
    );
  }
}

class _FilmGrainPainter extends CustomPainter {
  const _FilmGrainPainter({required this.intensity, required this.seed});

  final double intensity;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    FilmGrain.paint(
      canvas,
      Offset.zero & size,
      intensity,
      seed: seed,
    );
  }

  @override
  bool shouldRepaint(covariant _FilmGrainPainter old) =>
      old.intensity != intensity || old.seed != seed;
}
