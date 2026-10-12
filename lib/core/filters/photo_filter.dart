import 'dart:ui' as ui;

// The colour-filter engine behind the Decorate screen.
//
// Every preset is a 4x5 colour matrix in the same row-major layout that
// [ui.ColorFilter.matrix] consumes. That single representation is used by two
// consumers that must agree pixel-for-pixel:
//
//  * the live preview, which wraps each photo in a `ColorFiltered` widget, and
//  * the PNG exporter, which hands the identical matrix to the paint that
//    draws each photo cell.
//
// Because both paths share [buildMatrix], "what you see is what you export" is
// structural rather than hoped for.
//
// Intensity is applied by interpolating the preset matrix against the identity
// matrix, so strength 0 is exactly Original for every preset, and the output
// is deterministic for fixed inputs.

/// A single-tap photographic look, matching the design's filter shelf.
enum PhotoFilterType {
  original('Original'),
  softGlow('Soft Glow'),
  retroFilm('Retro Film'),
  vividPop('Vivid Pop'),
  coolBlue('Cool Blue'),
  dreamyPink('Dreamy Pink'),
  filmGrain('Film Grain'),
  classicBw('Classic B&W');

  const PhotoFilterType(this.label);

  /// Human-readable name shown on the filter shelf.
  final String label;

  /// Film Grain is the only preset that also overlays procedural noise.
  bool get hasGrain => this == PhotoFilterType.filmGrain;

  /// The fully-applied matrix for this preset at strength 1.
  List<double> get matrix {
    switch (this) {
      case PhotoFilterType.original:
        return ColorMatrix.identity;
      case PhotoFilterType.softGlow:
        // Lifted blacks + a gentle bloom, slightly warmed.
        return ColorMatrix.multiply(
          ColorMatrix.brightness(0.06),
          ColorMatrix.multiply(
            ColorMatrix.contrast(0.9),
            ColorMatrix.multiply(
              ColorMatrix.saturation(1.1),
              ColorMatrix.temperature(0.08),
            ),
          ),
        );
      case PhotoFilterType.retroFilm:
        // Faded, warm, low-saturation 70s stock.
        return ColorMatrix.multiply(
          ColorMatrix.brightness(0.05),
          ColorMatrix.multiply(
            ColorMatrix.contrast(0.88),
            ColorMatrix.multiply(
              ColorMatrix.saturation(0.82),
              ColorMatrix.temperature(0.16),
            ),
          ),
        );
      case PhotoFilterType.vividPop:
        // Punchy saturation and contrast.
        return ColorMatrix.multiply(
          ColorMatrix.contrast(1.12),
          ColorMatrix.saturation(1.45),
        );
      case PhotoFilterType.coolBlue:
        return ColorMatrix.multiply(
          ColorMatrix.temperature(-0.22),
          ColorMatrix.saturation(1.05),
        );
      case PhotoFilterType.dreamyPink:
        return ColorMatrix.multiply(
          ColorMatrix.pinkTint(0.9),
          ColorMatrix.multiply(
            ColorMatrix.brightness(0.07),
            ColorMatrix.saturation(1.12),
          ),
        );
      case PhotoFilterType.filmGrain:
        // Mild contrast + desaturation; the grain itself is a separate layer.
        return ColorMatrix.multiply(
          ColorMatrix.contrast(1.06),
          ColorMatrix.saturation(0.9),
        );
      case PhotoFilterType.classicBw:
        return ColorMatrix.multiply(
          ColorMatrix.contrast(1.08),
          ColorMatrix.saturation(0),
        );
    }
  }
}

/// Manual adjustments layered on top of a preset in the Adjust tab.
///
/// Each value is neutral at 0 and runs from -1 to 1. Adjustments compose
/// *after* the preset, matching the order the user sees them applied.
class PhotoAdjustments {
  const PhotoAdjustments({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
  });

  /// -1 (darker) … 0 (neutral) … 1 (brighter).
  final double brightness;

  /// -1 (softer) … 0 (neutral) … 1 (punchier).
  final double contrast;

  /// -1 (greyer) … 0 (neutral) … 1 (more colourful).
  final double saturation;

  /// -1 (cooler/blue) … 0 (neutral) … 1 (warmer/amber).
  final double warmth;

  /// True when every slider is at its neutral value.
  bool get isNeutral =>
      brightness == 0 && contrast == 0 && saturation == 0 && warmth == 0;

