import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'photo_filter.dart';

/// The PhotoBooth V3 effect collection.
///
/// Exactly fifteen effects with stable string identifiers. The enum's [name] is
/// what gets persisted in album records, so these names must never change;
/// display [label]s may.
///
/// ## A note on honesty
///
/// These are **digital simulations**. Every effect is a colour matrix plus, for
/// some, deterministic procedural grain and a screen-blended bloom pass. None
/// of them is scanned film stock, and they are not represented as such in the
/// UI.
enum PhotoEffect {
  // --- Essentials -----------------------------------------------------------
  original('Original'),
  soft('Soft'),
  warm('Warm'),
  cool('Cool'),

  // --- Film -----------------------------------------------------------------
  mm35('35mm'),
  vintage('Vintage'),
  grain('Grain'),
  faded('Faded'),
  classicFilm('Classic Film'),

  // --- Digital --------------------------------------------------------------
  y2kFlash('Y2K Flash'),
  ccd('CCD'),
  tokyoNight('Tokyo Night'),

  // --- Artistic -------------------------------------------------------------
  mono('Mono'),
  noir('Noir'),
  dreamy('Dreamy');

  const PhotoEffect(this.label);

  /// Display name shown on the effect shelf.
  final String label;

  /// Stable persisted identifier. Never change an existing value.
  String get id => name;

  /// Whether this effect paints procedural grain over the photo cells.
  bool get hasGrain => grainAmount > 0;

  /// Grain strength at 100 %, 0…1.
  double get grainAmount => switch (this) {
        mm35 => 0.35,
        vintage => 0.55,
        grain => 0.85,
        classicFilm => 0.28,
        _ => 0,
      };

  /// Whether this effect adds a blurred glow pass.
  bool get hasBloom => bloomAmount > 0;

  /// Bloom strength at 100 %, 0…1.
  double get bloomAmount => switch (this) {
        soft => 0.30,
        y2kFlash => 0.55,
        dreamy => 0.80,
        _ => 0,
      };

  /// Blur radius as a fraction of the region's short side, so the glow looks
  /// the same at thumbnail and export resolution.
  double get bloomRadius => switch (this) {
        soft => 0.012,
        y2kFlash => 0.018,
        dreamy => 0.030,
        _ => 0,
      };

