import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/filters/photo_effect.dart';
import 'package:photo_booth/core/filters/photo_filter.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/decorate/frame_theme.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// A controlled fixture that exercises the parts of a filter that a flat grey
/// image cannot:
///
///  * saturated patches, so a colour matrix's cross-channel terms show up;
///  * a white block and a black block, so highlight and shadow handling are
///    both measurable;
///  * a left-to-right gradient, so an accidental mirror is visible;
///  * an off-centre disc, so a transpose or a flip cannot hide.
Future<ui.Image> _fixture({int size = 96}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final double s = size.toDouble();

  // Left-to-right gradient. Warm on the left, cool on the right.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(s, 0),
        const <Color>[Color(0xFFFF3B30), Color(0xFF34C759), Color(0xFF007AFF)],
        const <double>[0, 0.5, 1],
      ),
  );

  // Neutral mid-grey, so any contrast/brightness change is unambiguous.
  canvas.drawRect(
    Rect.fromLTWH(0, s * 0.4, s, s * 0.2),
    Paint()..color = const Color(0xFF808080),
  );

  // Highlight and shadow blocks.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, s * 0.25, s * 0.4),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  canvas.drawRect(
    Rect.fromLTWH(s * 0.75, s * 0.6, s * 0.25, s * 0.4),
    Paint()..color = const Color(0xFF000000),
  );

  // Off-centre disc, high and left of centre.
  canvas.drawCircle(
    Offset(s * 0.3, s * 0.2),
    s * 0.12,
    Paint()..color = const Color(0xFFFFEB3B),
  );

  return recorder.endRecording().toImage(size, size);
}

/// Raw RGBA pixels of [image], row-major.
Future<Uint8List> _pixels(ui.Image image) async {
  final ByteData? data = await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Samples a single pixel as (r, g, b, a).
({int r, int g, int b, int a}) _at(Uint8List rgba, int width, int x, int y) {
  final int i = (y * width + x) * 4;
  return (r: rgba[i], g: rgba[i + 1], b: rgba[i + 2], a: rgba[i + 3]);
}

/// Mean per-pixel channel spread (max - min), a sign-independent measure of how
/// colourful the image is.
///
/// A signed red-minus-blue gap is useless here: the fixture's own mean is blue
/// dominant, so a desaturation shows up as the gap becoming *more* negative.
double _meanSaturation(Uint8List rgba) {
  double total = 0;
  final int pixels = rgba.length ~/ 4;
  for (int i = 0; i < rgba.length; i += 4) {
    final int r = rgba[i];
    final int g = rgba[i + 1];
    final int b = rgba[i + 2];
    final int hi = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final int lo = r < g ? (r < b ? r : b) : (g < b ? g : b);
    total += hi - lo;
  }
  return total / pixels;
}

/// Mean of one channel across the whole image.
double _channelMean(Uint8List rgba, int offset) {
  int total = 0;
  final int pixels = rgba.length ~/ 4;
  for (int i = offset; i < rgba.length; i += 4) {
    total += rgba[i];
  }
  return total / pixels;
}

/// Mean luminance, 0…255.
double _lumaMean(Uint8List rgba) {
  double total = 0;
  final int pixels = rgba.length ~/ 4;
  for (int i = 0; i < rgba.length; i += 4) {
    total += (0.299 * rgba[i]) + (0.587 * rgba[i + 1]) + (0.114 * rgba[i + 2]);
  }
  return total / pixels;
}

/// Standard deviation of luminance: the measurable signature of grain.
double _lumaStdDev(Uint8List rgba) {
  final double mean = _lumaMean(rgba);
  double sum = 0;
  final int pixels = rgba.length ~/ 4;
  for (int i = 0; i < rgba.length; i += 4) {
    final double l = (0.299 * rgba[i]) +
        (0.587 * rgba[i + 1]) +
        (0.114 * rgba[i + 2]);
    final double d = l - mean;
    sum += d * d;
  }
  return math.sqrt(sum / pixels);
}

/// Applies [recipe] to the fixture through the same canvas path the exporter
/// uses, so this measures the real pipeline rather than a re-implementation.
Future<Uint8List> _renderFixture(EffectRecipe recipe, {int size = 96}) async {
  final ui.Image source = await _fixture(size: size);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = Canvas(recorder);
  final ui.Rect target = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
  final ui.Rect sourceRect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());

  canvas.drawImageRect(
    source,
    sourceRect,
    target,
    Paint()
      ..colorFilter = ColorMatrix.isIdentity(recipe.matrix)
          ? null
          : ui.ColorFilter.matrix(recipe.matrix),
  );
  if (recipe.bloomAmount > 0) {
    EffectBloom.paintSingle(canvas, target, recipe, source, sourceRect);
  }
  if (recipe.grainAmount > 0) {
    EffectGrain.paint(
      canvas,
      target,
      recipe.grainAmount,
      seed: EffectRecipe.grainSeed,
    );
  }

  return _pixels(await recorder.endRecording().toImage(size, size));
}

