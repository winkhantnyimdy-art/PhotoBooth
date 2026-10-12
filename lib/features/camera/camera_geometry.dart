import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Pure geometry for turning a raw camera stream into an upright, full-bleed
/// portrait viewfinder that matches what the exported strip will contain.
///
/// ## Why this exists
///
/// `CameraPreview` sizes itself from `CameraValue.aspectRatio`, which is
/// `previewSize.width / previewSize.height`, then flips it based on the *device*
/// orientation. That heuristic is wrong on iOS Safari: Safari reports the video
/// track in **portrait** dimensions (e.g. 1080x1920), so `aspectRatio` is 0.5625
/// and the portrait flip produces a 16:9 box. Inside a portrait viewport that
/// resolves to a short wide band with black bars above and below - the exact
/// symptom reported on the iPhone 16e.
///
/// Nothing here depends on device orientation. The source frame's own
/// dimensions decide everything, so the viewfinder is identical on every
/// platform and in every orientation.
///
/// Every value here is a pure function of its inputs, which is what makes the
/// camera-to-export crop provably identical in the widget tests and in the PNG
/// renderer.
abstract final class CameraGeometry {
  /// Fallback aspect (width / height) when a platform reports no stream size.
  static const double defaultStreamAspect = 3.0 / 4.0;

  /// Clamps a raw width/height pair into a usable aspect ratio.
  ///
  /// Guards against zero, negative and absurd values that some web browsers
  /// report for `videoWidth`/`videoHeight` before the first frame is delivered.
  static double normalizeAspect(double width, double height) {
    if (width <= 0 || height <= 0 || !width.isFinite || !height.isFinite) {
      return defaultStreamAspect;
    }
    // Clamp to a sane sensor range: 1:8 .. 8:1.
    return (width / height).clamp(0.125, 8.0);
  }

  /// The aspect ratio (width / height) of the stream as it is *stored*.
  ///
  /// A phone camera almost always delivers a landscape-native frame even while
  /// the user holds the phone upright, so callers must pair this with
  /// [streamIsRotated] before drawing.
  static double streamAspect(Size? streamSize) {
    if (streamSize == null) return defaultStreamAspect;
    return normalizeAspect(streamSize.width, streamSize.height);
  }

  /// Whether the stored frame must be rotated a quarter turn to appear upright.
///
/// `true` when the frame's stored orientation differs from the orientation the
/// user is shooting in. The comparison is symmetric: a landscape-native frame
/// shot in portrait needs a quarter turn, and a portrait-native frame shot in
/// landscape needs three.
static bool streamIsRotated({
    required Size? streamSize,
    required bool shootInPortrait,
  }) {
    if (streamSize == null || streamSize.width <= 0 || streamSize.height <= 0) {
      return false;
    }
    final bool storedLandscape = streamSize.width > streamSize.height;
    final bool shootingLandscape = !shootInPortrait;
    // A square frame needs no rotation either way, because for it
    // `storedLandscape` is false, which matches portrait shooting.
    return storedLandscape != shootingLandscape;
  }

  /// Quarter turns needed to bring the stored frame upright, as a normalized
  /// value in `[0, 4)` that is safe to feed to `RotatedBox`.
  ///
  /// Delegates to [streamIsRotated] so the rotation decision and the aspect
  /// decision can never disagree (they did once: a square stream was reported
  /// as needing a rotation by one and not by the other).
  static int uprightQuarterTurns({
    required Size? streamSize,
    required bool shootInPortrait,
  }) {
    final bool rotated = streamIsRotated(
      streamSize: streamSize,
      shootInPortrait: shootInPortrait,
    );
    if (!rotated) return 0;
    return shootInPortrait ? 1 : 3;
  }