  /// The fully-applied 4x5 colour matrix for this effect.
  ///
  /// Every value is composed from the shared [ColorMatrix] primitives, so the
  /// maths stays in one place and the ordering of operations is explicit.
  List<double> get matrix => switch (this) {
        PhotoEffect.original => ColorMatrix.identity,

        // Soft: pull contrast in and lift overall, so highlights roll off
        // gently instead of clipping.
        PhotoEffect.soft => ColorMatrix.multiply(
            ColorMatrix.contrast(0.88),
            ColorMatrix.multiply(
              ColorMatrix.brightness(0.045),
              ColorMatrix.saturation(0.94),
            ),
          ),

        // Warm: a plain positive white balance with a touch of saturation.
        PhotoEffect.warm => ColorMatrix.multiply(
            ColorMatrix.temperature(0.34),
            ColorMatrix.multiply(
              ColorMatrix.saturation(1.10),
              ColorMatrix.contrast(1.03),
            ),
          ),

        // Cool: the mirror image of Warm, and deliberately near-neutral so it
        // does not compete with the film presets.
        PhotoEffect.cool => ColorMatrix.multiply(
            ColorMatrix.temperature(-0.32),
            ColorMatrix.multiply(
              ColorMatrix.saturation(1.04),
              ColorMatrix.contrast(1.04),
            ),
          ),

        // 35mm: warm-neutral stock, gently faded contrast, fine grain.
        PhotoEffect.mm35 => ColorMatrix.multiply(
            ColorMatrix.temperature(0.20),
            ColorMatrix.multiply(
              ColorMatrix.contrast(0.94),
              ColorMatrix.multiply(
                ColorMatrix.brightness(0.03),
                ColorMatrix.saturation(0.90),
              ),
            ),
          ),

        // Vintage: sepia-leaning warm shadows with reduced contrast, the
        // recognisable "old print" curve.
        PhotoEffect.vintage => ColorMatrix.multiply(
            ColorMatrix.sepia(0.42),
            ColorMatrix.multiply(
              ColorMatrix.temperature(0.16),
              ColorMatrix.multiply(
                ColorMatrix.contrast(0.82),
                ColorMatrix.saturation(0.80),
              ),
            ),
          ),

        // Grain: near-neutral tone so the noise is the whole signature.
        PhotoEffect.grain => ColorMatrix.multiply(
            ColorMatrix.contrast(1.04),
            ColorMatrix.saturation(0.94),
          ),

        // Faded: raised blacks and a milky, low-saturation curve.
        PhotoEffect.faded => ColorMatrix.multiply(
            ColorMatrix.contrast(0.74),
            ColorMatrix.multiply(
              ColorMatrix.brightness(0.075),
              ColorMatrix.saturation(0.62),
            ),
          ),

        // Classic Film: a balanced analogue curve - warm, slightly lifted
        // blacks, modest saturation, light grain.
        PhotoEffect.classicFilm => ColorMatrix.multiply(
            ColorMatrix.temperature(0.13),
            ColorMatrix.multiply(
              ColorMatrix.contrast(0.88),
              ColorMatrix.multiply(
                ColorMatrix.brightness(0.045),
                ColorMatrix.saturation(0.84),
              ),
            ),
          ),

        // Y2K Flash: blown highlights, cool shadow cast, plus bloom.
        PhotoEffect.y2kFlash => ColorMatrix.multiply(
            ColorMatrix.temperature(-0.10),
            ColorMatrix.multiply(
              ColorMatrix.contrast(1.20),
              ColorMatrix.multiply(
                ColorMatrix.brightness(0.02),
                ColorMatrix.saturation(1.22),
              ),
            ),
          ),

        // CCD: early digital character - punchy contrast with the slight
        // green-cyan bias those sensors had.
        PhotoEffect.ccd => ColorMatrix.multiply(
            ColorMatrix.channelBias(red: 1.04, green: 1.02, blue: 0.95),
            ColorMatrix.multiply(
              ColorMatrix.contrast(1.16),
              ColorMatrix.saturation(1.30),
            ),
          ),

        // Tokyo Night: a cool cinematic base with the cyan/magenta separation
        // the genre is known for.
        PhotoEffect.tokyoNight => ColorMatrix.multiply(
            ColorMatrix.shadowLift(
              shadowColor: const FilterColor(0.10, 0.16, 0.34),
              amount: 0.16,
            ),
            ColorMatrix.multiply(
              ColorMatrix.highlightTint(
                highlightColor: const FilterColor(1.00, 0.62, 0.92),
                amount: 0.20,
              ),
              ColorMatrix.multiply(
                ColorMatrix.temperature(-0.16),
                ColorMatrix.saturation(1.12),
              ),
            ),
          ),

        // Mono: a balanced luminance conversion - equal weight, no crush.
        PhotoEffect.mono => ColorMatrix.multiply(
            ColorMatrix.contrast(1.06),
            ColorMatrix.saturation(0),
          ),

        // Noir: high-contrast monochrome with crushed blacks and bright
        // highlights.
        PhotoEffect.noir => ColorMatrix.multiply(
            ColorMatrix.contrast(1.55),
            ColorMatrix.multiply(
              ColorMatrix.brightness(-0.06),
              ColorMatrix.saturation(0),
            ),
          ),

        // Dreamy: lifted blacks, soft glow, pink-lifted highlights.
        PhotoEffect.dreamy => ColorMatrix.multiply(
            ColorMatrix.pinkTint(0.55),
            ColorMatrix.multiply(
              ColorMatrix.contrast(0.80),
              ColorMatrix.multiply(
                ColorMatrix.brightness(0.06),
                ColorMatrix.saturation(0.92),
              ),
            ),
          ),
      };

