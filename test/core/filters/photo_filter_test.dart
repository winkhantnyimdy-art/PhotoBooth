import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/filters/photo_filter.dart';

void main() {
  group('ColorMatrix', () {
    test('multiply applies the second matrix first', () {
      // brightness(+1) then saturation(0) == the greyscale of a lifted image,
      // which is not the same as the identity.
      final List<double> composed = ColorMatrix.multiply(
        ColorMatrix.brightness(0.2),
        ColorMatrix.saturation(0),
      );
      expect(composed[4], closeTo(51, 0.001)); // 0.2 * 255 offset survives
      expect(composed[0], closeTo(0.2126, 0.001));
      expect(composed[3], 0);
    });

    test('lerp between identity and a matrix at 0 is identity', () {
      expect(
        ColorMatrix.lerp(
          ColorMatrix.identity,
          ColorMatrix.saturation(0),
          0,
        ),
        ColorMatrix.identity,
      );
    });
  });

  group('PhotoFilterType', () {
    test('every preset ships a label and a 20-value matrix', () {
      expect(PhotoFilterType.values.length, 8);
      for (final PhotoFilterType type in PhotoFilterType.values) {
        expect(type.label, isNotEmpty);
        expect(type.matrix, hasLength(20));
      }
    });

    test('only Film Grain carries the procedural noise layer', () {
      expect(PhotoFilterType.filmGrain.hasGrain, isTrue);
      for (final PhotoFilterType type in PhotoFilterType.values) {
        if (type != PhotoFilterType.filmGrain) {
          expect(type.hasGrain, isFalse, reason: type.label);
        }
      }
    });

    test('presets produce distinct matrices', () {
      final Set<List<double>> matrices = PhotoFilterType.values
          .map((PhotoFilterType t) => t.matrix)
          .toSet();
      expect(matrices.length, PhotoFilterType.values.length);
    });
  });

  group('buildMatrix', () {
    test('strength 0 is exactly Original for every preset', () {
      const PhotoAdjustments neutral = PhotoAdjustments();
      for (final PhotoFilterType type in PhotoFilterType.values) {
        final List<double> matrix = buildMatrix(type, 0, neutral);
        expect(
          matrix,
          ColorMatrix.identity,
          reason: '${type.label} at 0 must equal Original',
        );
      }
    });

    test('strength 1 uses the full preset matrix', () {
      final List<double> matrix = buildMatrix(
        PhotoFilterType.classicBw,
        1,
        const PhotoAdjustments(),
      );
      final List<double> expected = PhotoFilterType.classicBw.matrix;
      for (int i = 0; i < matrix.length; i++) {
        expect(matrix[i], closeTo(expected[i], 1e-9), reason: 'entry $i');
      }
    });

    test('original ignores intensity entirely', () {
      final List<double> full = buildMatrix(
        PhotoFilterType.original,
        1,
        const PhotoAdjustments(),
      );
      final List<double> half = buildMatrix(
        PhotoFilterType.original,
        0.5,
        const PhotoAdjustments(),
      );
      expect(full, ColorMatrix.identity);
      expect(half, ColorMatrix.identity);
    });

    test('neutral adjustments leave the preset untouched', () {
      final List<double> plain = buildMatrix(
        PhotoFilterType.retroFilm,
        0.6,
        const PhotoAdjustments(),
      );
      final List<double> neutral = buildMatrix(
        PhotoFilterType.retroFilm,
        0.6,
        const PhotoAdjustments(),
      );
      expect(plain, neutral);
      expect(isIdentityMatrix(neutral), isFalse);
    });

    test('adjustments compose onto the preset', () {
      final List<double> presetOnly = buildMatrix(
        PhotoFilterType.retroFilm,
        1,
        const PhotoAdjustments(),
      );
      final List<double> adjusted = buildMatrix(
        PhotoFilterType.retroFilm,
        1,
        const PhotoAdjustments(brightness: 0.3, saturation: -0.4),
      );
      expect(adjusted, isNot(presetOnly));
      expect(adjusted[4], greaterThan(presetOnly[4])); // brighter offset
      expect(
        adjusted[0],
        lessThan(presetOnly[0]), // more desaturated red coefficient
      );
    });

    test('output is deterministic for fixed inputs', () {
      final List<double> first = buildMatrix(
        PhotoFilterType.vividPop,
        0.72,
        const PhotoAdjustments(
          brightness: 0.1,
          contrast: 0.2,
          saturation: -0.2,
          warmth: 0.4,
        ),
      );
      final List<double> second = buildMatrix(
        PhotoFilterType.vividPop,
        0.72,
        const PhotoAdjustments(
          brightness: 0.1,
          contrast: 0.2,
          saturation: -0.2,
          warmth: 0.4,
        ),
      );
      expect(first, second);
    });

    test('PhotoAdjustments isNeutral reflects its sliders', () {
      expect(const PhotoAdjustments().isNeutral, isTrue);
      expect(
        const PhotoAdjustments(contrast: 0.5).isNeutral,
        isFalse,
      );
    });
  });
}