  /// The aspect ratio of the **upright** frame the viewfinder should display.
  ///
  /// Independent of device orientation: it is derived only from the stream's
  /// own dimensions, which is the whole point of this class.
  static double uprightAspect({
    required Size? streamSize,
    required bool shootInPortrait,
  }) {
    final double raw = streamAspect(streamSize);
    // A rotated frame swaps its aspect; an unrotated one keeps it.
    return streamIsRotated(
          streamSize: streamSize,
          shootInPortrait: shootInPortrait,
        )
        ? 1.0 / raw
        : raw;
  }

  /// The size a source of [sourceAspect] must be drawn at to *cover* [viewport].
  ///
  /// The result is at least as large as the viewport on **both** axes, and
  /// matches it exactly on one, so the overflow can be cropped and no
  /// letterbox bar is ever needed.
  ///
  /// - A source narrower than the box (taller aspect) is scaled by *width*,
  ///   which makes it taller than the box.
  /// - A source wider than the box is scaled by *height*, which makes it wider.
  static Size coverSize({
    required Size viewport,
    required double sourceAspect,
  }) {
    if (viewport.width <= 0 || viewport.height <= 0 || sourceAspect <= 0) {
      return viewport;
    }
    final double viewportAspect = viewport.width / viewport.height;
    if (sourceAspect <= viewportAspect) {
      // Taller/narrower than the box: scale by width.
      return Size(viewport.width, viewport.width / sourceAspect);
    }
    // Wider than the box: scale by height.
    return Size(viewport.height * sourceAspect, viewport.height);
  }

  /// The centred window of [viewport] that has [outputAspect].
  ///
  /// This is the crop guide drawn over the live preview: the largest centred
  /// rect with the same shape as one exported photo cell, so what the user
  /// frames is exactly what gets kept.
  static Rect cropWindow({
    required Size viewport,
    required double outputAspect,
  }) {
    if (viewport.width <= 0 || viewport.height <= 0 || outputAspect <= 0) {
      return Offset.zero & viewport;
    }
    final double viewportAspect = viewport.width / viewport.height;
    if (viewportAspect > outputAspect) {
      // Viewport is wider than the target: full height, narrower width.
      final double w = viewport.height * outputAspect;
      return Rect.fromLTWH((viewport.width - w) / 2, 0, w, viewport.height);
    }
    final double h = viewport.width / outputAspect;
    return Rect.fromLTWH(0, (viewport.height - h) / 2, viewport.width, h);
  }

  /// Maps [cropWindow] (in viewport coordinates) back onto [sourceSize].
  ///
  /// The renderer uses this to crop a captured frame to the same window the
  /// viewfinder showed, which is what guarantees preview/export agreement.
  ///
  /// Returns a rect in **source pixel** coordinates, clamped to the source.
  static Rect sourceRectForCrop({
    required Size viewport,
    required Size sourceSize,
    required Rect cropWindow,
    double sourceAspect = 0,
  }) {
    if (sourceSize.width <= 0 || sourceSize.height <= 0 || viewport.width <= 0) {
      return Offset.zero & sourceSize;
    }
    final double aspect =
        sourceAspect > 0 ? sourceAspect : sourceSize.width / sourceSize.height;
    final Size drawn = coverSize(viewport: viewport, sourceAspect: aspect);

    final double scaleX = sourceSize.width / drawn.width;
    final double scaleY = sourceSize.height / drawn.height;

    // A cover fit overflows on exactly one axis, and the overflow is centred,
    // so that axis's viewport origin maps *into* the drawn image by half the
    // overflow. The other axis is flush and contributes nothing.
    final double overflowX = math.max(0.0, (drawn.width - viewport.width) / 2);
    final double overflowY = math.max(0.0, (drawn.height - viewport.height) / 2);

    final double left = (cropWindow.left + overflowX) * scaleX;
    final double top = (cropWindow.top + overflowY) * scaleY;
    final double width = cropWindow.width * scaleX;
    final double height = cropWindow.height * scaleY;

    return Rect.fromLTRB(
      left.clamp(0.0, sourceSize.width),
      top.clamp(0.0, sourceSize.height),
      (left + width).clamp(0.0, sourceSize.width),
      (top + height).clamp(0.0, sourceSize.height),
    );
  }