  /// Parses a persisted identifier, returning null when unknown.
  static PhotoEffect? tryParse(String id) {
    for (final PhotoEffect effect in PhotoEffect.values) {
      if (effect.name == id) return effect;
    }
    return null;
  }
}

/// A fully-resolved effect, ready to be painted.
///
/// This is the **single description** of "what an effect looks like". The live
/// preview and the PNG exporter both consume this object, which is what makes
/// them agree by construction rather than by coincidence.
class EffectRecipe {
  const EffectRecipe({
    required this.effect,
    required this.intensity,
    required this.matrix,
    required this.grainAmount,
    required this.bloomAmount,
    required this.bloomRadius,
  });

  /// The effect this recipe came from.
  final PhotoEffect effect;

  /// 0…1, already clamped.
  final double intensity;

  /// The 20-value colour matrix, already blended towards identity by
  /// [intensity].
  final List<double> matrix;

  /// 0…1 grain strength, already scaled by [intensity].
  final double grainAmount;

  /// 0…1 bloom strength, already scaled by [intensity].
  final double bloomAmount;

  /// Blur radius as a fraction of the painted region's short side.
  final double bloomRadius;

  /// True when nothing at all needs painting.
  bool get isIdentity =>
      grainAmount <= 0 &&
      bloomAmount <= 0 &&
      ColorMatrix.isIdentity(matrix);

  /// The deterministic grain seed.
  ///
  /// Constant so a given region always receives the same noise pattern. The
  /// previous pipeline seeded the preview with 0 and the export with the
  /// export width, so the two never matched.
  static const int grainSeed = 0x5EED;

  /// Resolves [effect] at [intensity] with optional [adjustments].
  ///
  /// Intensity 0 always resolves to the identity matrix with no grain and no
  /// bloom, so 0 % is exactly Original for every one of the fifteen effects.
  static EffectRecipe resolve(
    PhotoEffect effect,
    double intensity, {
    PhotoAdjustments adjustments = const PhotoAdjustments(),
  }) {
    final double t = intensity.clamp(0.0, 1.0);
    final List<double> blended = ColorMatrix.lerp(
      ColorMatrix.identity,
      effect.matrix,
      t,
    );
    final List<double> finalMatrix = adjustments.isNeutral
        ? blended
        : ColorMatrix.multiply(adjustments.matrix, blended);

    // Effects stack multiplicatively with the manual adjustments: a neutral
    // adjustment must not change the effect at all, so the grain and bloom
    // terms are driven by intensity only.
    return EffectRecipe(
      effect: effect,
      intensity: t,
      matrix: finalMatrix,
      grainAmount: effect.grainAmount * t,
      bloomAmount: effect.bloomAmount * t,
      bloomRadius: effect.bloomRadius,
    );
  }

  /// Blur sigma in logical pixels for a region whose short side is [shortSide].
  ///
  /// Expressed relatively so a 64 px thumbnail and a 576 px export cell get the
  /// same *apparent* glow. Returns 0 when there is no bloom.
  double bloomSigma(double shortSide) {
    if (bloomAmount <= 0 || shortSide <= 0) return 0;
    return bloomRadius * shortSide;
  }

  EffectRecipe copyWith({double? intensity}) {
    return resolve(effect, intensity ?? this.intensity);
  }

  @override
  String toString() =>
      'EffectRecipe(${effect.id}, intensity=${intensity.toStringAsFixed(2)}, '
      'grain=${grainAmount.toStringAsFixed(2)}, bloom=${bloomAmount.toStringAsFixed(2)})';
}