  PhotoAdjustments copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
  }) {
    return PhotoAdjustments(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      warmth: warmth ?? this.warmth,
    );
  }

  /// The composed matrix for these adjustments.
  List<double> get matrix {
    List<double> result = ColorMatrix.identity;
    if (saturation != 0) {
      result = ColorMatrix.multiply(
        ColorMatrix.saturation(1 + saturation),
        result,
      );
    }
    if (warmth != 0) {
      result = ColorMatrix.multiply(
        ColorMatrix.temperature(warmth),
        result,
      );
    }
    if (contrast != 0) {
      result = ColorMatrix.multiply(
        ColorMatrix.contrast(1 + contrast),
        result,
      );
    }
    if (brightness != 0) {
      result = ColorMatrix.multiply(
        ColorMatrix.brightness(brightness),
        result,
      );
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is PhotoAdjustments &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.saturation == saturation &&
      other.warmth == warmth;

  @override
  int get hashCode =>
      Object.hash(brightness, contrast, saturation, warmth);
}

/// The single entry point used by both the preview and the exporter.
///
/// * [filter] — the chosen preset.
/// * [intensity] — 0…1 blend towards the preset (0 is identity / Original).
/// * [adjustments] — manual tweaks layered after the preset.
///
/// Returns a 20-value matrix ready for [ui.ColorFilter.matrix].
List<double> buildMatrix(
  PhotoFilterType filter,
  double intensity,
  PhotoAdjustments adjustments,
) {
  final double t = intensity.clamp(0.0, 1.0);
  final List<double> presetted = ColorMatrix.lerp(
    ColorMatrix.identity,
    filter.matrix,
    t,
  );
  if (adjustments.isNeutral) return presetted;
  return ColorMatrix.multiply(adjustments.matrix, presetted);
}

/// Convenience wrapper for the Flutter widget layer.
ui.ColorFilter buildColorFilter(
  PhotoFilterType filter,
  double intensity,
  PhotoAdjustments adjustments,
) {
  return ui.ColorFilter.matrix(buildMatrix(filter, intensity, adjustments));
}

/// True when [matrix] leaves every channel untouched (an identity transform).
bool isIdentityMatrix(List<double> matrix, {double epsilon = 1e-6}) {
  for (int i = 0; i < matrix.length; i++) {
    if ((matrix[i] - ColorMatrix.identity[i]).abs() > epsilon) return false;
  }
  return true;
}

/// 4x5 colour-matrix maths.
///
/// Matrices are stored row-major with 5 values per row and the fifth column
/// holding an offset in the 0…255 space that [ui.ColorFilter.matrix] expects.
abstract final class ColorMatrix {
  /// The no-op transform.
  static const List<double> identity = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// Saturation where 0 is greyscale and 1 is unchanged.
  static List<double> saturation(double s) {
    const double lr = 0.2126;
    const double lg = 0.7152;
    const double lb = 0.0722;
    final double ir = (1 - s) * lr;
    final double ig = (1 - s) * lg;
    final double ib = (1 - s) * lb;
    return <double>[
      ir + s, ig, ib, 0, 0, //
      ir, ig + s, ib, 0, 0, //
      ir, ig, ib + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// Contrast around mid-grey. 1 is unchanged.
  static List<double> contrast(double c) {
    final double offset = 127.5 * (1 - c);
    return <double>[
      c, 0, 0, 0, offset, //
      0, c, 0, 0, offset, //
      0, 0, c, 0, offset, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// Additive brightness. [b] runs -1…1 and maps to a ±255 offset.
  static List<double> brightness(double b) {
    final double offset = b * 255;
    return <double>[
      1, 0, 0, 0, offset, //
      0, 1, 0, 0, offset, //
      0, 0, 1, 0, offset, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// Warm/cool white balance. Positive = warmer (more red, less blue).
  static List<double> temperature(double t) {
    final double r = 1 + (t * 0.14);
    final double g = 1 + (t * 0.02);
    final double b = 1 - (t * 0.14);
    return <double>[
      r, 0, 0, 0, 0, //
      0, g, 0, 0, 0, //
      0, 0, b, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// A soft pink cast used by Dreamy Pink. [strength] runs 0…1.
  static List<double> pinkTint(double strength) {
    final double r = 1 + (0.08 * strength);
    final double g = 1 - (0.03 * strength);
    final double b = 1 + (0.03 * strength);
    final double lift = 10 * strength;
    return <double>[
      r, 0, 0, 0, lift, //
      0, g, 0, 0, lift * 0.4, //
      0, 0, b, 0, lift * 0.6, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// Composes two matrices: the result applies [b] first, then [a].
  ///
  /// The implicit bottom row of the affine transform is `[0, 0, 0, 0, 1]`, so
  /// the fifth column of the product folds in `a`'s own offset.
  static List<double> multiply(List<double> a, List<double> b) {
    final List<double> out = List<double>.filled(20, 0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        double value = 0;
        for (int k = 0; k < 4; k++) {
          value += a[(row * 5) + k] * b[(k * 5) + col];
        }
        if (col == 4) value += a[(row * 5) + 4];
        out[(row * 5) + col] = value;
      }
    }
    return out;
  }

  /// Element-wise interpolation from [a] (t=0) to [b] (t=1).
  static List<double> lerp(List<double> a, List<double> b, double t) {
    final List<double> out = List<double>.filled(20, 0);
    for (int i = 0; i < 20; i++) {
      out[i] = a[i] + ((b[i] - a[i]) * t);
    }
    return out;
  }
}