  /// Normalised (0..1) source rect, handy for assertions and for painting crop
  /// guides directly onto the captured image.
  static Rect normalizedSourceRect({
    required Size viewport,
    required Size sourceSize,
    required Rect cropWindow,
    double sourceAspect = 0,
  }) {
    final Rect px = sourceRectForCrop(
      viewport: viewport,
      sourceSize: sourceSize,
      cropWindow: cropWindow,
      sourceAspect: sourceAspect,
    );
    return Rect.fromLTRB(
      px.left / sourceSize.width,
      px.top / sourceSize.height,
      px.right / sourceSize.width,
      px.bottom / sourceSize.height,
    );
  }

  /// Scale factor mapping the upright stream onto the viewfinder.
  ///
  /// Exposed so tests can assert that the preview is scaled up rather than
  /// letterboxed (the reported bug).
  static double previewScale({
    required Size viewport,
    required double uprightAspectRatio,
  }) {
    if (viewport.width <= 0 || viewport.height <= 0 || uprightAspectRatio <= 0) {
      return 1.0;
    }
    final Size drawn = coverSize(
      viewport: viewport,
      sourceAspect: uprightAspectRatio,
    );
    return math.max(drawn.width / viewport.width, drawn.height / viewport.height);
  }

  /// True when the upright frame covers [viewport] on both axes, i.e. when the
  /// viewfinder is genuinely full-bleed with no letterbox bars.
  static bool isFullBleed({
    required Size viewport,
    required double uprightAspectRatio,
  }) {
    if (viewport.width <= 0 || viewport.height <= 0 || uprightAspectRatio <= 0) {
      return false;
    }
    final Size drawn = coverSize(
      viewport: viewport,
      sourceAspect: uprightAspectRatio,
    );
    final double eps = 0.01;
    return drawn.width >= viewport.width - eps &&
        drawn.height >= viewport.height - eps;
  }

  /// The destination rect inside [target] that a source image should occupy
  /// after a centre "cover" crop.
  ///
  /// Shared by the strip renderer so every photo is cover-cropped identically
  /// no matter its own dimensions.
  static Rect coverRect({
    required Size source,
    required Size target,
  }) {
    if (source.width <= 0 || source.height <= 0) return Offset.zero & target;
    final double sourceAspect = source.width / source.height;
    final double targetAspect = target.width / target.height;

    if (sourceAspect > targetAspect) {
      // Source is wider: keep full height, crop the sides.
      final double w = target.height * sourceAspect;
      return Rect.fromLTWH((target.width - w) / 2, 0, w, target.height);
    }
    // Source is taller: keep full width, crop top and bottom.
    final double h = target.width / sourceAspect;
    return Rect.fromLTWH(0, (target.height - h) / 2, target.width, h);
  }

  /// The sub-rectangle of a [source] image that ends up inside [target] after a
  /// cover fit.
///
/// [coverRect] deliberately overflows the target on one axis; only the part
  /// inside the target survives, so that intersection is what gets mapped back
  /// into source pixels. Scaling the overflowing rect directly (the previous
  /// behaviour) returned coordinates outside the source image.
  static Rect sourceRectForCover({
    required Size source,
    required Size target,
  }) {
    if (source.width <= 0 || source.height <= 0 ||
        target.width <= 0 || target.height <= 0) {
      return Offset.zero & source;
    }
    final Rect drawn = coverRect(source: source, target: target);
    final Rect visible = drawn.intersect(Offset.zero & target);
    if (visible.width <= 0 || visible.height <= 0) return Offset.zero & source;

    final double scaleX = source.width / target.width;
    final double scaleY = source.height / target.height;
    return Rect.fromLTRB(
      visible.left * scaleX,
      visible.top * scaleY,
      visible.right * scaleX,
      visible.bottom * scaleY,
    );
  }
}