/// Deterministic, scale-normalised film grain.
///
/// ## What this fixes
///
/// The previous grain sized every speck in **absolute pixels** (0.5-1.4 px) and
/// capped the total count at 2600. A 64 px thumbnail and a 576 px export cell
/// therefore showed visibly different noise, and large export regions lost
/// grain density where the cap bit. Everything here is expressed relative to
/// the painted region, and the pattern is seeded deterministically so the
/// preview and the export receive identical noise.
abstract final class EffectGrain {
  /// A value in 0…1, used to keep the maths free of magic numbers.
  static double clamp01(double v) => v.clamp(0.0, 1.0);

  /// Number of specks for a region, scaled by its area and its strength.
  static int speckCount({
    required double width,
    required double height,
    required double amount,
  }) {
    final double area = width * height;
    if (area <= 0 || amount <= 0) return 0;
    // Density is relative to a reference export cell, so the same region at
    // preview and export size yields the same *proportion* of specks.
    const double referenceArea = 576.0 * 768.0;
    const double specksAtFullStrength = 5200.0;
    final double scaled =
        (area / referenceArea) * specksAtFullStrength * clamp01(amount);
    // A ceiling guards very large canvases; below it the ratio stays constant.
    return scaled.round().clamp(0, 24000);
  }

  /// The speck radius for a region, relative to its short side.
  static double speckRadius({
    required double shortSide,
    required double amount,
  }) {
    if (shortSide <= 0 || amount <= 0) return 0;
    // ~0.35 % of the short side: fine enough to read as grain rather than dirt
    // at every resolution.
    final double base = shortSide * 0.0035;
    return base * (0.45 + (0.55 * clamp01(amount)));
  }

  /// Paints grain into [canvas] over [area].
  ///
  /// Shared verbatim by the Decorate preview and the PNG exporter so the two
  /// cannot drift. The noise is seeded from [seed], so identical regions always
  /// receive an identical speck pattern.
  static void paint(
    ui.Canvas canvas,
    ui.Rect area,
    double amount, {
    int seed = 0,
  }) {
    final double a = clamp01(amount);
    if (a <= 0 || area.isEmpty) return;

    final int count = speckCount(
      width: area.width,
      height: area.height,
      amount: a,
    );
    if (count == 0) return;

    final double radius = speckRadius(
      shortSide: math.min(area.width, area.height),
      amount: a,
    );
    if (radius <= 0) return;

    final math.Random random = math.Random(seed);
    // Two populations so the noise reads as silver halide rather than a single
    // colour of dirt.
    _paintSpecks(
      canvas,
      area,
      (count * 0.45).round(),
      random,
      radius,
      // Slightly warm light specks.
      const ui.Color(0xFFF3EADC),
      0.16 * a,
    );
    _paintSpecks(
      canvas,
      area,
      count - (count * 0.45).round(),
      random,
      radius,
      const ui.Color(0xFF14110C),
      0.20 * a,
    );
  }

  static void _paintSpecks(
    ui.Canvas canvas,
    ui.Rect area,
    int count,
    math.Random random,
    double radius,
    ui.Color color,
    double opacity,
  ) {
    if (count <= 0) return;
    final ui.Paint paint = ui.Paint()
      ..isAntiAlias = true
      ..style = ui.PaintingStyle.fill
      ..color = color.withValues(alpha: opacity);
    for (int i = 0; i < count; i++) {
      final double dx = area.left + (random.nextDouble() * area.width);
      final double dy = area.top + (random.nextDouble() * area.height);
      final double r = radius * (0.55 + (random.nextDouble() * 0.9));
      canvas.drawCircle(ui.Offset(dx, dy), r, paint);
    }
  }

