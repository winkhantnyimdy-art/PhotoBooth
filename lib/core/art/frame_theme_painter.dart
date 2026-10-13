import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../features/decorate/frame_theme.dart';
import '../theme/app_colors.dart';
import 'deco_scatter.dart';

/// Paints a [FrameTheme]'s complete chrome: paper, border artwork, corner
/// accents and the footer wordmark.
///
/// Every theme draws its own border and accents rather than tinting a shared
/// one, which is what makes them read as distinct identities instead of
/// recoloured variants. All sizes derive from [rect], so the artwork is
/// proportional in the Decorate preview and at full export resolution.
///
/// ## Z-order contract
///
/// [paint] fills the **whole** rect with opaque paper before drawing the
/// border, so it must always be the *first* thing drawn for a composition -
/// exactly as `PhotoStripRenderer` does it. Painting it later buries the photo
/// cells underneath and the strip renders as an empty frame.
///
/// That makes the wordmark a trap: at its default placement it is centred on
/// [rect], i.e. right over the photo grid. Callers that draw their own footer
/// band (the Decorate preview does) pass `includeWordmark: false` so the
/// wordmark is neither painted twice nor painted over the photos.
abstract final class FrameThemePainter {
  /// Paints the theme chrome into [rect].
  ///
  /// [wordmarkSize] is the em size for the footer wordmark; the caller passes
  /// a value appropriate to the canvas it is drawing into.
  ///
  /// [includeWordmark] paints the wordmark centred on [rect]. Pass false when
  /// the caller draws the footer wordmark itself into a dedicated footer band.
  static void paint(
    ui.Canvas canvas,
    ui.Rect rect,
    FrameTheme theme, {
    double wordmarkSize = 36,
    bool includeWordmark = true,
  }) {
    final FrameThemeSpec spec = theme.spec;

    // 1. Paper.
    canvas.drawRect(rect, ui.Paint()..color = spec.paper);

    // 2. Border artwork, per theme.
    switch (theme) {
      case FrameTheme.retroPop:
        _retroPopBorder(canvas, rect, spec);
      case FrameTheme.y2kPop:
        _y2kBorder(canvas, rect, spec);
      case FrameTheme.vintageFilm:
        _vintageFilmBorder(canvas, rect, spec);
      case FrameTheme.cherryBlossom:
        _sakuraBorder(canvas, rect, spec);
      case FrameTheme.kawaii:
        _kawaiiBorder(canvas, rect, spec);
      case FrameTheme.minimalWhite:
        _minimalWhiteBorder(canvas, rect, spec);
      case FrameTheme.darkFilm:
        _darkFilmBorder(canvas, rect, spec);
      case FrameTheme.birthday:
        _birthdayBorder(canvas, rect, spec);
    }

    // 3. Footer wordmark.
    if (includeWordmark) {
      paintWordmark(canvas, rect, theme, wordmarkSize);
    }
  }

  /// Paints just the theme's footer wordmark, centred in [footer].
  static void paintWordmark(
    ui.Canvas canvas,
    ui.Rect footer,
    FrameTheme theme,
    double size,
  ) {
    final FrameThemeSpec spec = theme.spec;
    final TextStyle style = _wordmarkStyle(theme, size);

    final TextPainter halo = _painter(
      spec.wordmark,
      style.copyWith(
        color: spec.onDarkPaper ? const Color(0xFF000000) : AppColors.surface,
        fontSize: size * 1.1,
      ),
    );
    final TextPainter mark = _painter(spec.wordmark, style);

    // The halo gives the wordmark the "sticker" look used across the app.
    halo.paint(
      canvas,
      Offset(footer.center.dx - halo.width / 2, footer.center.dy - halo.height / 2 - 2),
    );
    mark.paint(
      canvas,
      Offset(footer.center.dx - mark.width / 2, footer.center.dy - mark.height / 2),
    );
  }