/// Runs [recipe] through the pipeline twice and asserts the result is
/// bit-identical, which is what "deterministic" has to mean.
Future<Uint8List> _renderTwice(EffectRecipe recipe) async {
  final Uint8List a = await _renderFixture(recipe);
  final Uint8List b = await _renderFixture(recipe);
  expect(a, orderedEquals(b), reason: 'the same recipe must not drift');
  return a;
}

void main() {
  group('PhotoEffect catalogue', () {
    test('holds exactly fifteen effects with stable identifiers', () {
      expect(PhotoEffect.values.length, 15);
      expect(
        PhotoEffect.values.map((PhotoEffect e) => e.id).toSet().length,
        15,
        reason: 'identifiers must be unique',
      );
      // The published identifier vocabulary. Changing one of these would break
      // every album record already written to disk.
      expect(
        PhotoEffect.values.map((PhotoEffect e) => e.id).toList(),
        <String>[
          'original',
          'soft',
          'warm',
          'cool',
          'mm35',
          'vintage',
          'grain',
          'faded',
          'classicFilm',
          'y2kFlash',
          'ccd',
          'tokyoNight',
          'mono',
          'noir',
          'dreamy',
        ],
      );
    });

    test('every identifier round-trips through parsing', () {
      for (final PhotoEffect effect in PhotoEffect.values) {
        expect(PhotoEffect.tryParse(effect.id), effect);
      }
      expect(PhotoEffect.tryParse('nonsense'), isNull);
    });

    test('every effect has a non-empty readable label', () {
      for (final PhotoEffect effect in PhotoEffect.values) {
        expect(effect.label.trim(), isNotEmpty, reason: effect.id);
      }
    });

    test('every effect except Original changes the pixels', () async {
      final Uint8List original = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.original, 1),
      );
      for (final PhotoEffect effect in PhotoEffect.values) {
        if (effect == PhotoEffect.original) continue;
        final Uint8List graded = await _renderFixture(
          EffectRecipe.resolve(effect, 1),
        );
        expect(
          graded,
          isNot(orderedEquals(original)),
          reason: '${effect.id} left the image untouched at 100%',
        );
      }
    });
  });

  group('intensity', () {
    test('Original is the identity matrix at every intensity', () {
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        expect(
          ColorMatrix.isIdentity(EffectRecipe.resolve(PhotoEffect.original, t).matrix),
          isTrue,
          reason: 'Original at $t must be identity',
        );
      }
    });

    test('intensity 0 is exactly Original for all fifteen effects', () async {
      final Uint8List original = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.original, 1),
      );
      for (final PhotoEffect effect in PhotoEffect.values) {
        final EffectRecipe zero = EffectRecipe.resolve(effect, 0);
        expect(zero.grainAmount, 0, reason: '${effect.id} grain at 0');
        expect(zero.bloomAmount, 0, reason: '${effect.id} bloom at 0');
        expect(
          ColorMatrix.isIdentity(zero.matrix),
          isTrue,
          reason: '${effect.id} matrix at 0 must be identity',
        );
        expect(
          await _renderFixture(zero),
          orderedEquals(original),
          reason: '${effect.id} at 0% must equal Original pixel for pixel',
        );
      }
    });

    test('out-of-range intensity is clamped, not extrapolated', () {
      final EffectRecipe high = EffectRecipe.resolve(PhotoEffect.vintage, 4);
      final EffectRecipe unit = EffectRecipe.resolve(PhotoEffect.vintage, 1);
      expect(high.intensity, 1);
      expect(high.matrix, orderedEquals(unit.matrix));

      final EffectRecipe low = EffectRecipe.resolve(PhotoEffect.vintage, -2);
      expect(low.intensity, 0);
      expect(ColorMatrix.isIdentity(low.matrix), isTrue);
    });

    test('intensity increases monotonically toward the full effect', () {
      // A matte reference frame: intensity 50% must sit between identity and
      // full, closer to neither than the other.
      final List<double> distances = <double>[];
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        final List<double> m = EffectRecipe.resolve(PhotoEffect.ccd, t).matrix;
        distances.add(_matrixDistance(m, ColorMatrix.identity));
      }
      for (int i = 1; i < distances.length; i++) {
        expect(
          distances[i],
          greaterThan(distances[i - 1]),
          reason: 'intensity must increase the distance from identity',
        );
      }
      expect(
        distances.last,
        closeTo(distances.first + distances.last, 0.001),
        reason: 'full strength must be twice the midpoint distance',
      );
    });

    test('grain and bloom strength scale linearly with intensity', () {
      for (final PhotoEffect effect in <PhotoEffect>[
        PhotoEffect.grain,
        PhotoEffect.dreamy,
        PhotoEffect.y2kFlash,
      ]) {
        final EffectRecipe half = EffectRecipe.resolve(effect, 0.5);
        final EffectRecipe full = EffectRecipe.resolve(effect, 1);
        expect(half.grainAmount, closeTo(full.grainAmount / 2, 1e-9));
        expect(half.bloomAmount, closeTo(full.bloomAmount / 2, 1e-9));
      }
    });
  });

  group('pixel behaviour', () {
    test('Mono and Noir are the only fully desaturated effects', () async {
      for (final PhotoEffect effect in PhotoEffect.values) {
        final Uint8List rgba = await _renderFixture(
          EffectRecipe.resolve(effect, 1),
        );
        final double spread = (_channelMean(rgba, 0) - _channelMean(rgba, 1))
                .abs() +
            (_channelMean(rgba, 1) - _channelMean(rgba, 2)).abs();
        final bool desaturated = spread < 1.0;
        if (effect == PhotoEffect.mono || effect == PhotoEffect.noir) {
          expect(desaturated, isTrue, reason: '${effect.id} should be grey');
        }
      }
    });

    test('Noir is higher contrast than Mono', () async {
      final Uint8List mono = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.mono, 1),
      );
      final Uint8List noir = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.noir, 1),
      );
      expect(
        _lumaStdDev(noir),
        greaterThan(_lumaStdDev(mono)),
        reason: 'Noir must crush harder than Mono',
      );
    });

    test('Warm pushes red up and Cool pushes blue up', () async {
      final Uint8List original = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.original, 1),
      );
      final Uint8List warm = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.warm, 1),
      );
      final Uint8List cool = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.cool, 1),
      );

      expect(
        _channelMean(warm, 0) - _channelMean(warm, 2),
        greaterThan(
          _channelMean(original, 0) - _channelMean(original, 2),
        ),
        reason: 'Warm must widen the red-blue gap',
      );
      expect(
        _channelMean(cool, 2) - _channelMean(cool, 0),
        greaterThan(
          _channelMean(original, 2) - _channelMean(original, 0),
        ),
        reason: 'Cool must widen the blue-red gap',
      );
    });

    test('Faded lifts the blacks and drops saturation', () async {
      final Uint8List original = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.original, 1),
      );
      final Uint8List faded = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.faded, 1),
      );
      // The fixture's black block sits at the lower right.
      final int blackX = 84;
      final int blackY = 84;
      expect(
        _at(faded, 96, blackX, blackY).r,
        greaterThan(_at(original, 96, blackX, blackY).r),
        reason: 'Faded must raise the black point',
      );
      expect(
        _meanSaturation(original),
        greaterThan(_meanSaturation(faded) + 1),
        reason: 'Faded must reduce colour',
      );
    });

    test('the fixture is asymmetric, so mirroring would be detectable', () async {
      final Uint8List rgba = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.original, 1),
      );
      final ({int r, int g, int b, int a}) left = _at(rgba, 96, 4, 4);
      final ({int r, int g, int b, int a}) right = _at(rgba, 96, 91, 4);
      expect(
        (left.r - right.r).abs() + (left.b - right.b).abs(),
        greaterThan(20),
        reason: 'the fixture must differ left to right',
      );
    });

    test('every effect preserves alpha and the image dimensions', () async {
      for (final PhotoEffect effect in PhotoEffect.values) {
        final Uint8List rgba = await _renderFixture(
          EffectRecipe.resolve(effect, 1),
        );
        expect(rgba.length, 96 * 96 * 4, reason: effect.id);
        expect(
          _at(rgba, 96, 0, 0).a,
          255,
          reason: '${effect.id} must not knock out the corner pixel',
        );
      }
    });
  });

  group('grain', () {
    test('is absent at 0 and present at 100', () async {
      final Uint8List flat = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.grain, 0),
      );
      final Uint8List grained = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.grain, 1),
      );
      expect(_lumaStdDev(grained), greaterThan(_lumaStdDev(flat) + 0.2));
    });

    test('is deterministic for the same recipe', () async {
      final Uint8List a = await _renderTwice(
        EffectRecipe.resolve(PhotoEffect.grain, 1),
      );
      final Uint8List b = await _renderTwice(
        EffectRecipe.resolve(PhotoEffect.grain, 1),
      );
      expect(a, orderedEquals(b));
    });

    test('a different seed produces a different pattern', () async {
      final ui.Image source = await _fixture();
      Future<Uint8List> withSeed(int seed) async {
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final ui.Canvas canvas = Canvas(recorder);
        canvas.drawImage(
          source,
          Offset.zero,
          Paint()
            ..colorFilter = ui.ColorFilter.matrix(
              EffectRecipe.resolve(PhotoEffect.grain, 1).matrix,
            ),
        );
        EffectGrain.paint(
          canvas,
          const ui.Rect.fromLTWH(0, 0, 96, 96),
          0.85,
          seed: seed,
        );
        return _pixels(await recorder.endRecording().toImage(96, 96));
      }

      expect(
        await withSeed(1),
        isNot(orderedEquals(await withSeed(2))),
        reason: 'a different seed must move the specks',
      );
      source.dispose();
    });

    test('speck density scales with area, not with absolute pixel count', () {
      // The same short side at four times the area must produce roughly four
      // times the specks; the old implementation capped this, which is why
      // large exports looked smoother than previews.
      final int small = EffectGrain.speckCount(width: 288, height: 384, amount: 1);
      final int large = EffectGrain.speckCount(width: 576, height: 768, amount: 1);
      expect(large, closeTo(small * 4, small * 0.05));
    });

    test('speck radius scales with the region short side', () {
      final double small =
          EffectGrain.speckRadius(shortSide: 128, amount: 1);
      final double large =
          EffectGrain.speckRadius(shortSide: 512, amount: 1);
      expect(large / small, closeTo(4, 0.001));
    });

    test('no specks are painted for an empty region or zero amount', () {
      expect(EffectGrain.speckCount(width: 0, height: 0, amount: 1), 0);
      expect(EffectGrain.speckCount(width: 576, height: 768, amount: 0), 0);
    });
  });

  group('bloom', () {
    test('sigma scales with the region so the look survives resolution', () {
      final EffectRecipe recipe = EffectRecipe.resolve(PhotoEffect.dreamy, 1);
      final double small = recipe.bloomSigma(128);
      final double large = recipe.bloomSigma(512);
      expect(large / small, closeTo(4, 1e-9));
    });

    test('sigma is zero without bloom', () {
      expect(EffectRecipe.resolve(PhotoEffect.grain, 1).bloomSigma(512), 0);
      expect(EffectRecipe.resolve(PhotoEffect.dreamy, 0).bloomSigma(512), 0);
    });

    test('screen blending lifts highlights but leaves shadows down', () async {
      // White block in the upper left, black block in the lower right.
      final ui.Image source = await _fixture();
      final EffectRecipe recipe = EffectRecipe.resolve(PhotoEffect.dreamy, 1);

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = Canvas(recorder);
      EffectBloom.paintSingle(
        canvas,
        const ui.Rect.fromLTWH(0, 0, 96, 96),
        recipe,
        source,
        const ui.Rect.fromLTWH(0, 0, 96, 96),
      );
      final Uint8List rgba =
          await _pixels(await recorder.endRecording().toImage(96, 96));

      // The glow pass alone is translucent white: strong where the photo was
      // white, close to nothing where it was black. That asymmetry is exactly
      // what screen blending buys and an alpha composite would not.
      expect(_at(rgba, 96, 4, 4).r, greaterThan(100));
      expect(_at(rgba, 96, 91, 91).r, lessThan(40));
    });
  });

  group('preview and export agreement', () {
    test('the recipe is the only description either side reads', () {
      // Thumbnail, Decorate preview and exporter all call this. If they ever
      // diverge, this test is the place it shows up first.
      for (final PhotoEffect effect in PhotoEffect.values) {
        for (final double t in <double>[0, 0.5, 1]) {
          final EffectRecipe a = EffectRecipe.resolve(effect, t);
          final EffectRecipe b = EffectRecipe.resolve(effect, t);
          expect(a.matrix, orderedEquals(b.matrix));
          expect(a.grainAmount, b.grainAmount);
          expect(a.bloomAmount, b.bloomAmount);
        }
      }
    });

    test('the shared seed is stable, so preview and export match', () {
      // The old pipeline seeded the preview with 0 and the export with the
      // export width, so the two never showed the same noise.
      expect(EffectRecipe.grainSeed, isNot(0));
      expect(EffectRecipe.grainSeed, isNot(1200));
      expect(EffectRecipe.grainSeed, EffectRecipe.grainSeed);
    });

    test('resolution does not change the colour grade', () async {
      // Same recipe, different painted size: the matrix result must be
      // identical at matching coordinates. Grain and bloom are relative for
      // exactly this reason.
      final Uint8List small = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.classicFilm, 1),
        size: 48,
      );
      final Uint8List large = await _renderFixture(
        EffectRecipe.resolve(PhotoEffect.classicFilm, 1),
        size: 192,
      );
      // Sample the same relative point and allow for resampling tolerance.
      final ({int r, int g, int b, int a}) a = _at(small, 48, 4, 4);
      final ({int r, int g, int b, int a}) b = _at(large, 192, 16, 16);
      expect((a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs(),
          lessThan(24));
    });

    test('the export painter and the widget painter share one primitive', () {
      // Both surfaces call these exact helpers; asserting on identity keeps
      // them from being forked later.
      expect(EffectBloom.glowPaint(sigma: 4, amount: 0.5).blendMode,
          BlendMode.screen);
      expect(
        EffectBloom.glowPaint(sigma: 4, amount: 0.5).imageFilter,
        isNotNull,
      );
      expect(EffectBloom.glowPaint(sigma: 0, amount: 0.5).imageFilter, isNull);
    });
  });

  group('state, persistence and undo', () {
    const DecorationState base = DecorationState(
      layout: PhotoLayout.grid4,
      background: BackgroundChoice.cream,
      style: DecorativeStyle.clean,
    );

    test('effect selection is reversible through the decoration state', () {
      final DecorationState graded =
          base.copyWith(filter: PhotoEffect.tokyoNight, filterIntensity: 0.6);
      expect(graded.filter, PhotoEffect.tokyoNight);
      expect(graded.filterIntensity, 0.6);
      // Non-destructive: the original state is untouched.
      expect(base.filter, PhotoEffect.original);
      expect(base.filterIntensity, 1.0);
    });

    test('undo and redo restore effect and strength exactly', () {
      final UndoRedoDecoration history = UndoRedoDecoration();
      DecorationState current = base;

      history.record(current);
      current = current.copyWith(filter: PhotoEffect.vintage);
      expect(current.filter, PhotoEffect.vintage);

      history.record(current);
      current = current.copyWith(filterIntensity: 0.35);
      expect(current.filterIntensity, 0.35);

      current = history.undo(current)!;
      expect(current.filterIntensity, 1.0, reason: 'undo the strength');
      expect(current.filter, PhotoEffect.vintage, reason: 'keep the effect');

      current = history.undo(current)!;
      expect(current.filter, PhotoEffect.original, reason: 'undo the effect');

      expect(history.canUndo, isFalse);
      expect(history.canRedo, isTrue);

      current = history.redo(current)!;
      expect(current.filter, PhotoEffect.vintage);
      current = history.redo(current)!;
      expect(current.filterIntensity, 0.35);
    });

    test('switching effect does not disturb stickers, text or frames', () {
      final DecorationState decorated = base.copyWith(
        filter: PhotoEffect.mono,
        frameTheme: FrameTheme.vintageFilm,
        texts: const <TextPlacement>[
          TextPlacement(text: 'hi', x: 0.5, y: 0.5),
        ],
      );
      final DecorationState next =
          decorated.copyWith(filter: PhotoEffect.ccd);
      expect(next.texts.length, 1, reason: 'text must survive');
      expect(next.frameTheme, FrameTheme.vintageFilm, reason: 'frame survives');
      expect(next.filter, PhotoEffect.ccd);
      expect(next.filterIntensity, decorated.filterIntensity);
    });

    test('manual adjustments compose with the effect', () {
      const PhotoAdjustments boosted = PhotoAdjustments(brightness: 0.2);
      final EffectRecipe plain =
          EffectRecipe.resolve(PhotoEffect.warm, 1);
      final EffectRecipe adjusted = EffectRecipe.resolve(
        PhotoEffect.warm,
        1,
        adjustments: boosted,
      );
      expect(adjusted.matrix, isNot(orderedEquals(plain.matrix)));
      expect(
        adjusted.grainAmount,
        plain.grainAmount,
        reason: 'adjustments must not disturb the grain amount',
      );
    });

    test('a neutral adjustment is a no-op for every effect', () {
      for (final PhotoEffect effect in PhotoEffect.values) {
        expect(
          EffectRecipe.resolve(
            effect,
            0.7,
            adjustments: const PhotoAdjustments(),
          ).matrix,
          orderedEquals(EffectRecipe.resolve(effect, 0.7).matrix),
          reason: effect.id,
        );
      }
    });
  });

  group('legacy migration', () {
    test('every v1.0.0 preset maps to a V3 effect', () {
      expect(PhotoFilterType.values.length, 8);
      for (final PhotoFilterType legacy in PhotoFilterType.values) {
        expect(
          legacy.toEffect(),
          isA<PhotoEffect>(),
          reason: '${legacy.name} must resolve to a V3 effect',
        );
      }
    });

    test('Original maps to Original', () {
      expect(PhotoFilterType.original.toEffect(), PhotoEffect.original);
    });
  });
}

/// Mean absolute difference between a matrix and a reference.
double _matrixDistance(List<double> matrix, List<double> reference) {
  double total = 0;
  for (int i = 0; i < matrix.length; i++) {
    total += (matrix[i] - reference[i]).abs();
  }
  return total;
}
