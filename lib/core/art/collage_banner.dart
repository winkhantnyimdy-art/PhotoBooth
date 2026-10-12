import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Layered scrapbook "photo collage" banner for Home: a film strip with
/// sprockets next to three tilted paper cards with pastel photo blocks.
/// Purely decorative, matching the reference's collage direction.
class CollageBanner extends StatelessWidget {
  const CollageBanner({super.key, this.height = 128});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Scrapbook photo collage preview',
      image: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.surfaceMuted.withValues(alpha: 0.6),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
          ),
          child: CustomPaint(
            size: Size.infinite,
            painter: const _CollageBannerPainter(),
          ),
        ),
      ),
    );
  }
}

class _CollageBannerPainter extends CustomPainter {
  const _CollageBannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double h = size.height;
    final double w = size.width;
    if (w <= 0 || h <= 0) return;

    // --- 1. Film strip on the left ----------------------------------------
    final Rect film = Rect.fromLTWH(w * 0.035, h * 0.12, w * 0.16, h * 0.76);
    final RRect filmRR = RRect.fromRectAndRadius(film, Radius.circular(6));
    canvas.drawRRect(filmRR, Paint()..color = AppColors.popNavy);
    // Sprocket holes.
    final Paint hole = Paint()..color = AppColors.surface;
    for (double y = film.top + 8; y < film.bottom - 6; y += h * 0.115) {
      canvas.drawCircle(Offset(film.left + film.width * 0.30, y), 2.2, hole);
      canvas.drawCircle(Offset(film.right - film.width * 0.30, y), 2.2, hole);
    }
    // A little cut-out film tab, pink.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(film.left - 2, film.bottom - h * 0.14, film.width + 4, h * 0.09),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.hotPink,
    );
    // Cream film inner window with a miniature photo.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(film.left + 3, film.top + 6, film.width - 6, film.height - 12),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.surfaceMuted,
    );

    // --- 2. Tilted polaroid cards -----------------------------------------
    final double cardH = h * 0.52;
    final double cardW = w * 0.30;
    _drawPolaroid(
      canvas,
      Rect.fromLTWH(w * 0.26, h * 0.30, cardW, cardH),
      rotation: -0.12,
      photo: (Canvas c, Rect r) {
        c.drawRect(r, Paint()..color = AppColors.popBlue.withValues(alpha: 0.55));
        c.drawCircle(
          Offset(r.left + r.width * 0.3, r.top + r.height * 0.3),
          r.shortestSide * 0.18,
          Paint()..color = AppColors.popYellow,
        );
      },
      captionColor: AppColors.accentSoft,
    );

    _drawPolaroid(
      canvas,
      Rect.fromLTWH(w * 0.38, h * 0.16, w * 0.34, cardH * 1.18),
      rotation: 0.045,
      photo: (Canvas c, Rect r) {
        final double cell = r.width / 2;
        final List<Color> tints = <Color>[
          AppColors.accentSoft,
          AppColors.popBlue.withValues(alpha: 0.5),
          AppColors.surfaceMuted,
          AppColors.popYellow.withValues(alpha: 0.5),
        ];
        for (int i = 0; i < 2; i++) {
          for (int j = 0; j < 2; j++) {
            c.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  r.left + i * cell + 2,
                  r.top + j * cell + 2,
                  cell - 4,
                  cell - 4,
                ),
                const Radius.circular(2.5),
              ),
              Paint()..color = tints[i * 2 + j],
            );
          }
        }
      },
      captionColor: AppColors.popPink.withValues(alpha: 0.4),
    );

    _drawPolaroid(
      canvas,
      Rect.fromLTWH(w * 0.60, h * 0.40, cardW * 0.92, cardH * 0.8),
      rotation: -0.05,
      photo: (Canvas c, Rect r) {
        c.drawRect(r, Paint()..color = AppColors.popPink.withValues(alpha: 0.28));
        // Film-edge notches along the bottom of this "photo".
        for (double x = r.left + 4; x < r.right - 4; x += r.width / 9) {
          c.drawCircle(Offset(x, r.bottom - 3), 1.8, Paint()..color = AppColors.popInk);
        }
      },
      captionColor: AppColors.popBlue.withValues(alpha: 0.35),
    );

    // --- 3. Tape + tiny doodles for scrapbook feel -------------------------
    canvas.save();
    canvas.translate(w * 0.52, h * 0.06);
    canvas.rotate(0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-w * 0.07, -3, w * 0.14, 8), const Radius.circular(2)),
      Paint()..color = AppColors.crownGold.withValues(alpha: 0.85),
    );
    canvas.restore();

    canvas.drawCircle(
      Offset(w * 0.09, h * 0.90),
      2.6,
      Paint()..color = AppColors.hotPink,
    );
    canvas.drawCircle(
      Offset(w * 0.97, h * 0.14),
      2.2,
      Paint()..color = AppColors.crownGold,
    );
  }

  void _drawPolaroid(
    Canvas canvas,
    Rect card,
    {required double rotation,
    required void Function(Canvas, Rect) photo,
    required Color captionColor}) {
    canvas.save();
    canvas.translate(card.center.dx, card.center.dy);
    canvas.rotate(rotation);
    final Rect r = Rect.fromCenter(center: Offset.zero, width: card.width, height: card.height);

    // Soft drop shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.translate(1.5, 4), const Radius.circular(7)),
      Paint()..color = AppColors.popInk.withValues(alpha: 0.14),
    );
    // Paper card.
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(7)),
      Paint()..color = AppColors.surface,
    );
    // Photo window.
    final Rect photoR = Rect.fromLTWH(
      r.left + r.width * 0.06,
      r.top + r.width * 0.06,
      r.width * 0.88,
      r.height - r.width * 0.20,
    );
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(photoR, const Radius.circular(4)),
    );
    photo(canvas, photoR);
    canvas.restore();
    // Caption bar.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          r.left + r.width * 0.18,
          r.bottom - r.width * 0.22,
          r.width * 0.64,
          r.width * 0.09,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = captionColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CollageBannerPainter oldDelegate) => false;
}