  /// Renders a patch of grain into a standalone image.
  ///
  /// Used by the comparison sheets so the contact sheet is produced by the real
  /// painter rather than a re-implementation.
  static Future<ui.Image> renderPatch({
    required int width,
    required int height,
    required double amount,
    int seed = 0,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    paint(
      canvas,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      amount,
      seed: seed,
    );
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  }
}


/// The blurred glow pass shared by the Decorate preview and the PNG exporter.
///
/// ## Why screen blending
///
/// A colour matrix cannot blur, and adding a fragment shader for three effects
/// was not justified. Instead the photo is drawn a second time, blurred, and
/// composited with [BlendMode.screen]. Screen blending is
/// `1 - (1-a)(1-b)`, so a near-black pixel is almost unchanged while
/// highlights lift - which is exactly the glow we want, and it needs no GPU
/// program. Both `Canvas` and the widget tree can express it, so the preview
/// and the export use the same primitive and the same sigma.
///
/// ## Resolution independence
///
/// [EffectRecipe.bloomSigma] derives the radius from the region's short side,
/// so a 64 px thumbnail and a 576 px export cell get the same *apparent* glow
/// rather than the preview being visibly blurrier or sharper.
abstract final class EffectBloom {
  /// The paint used for the blurred glow pass.
  ///
  /// Exposed so the widget layer can reuse the exact same configuration.
  static ui.Paint glowPaint({
    required double sigma,
    required double amount,
  }) {
    return ui.Paint()
      ..isAntiAlias = true
      ..blendMode = ui.BlendMode.screen
      ..color = ui.Color.fromRGBO(255, 255, 255, amount.clamp(0.0, 1.0))
      ..imageFilter = sigma > 0
          ? ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: ui.TileMode.decal)
          : null;
  }

  /// Paints the glow for one image over [area].
  ///
  /// The single-image form used by the Decorate preview, where each cell is
  /// painted by its own [EffectImage].
  static void paintSingle(
    ui.Canvas canvas,
    ui.Rect area,
    EffectRecipe recipe,
    ui.Image image,
    ui.Rect source,
  ) {
    if (recipe.bloomAmount <= 0 || area.isEmpty) return;
    final double sigma = recipe.bloomSigma(math.min(area.width, area.height));
    if (sigma <= 0) return;
    canvas.save();
    canvas.clipRect(area);
    canvas.drawImageRect(
      image,
      source,
      area,
      glowPaint(sigma: sigma, amount: recipe.bloomAmount),
    );
    canvas.restore();
  }

  /// Paints the glow over [area] for a list of already-placed cells.
  ///
  /// [sources] holds the source rect each image occupies, in the same order as
  /// [images]; [targets] the destination rects. The exporter passes one entry
  /// per photo so each cell glows with its own pixels.
  static void paintCells(
    ui.Canvas canvas,
    EffectRecipe recipe,
    List<ui.Image> images,
    List<ui.Rect> sources,
    List<ui.Rect> targets,
  ) {
    if (recipe.bloomAmount <= 0 || images.isEmpty) return;
    final int count = images.length < targets.length ? images.length : targets.length;
    for (int i = 0; i < count; i++) {
      final ui.Rect source = i < sources.length ? sources[i] : targets[i];
      paintSingle(canvas, targets[i], recipe, images[i], source);
    }
  }
}

/// Minimal Dark effect overlay for the live preview.
///
/// Wraps [EffectGrain] so the Decorate composition and the exporter share the
/// exact same painter.
class EffectGrainOverlay extends StatelessWidget {
  const EffectGrainOverlay({
    super.key,
    required this.amount,
    this.seed = EffectRecipe.grainSeed,
  });

  /// Grain strength, 0…1.
  final double amount;

  /// Deterministic seed; must match the exporter.
  final int seed;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _EffectGrainPainter(amount: amount, seed: seed),
      ),
    );
  }
}

class _EffectGrainPainter extends CustomPainter {
  const _EffectGrainPainter({required this.amount, required this.seed});

  final double amount;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    EffectGrain.paint(
      canvas,
      ui.Rect.fromLTWH(0, 0, size.width, size.height),
      amount,
      seed: seed,
    );
  }

  @override
  bool shouldRepaint(covariant _EffectGrainPainter old) =>
      old.amount != amount || old.seed != seed;
}
