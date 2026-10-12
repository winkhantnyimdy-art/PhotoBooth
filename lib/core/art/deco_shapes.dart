import 'dart:math' as math;
import 'dart:ui' as ui;

/// Deterministic decorative primitives shared by the frame themes.
///
/// Everything here is driven by an explicit `seed` and fixed iteration order, so
/// a theme paints identically on the Decorate preview and in the exported PNG.
/// Nothing reads `Random()` without a seed, and nothing samples the clock: a
/// re-render of the same composition must produce the same pixels.
abstract final class Deco {
  /// A five-petal blossom used by the Cherry Blossom and Kawaii themes.
  static void blossom(
    ui.Canvas canvas,
    ui.Offset center,
    double radius,
    ui.Color color,
  ) {
    final ui.Paint paint = ui.Paint()..color = color;
    for (int i = 0; i < 5; i++) {
      final double a = -math.pi / 2 + i * (2 * math.pi / 5);
      final ui.Offset petalCenter =
          center + ui.Offset(radius * 0.62 * math.cos(a), radius * 0.62 * math.sin(a));
      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(a + math.pi / 2);
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: ui.Offset.zero,
          width: radius * 0.86,
          height: radius * 1.15,
        ),
        paint,
      );
      canvas.restore();
    }
    canvas.drawCircle(center, radius * 0.3, paint);
  }

  /// A small heart, used by the Kawaii theme.
  static void heart(
    ui.Canvas canvas,
    ui.Offset center,
    double size,
    ui.Color color,
  ) {
    final ui.Paint paint = ui.Paint()..color = color;
    final double w = size * 0.92;
    final double h = size;
    canvas.drawCircle(
      center.translate(-w * 0.25, -h * 0.18),
      w * 0.3,
      paint,
    );
    canvas.drawCircle(
      center.translate(w * 0.25, -h * 0.18),
      w * 0.3,
      paint,
    );
    final ui.Path tip = ui.Path()
      ..moveTo(center.dx - w * 0.54, center.dy - h * 0.06)
      ..lineTo(center.dx + w * 0.54, center.dy - h * 0.06)
      ..lineTo(center.dx, center.dy + h * 0.5)
      ..close();
    canvas.drawPath(tip, paint);
  }

  /// A four-point sparkle.
  static void sparkle(
    ui.Canvas canvas,
    ui.Offset center,
    double radius,
    ui.Color color,
  ) {
    final ui.Path path = ui.Path();
    for (int i = 0; i < 8; i++) {
      final double r = i.isEven ? radius : radius * 0.28;
      final double a = -math.pi / 2 + i * math.pi / 4;
      final ui.Offset p = center + ui.Offset(r * math.cos(a), r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, ui.Paint()..color = color);
  }
}

/// A small deterministic value generator.
///
/// Seeded from a caller-supplied integer so a given composition always produces
/// the same scatter, which is what keeps the preview and the export identical.
class DecoRandom {
  DecoRandom(int seed) : _state = (seed == 0 ? 0x9E3779B9 : seed) & 0x7FFFFFFF;

  int _state;

  /// Next value in `[0, 1)`.
  double next() {
    // xorshift32: tiny, deterministic and dependency-free.
    _state ^= (_state << 13) & 0x7FFFFFFF;
    _state ^= _state >> 17;
    _state ^= (_state << 5) & 0x7FFFFFFF;
    if (_state <= 0) _state = 0x9E3779B9;
    return _state / 0x7FFFFFFF;
  }

  double range(double min, double max) => min + next() * (max - min);
}