  static TextStyle _wordmarkStyle(FrameTheme theme, double size) {
    final FrameThemeSpec spec = theme.spec;
    switch (theme) {
      case FrameTheme.retroPop:
        return TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: spec.accent,
          letterSpacing: 3,
        );
      case FrameTheme.y2kPop:
        // Chunky, wide-tracked and letter-spaced like a bubble logo.
        return TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: spec.accent,
          letterSpacing: 8,
        );
      case FrameTheme.vintageFilm:
        return TextStyle(
          fontSize: size * 0.92,
          fontWeight: FontWeight.w700,
          color: spec.ink,
          letterSpacing: 6,
        );
      case FrameTheme.cherryBlossom:
        return TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: spec.ink,
          letterSpacing: 4,
        );
      case FrameTheme.kawaii:
        return TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: spec.accent,
          letterSpacing: 2,
        );
      case FrameTheme.minimalWhite:
        // Small caps, wide tracking, quiet.
        return TextStyle(
          fontSize: size * 0.72,
          fontWeight: FontWeight.w500,
          color: spec.secondary,
          letterSpacing: 10,
        );
      case FrameTheme.darkFilm:
        return TextStyle(
          fontSize: size * 0.8,
          fontWeight: FontWeight.w700,
          color: spec.ink,
          letterSpacing: 7,
        );
      case FrameTheme.birthday:
        return TextStyle(
          fontSize: size * 0.96,
          fontWeight: FontWeight.w900,
          color: spec.accent,
          letterSpacing: 3,
        );
    }
  }

  static TextPainter _painter(String text, TextStyle style) {
    final TextPainter p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    );
    p.layout();
    return p;
  }

  // ---------------------------------------------------------------------------
  // Borders
  // ---------------------------------------------------------------------------

  static void _retroPopBorder(ui.Canvas canvas, ui.Rect rect, FrameThemeSpec s) {
    final double w = math.max(10, rect.width * 0.026);
    final ui.Paint border = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = w
      ..color = s.accent;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect.deflate(w / 2), const ui.Radius.circular(16)),
      border,
    );

    final ui.Paint dot = ui.Paint()..color = AppColors.surface;
    final double spacing = w * 1.15;
    final double radius = w * 0.22;
    final ui.RRect inner = ui.RRect.fromRectAndRadius(
      rect.deflate(w / 2),
      const ui.Radius.circular(14),
    );
    for (double y = inner.top + spacing / 2; y < inner.bottom; y += spacing) {
      for (double x = inner.left + spacing / 2; x < inner.right; x += spacing) {
        if (inner.contains(ui.Offset(x, y))) {
          canvas.drawCircle(ui.Offset(x, y), radius, dot);
        }
      }
    }
  }

  /// Y2K: a two-tone chrome rail with bubble dots and corner starbursts.
  static void _y2kBorder(ui.Canvas canvas, ui.Rect rect, FrameThemeSpec s) {
    final double w = math.max(14, rect.width * 0.036);

    final ui.Rect band = rect.deflate(w / 2);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(band, const ui.Radius.circular(22)),
      ui.Paint()..color = s.accent,
    );

    // Chrome gradient: a linear sweep from indigo through cyan.
    final ui.Rect inner = band.deflate(w * 0.34);
    canvas.save();
    canvas.clipRRect(ui.RRect.fromRectAndRadius(inner, const ui.Radius.circular(16)));
    final ui.Rect sweep = ui.Rect.fromLTWH(
      inner.left,
      inner.top,
      inner.width,
      inner.height * 0.55,
    );
    canvas.drawRect(
      sweep,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          sweep.topLeft,
          sweep.bottomRight,
          <ui.Color>[s.accent, s.secondary],
        ),
    );
    canvas.restore();

    // Bubble dots along the rail.
    final ui.Paint bubble = ui.Paint()..color = const Color(0xFFFFFFFF);
    final double spacing = w * 1.25;
    final double radius = w * 0.2;
    final ui.Rect track = band.deflate(w * 0.17);
    for (double x = track.left + spacing / 2; x < track.right; x += spacing) {
      canvas.drawCircle(ui.Offset(x, rect.top + w * 0.17), radius, bubble);
      canvas.drawCircle(ui.Offset(x, rect.bottom - w * 0.17), radius, bubble);
    }
    for (double y = track.top + spacing / 2; y < track.bottom; y += spacing) {
      canvas.drawCircle(ui.Offset(rect.left + w * 0.17, y), radius, bubble);
      canvas.drawCircle(ui.Offset(rect.right - w * 0.17, y), radius, bubble);
    }

    // Four-point starbursts in the corners.
    _starburst(canvas, rect.topLeft.translate(w * 0.6, w * 0.6), w * 0.42, s.secondary);
    _starburst(canvas, rect.topRight.translate(-w * 0.6, w * 0.6), w * 0.42, s.secondary);
    _starburst(canvas, rect.bottomLeft.translate(w * 0.6, -w * 0.6), w * 0.42, s.secondary);
    _starburst(canvas, rect.bottomRight.translate(-w * 0.6, -w * 0.6), w * 0.42, s.secondary);
  }

  /// Vintage Film: warm rails, sprocket holes and an orange date stamp.
  static void _vintageFilmBorder(ui.Canvas canvas, ui.Rect rect, FrameThemeSpec s) {
    final double rail = math.max(10, rect.width * 0.03);
    final ui.Paint railPaint = ui.Paint()..color = s.ink;

    canvas.drawRect(
      ui.Rect.fromLTWH(rect.left, rect.top, rail, rect.height),
      railPaint,
    );
    canvas.drawRect(
      ui.Rect.fromLTWH(rect.right - rail, rect.top, rail, rect.height),
      railPaint,
    );

    // Sprocket holes.
    final ui.Paint hole = ui.Paint()..color = s.paper;
    final double holeSize = rail * 0.46;
    final double step = holeSize * 2.6;
    for (double y = rect.top + step; y < rect.bottom - step; y += step) {
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromCenter(
            center: ui.Offset(rect.left + rail / 2, y),
            width: holeSize,
            height: holeSize,
          ),
          ui.Radius.circular(holeSize * 0.22),
        ),
        hole,
      );
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromCenter(
            center: ui.Offset(rect.right - rail / 2, y),
            width: holeSize,
            height: holeSize,
          ),
          ui.Radius.circular(holeSize * 0.22),
        ),
        hole,
      );
    }

    // Corner wear marks, like an aged print.
    final ui.Paint wear = ui.Paint()
      ..color = s.secondary.withValues(alpha: 0.5)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = rail * 0.12;
    for (final ui.Offset corner in <ui.Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawArc(
        ui.Rect.fromCircle(center: corner, radius: rail * 2.2),
        0,
        math.pi * 2,
        false,
        wear,
      );
    }
  }

  /// Cherry Blossom: sakura petals drifting across a soft pink rail.
  static void _sakuraBorder(ui.Canvas canvas, ui.Rect rect, FrameThemeSpec s) {
    final double w = math.max(12, rect.width * 0.03);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(18)),
      ui.Paint()..color = s.accent.withValues(alpha: 0.55),
    );

    final ui.RRect inner = ui.RRect.fromRectAndRadius(
      rect.deflate(w * 0.6),
      const ui.Radius.circular(14),
    );
    canvas.drawRRect(inner, ui.Paint()..color = s.paper);

    // Petals scattered along the rail. Fixed positions (not random) so the
    // preview and the export are identical.
    final PetalPainter petals = PetalPainter(
      color: s.accent,
      seed: rect.width.round(),
    );
    final double step = w * 1.5;
    for (double x = rect.left + step / 2; x < rect.right; x += step) {
      petals.paint(canvas, ui.Offset(x, rect.top + w / 2), w * 0.34);
      petals.paint(canvas, ui.Offset(x + step / 2, rect.bottom - w / 2), w * 0.3);
    }
    for (double y = rect.top + step / 2; y < rect.bottom; y += step) {
      petals.paint(canvas, ui.Offset(rect.left + w / 2, y), w * 0.32);
      petals.paint(canvas, ui.Offset(rect.right - w / 2, y + step / 2), w * 0.28);
    }

    // A small sprig in the top-right corner.
    _sprig(canvas, rect.topRight.translate(-w * 1.6, w * 1.6), w * 1.4, s.secondary);
  }

  /// Kawaii: pastel scallops, a soft inner glow and tiny hearts.
  static void _kawaiiBorder(ui.Canvas canvas, ui.Rect rect, FrameThemeSpec s) {
    final double band = math.max(12, rect.width * 0.032);
    canvas.drawPath(
      ui.Path()
        ..addRRect(ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(20)))
        ..addRRect(
          ui.RRect.fromRectAndRadius(
            rect.deflate(band),
            const ui.Radius.circular(16),
          ),
        )
        ..fillType = ui.PathFillType.evenOdd,
      ui.Paint()..color = s.accent,
    );

    final ui.Paint cut = ui.Paint()..color = s.paper;
    final double radius = band * 0.38;
    final double spacing = radius * 2.6;
    for (double x = rect.left + spacing; x < rect.right - spacing; x += spacing) {
      canvas.drawCircle(ui.Offset(x, rect.top + band / 2), radius, cut);
      canvas.drawCircle(ui.Offset(x, rect.bottom - band / 2), radius, cut);
    }
    for (double y = rect.top + spacing; y < rect.bottom - spacing; y += spacing) {
      canvas.drawCircle(ui.Offset(rect.left + band / 2, y), radius, cut);
      canvas.drawCircle(ui.Offset(rect.right - band / 2, y), radius, cut);
    }

    // Tiny hearts along the band.
    final PetalPainter hearts = PetalPainter(
      color: s.secondary,
      seed: rect.width.round() + 7,
    );
    final double hstep = spacing * 2;
    for (double x = rect.left + hstep / 2; x < rect.right; x += hstep) {
      hearts.paint(canvas, ui.Offset(x, rect.top + band * 2.1), band * 0.22);
      hearts.paint(canvas, ui.Offset(x + hstep / 2, rect.bottom - band * 2.1), band * 0.2);
    }
  }

  /// Minimal White: a hairline rule and nothing else.
  static void _minimalWhiteBorder(ui.Canvas canvas, ui.Rect rect, FrameThemeSpec s) {
    final double w = math.max(1.5, rect.width * 0.0022);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        rect.deflate(w),
        const ui.Radius.circular(2),
      ),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = w
        ..color = s.accent,
    );
    // A single short accent rule, top-left, to break the emptiness.
    final double len = math.max(18, rect.width * 0.06);
    canvas.drawLine(
      ui.Offset(rect.left + w * 6, rect.top + w * 6),
      ui.Offset(rect.left + w * 6 + len, rect.top + w * 6),
      ui.Paint()
        ..strokeWidth = w * 3
        ..strokeCap = ui.StrokeCap.round
        ..color = s.secondary,
    );
  }

  /// Dark Film: black paper, thin light rail and amber corner marks.
  static void _darkFilmBorder(ui.Canvas canvas, ui.Rect rect, FrameThemeSpec s) {
    final double w = math.max(6, rect.width * 0.014);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        rect.deflate(w / 2),
        const ui.Radius.circular(6),
      ),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = w
        ..color = s.ink.withValues(alpha: 0.55),
    );

    // Sprocket teeth along the very edge.
    final ui.Paint tooth = ui.Paint()..color = s.secondary.withValues(alpha: 0.75);
    final double toothH = w * 0.9;
    final double step = w * 1.5;
    for (double y = rect.top + step; y < rect.bottom - step; y += step) {
      canvas.drawRect(
        ui.Rect.fromLTWH(rect.left + w * 0.15, y - toothH / 2, w * 0.5, toothH),
        tooth,
      );
      canvas.drawRect(
        ui.Rect.fromLTWH(rect.right - w * 0.65, y - toothH / 2, w * 0.5, toothH),
        tooth,
      );
    }

    // Amber registration marks in the corners.
    final ui.Paint mark = ui.Paint()
      ..color = s.accent
      ..strokeWidth = w * 0.6
      ..strokeCap = ui.StrokeCap.square;
    final double len = math.max(14, rect.width * 0.05);
    const double inset = 10;
    final List<ui.Offset> corners = <ui.Offset>[
      ui.Offset(rect.left + inset, rect.top + inset),
      ui.Offset(rect.right - inset, rect.top + inset),
      ui.Offset(rect.left + inset, rect.bottom - inset),
      ui.Offset(rect.right - inset, rect.bottom - inset),
    ];
    for (final ui.Offset c in corners) {
      canvas.drawLine(c, c.translate(len, 0), mark);
      canvas.drawLine(c, c.translate(0, len), mark);
    }
  }

  /// Birthday: bunting across the top and confetti over the paper.
  static void _birthdayBorder(ui.Canvas canvas, ui.Rect rect, FrameThemeSpec s) {
    final double w = math.max(12, rect.width * 0.03);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(18)),
      ui.Paint()..color = s.accent,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        rect.deflate(w),
        const ui.Radius.circular(14),
      ),
      ui.Paint()..color = s.paper,
    );

    // Bunting: a catenary of alternating triangles just inside the top rail.
    final double flagW = w * 1.5;
    final double flagH = w * 1.25;
    final double sag = w * 0.9;
    final List<Color> flagColors = <Color>[
      s.accent,
      s.secondary,
      const Color(0xFFFFD759),
      const Color(0xFF7ED957),
      const Color(0xFFC08BFF),
    ];
    final double usable = rect.width - w * 2;
    final int count = math.max(4, (usable / flagW).floor());
    final double spacing = usable / count;
    for (int i = 0; i < count; i++) {
      final double t = count == 1 ? 0.5 : i / (count - 1);
      // Parabolic sag across the width.
      final double y = rect.top + w + sag * (1 - 4 * (t - 0.5) * (t - 0.5));
      final double x = rect.left + w + (i * spacing);
      final ui.Path flag = ui.Path()
        ..moveTo(x, y)
        ..lineTo(x + spacing * 0.86, y)
        ..lineTo(x + spacing * 0.43, y + flagH)
        ..close();
      canvas.drawPath(flag, ui.Paint()..color = flagColors[i % flagColors.length]);
    }

    // Confetti on the paper.
    final ConfettiPainter confetti = ConfettiPainter(
      rect: rect.deflate(w),
      seed: rect.width.round(),
    );
    confetti.paint(canvas);
  }

  // ---------------------------------------------------------------------------
  // Accent helpers
  // ---------------------------------------------------------------------------

  static void _starburst(
    ui.Canvas canvas,
    ui.Offset center,
    double radius,
    Color color,
  ) {
    final ui.Path path = ui.Path();
    const int spikes = 4;
    for (int i = 0; i < spikes * 2; i++) {
      final double r = i.isEven ? radius : radius * 0.32;
      final double a = -math.pi / 2 + i * math.pi / spikes;
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

  static void _sprig(
    ui.Canvas canvas,
    ui.Offset origin,
    double size,
    Color color,
  ) {
    final ui.Paint stem = ui.Paint()
      ..color = color
      ..strokeWidth = size * 0.09
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round;
    canvas.drawLine(origin, origin.translate(-size, -size * 0.8), stem);
    final PetalPainter petals = PetalPainter(color: color, seed: 11);
    for (int i = 1; i <= 3; i++) {
      final double t = i / 4;
      petals.paint(
        canvas,
        origin.translate(-size * t, -size * 0.8 * t),
        size * 0.2,
      );
    }
  }
}