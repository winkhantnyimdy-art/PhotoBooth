import 'dart:math' as math;

/// Decides how large a photo needs to be **decoded** for an interactive
/// preview.
///
/// ## Why this exists
///
/// `Image.file` and `Image.memory` decode a photo at its stored resolution.
/// A single iPhone capture is 12 megapixels, so one decode costs roughly
/// 48 MB of RGBA. A four-shot strip in the Decorate preview meant four such
/// bitmaps live at once - about 190 MB - which on mobile Safari is enough to
/// make the editor stutter, drop frames and get a tab killed. The bytes are
/// also re-read and re-decoded for every thumbnail, the review grid and the
/// album, because each surface asked for a full-size image and simply scaled
/// it down at paint time.
///
/// Decoding at the size actually displayed fixes this without touching output
/// quality: the exporter never goes through here. It reads the original bytes
/// and decodes them at `cell.width * 2`, which is what keeps exported PNGs
/// crisp. Only the interactive previews are downscaled, and only to a size
/// still above the device pixel ratio of the target surface.
abstract final class PreviewDecode {
  /// Upper bound for a preview decode, in pixels.
  ///
  /// Roughly 1024px across covers any phone or tablet preview at 2x with
  /// headroom, while capping the worst-case bitmap at about 4 MB.
  static const int maxWidth = 1024;

  /// Lower bound, so a tiny widget still decodes enough to stay sharp.
  static const int minWidth = 48;

  /// The decode width for a preview that will be [logicalWidth] wide on a
  /// device with [devicePixelRatio], or null when [logicalWidth] is unknown.
  ///
  /// Null means "do not downscale", which keeps existing callers working and
  /// is the safe choice when a size has not been measured yet.
  static int? forWidth(double logicalWidth, double devicePixelRatio) {
    if (logicalWidth <= 0 || !logicalWidth.isFinite) return null;
    if (devicePixelRatio <= 0 || !devicePixelRatio.isFinite) return null;
    final double px = logicalWidth * devicePixelRatio;
    if (px <= 0) return null;
    return math.max(minWidth, px.ceil().clamp(minWidth, maxWidth));
  }

  /// The decode width for a square preview of [logicalSize].
  static int? forSize(double logicalSize, double devicePixelRatio) =>
      forWidth(logicalSize, devicePixelRatio);
}