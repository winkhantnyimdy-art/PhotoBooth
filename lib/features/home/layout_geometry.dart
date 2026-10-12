import 'package:flutter/material.dart';

import 'layout_model.dart';

/// Single source of truth for how a [PhotoLayout] maps onto a photo strip.
///
/// Every surface that depicts the composition — the Home layout card, the
/// Review grid, the Decorate live preview and the exported PNG — derives its
/// grid from this class. Previously each surface computed its own cell size and
/// they drifted apart: the previews drew square cells while the renderer
/// produced 576x976 (4 CUT) and 576x1168 (2 CUT) cells, which silently
/// stretched every captured face. Deriving all surfaces from here keeps them
/// in agreement and keeps rendering deterministic.
abstract final class PhotoStripGeometry {
  /// Export canvas width in pixels. Fixed so exports are device independent.
  static const double exportWidth = 1200.0;

  /// Space between the canvas edge and the outermost photo cells.
  static const double outerPadding = 16.0;

  /// Space between neighbouring photo cells.
  static const double gutter = 16.0;

  /// Height reserved at the bottom of the canvas for branding and the date.
  static const double footerHeight = 150.0;

  /// Intended shape of a single photo cell (width / height).
  ///
  /// Cell shape now comes from the layout itself (3:4 portrait) rather than a
  /// hard-coded square, so a Korean 4-cut shows tall portrait frames instead of
  /// squashed ones. Because the renderer cover-crops each decoded photo into the
  /// cell, this ratio also keeps captured faces undistorted.
  static double cellAspect(PhotoLayout layout) => layout.cellAspect;

  /// Nominal sticker diameter in export pixels.
  ///
  /// Shared so a sticker occupies the same share of the composition on the
  /// Decorate preview and on the exported PNG.
  static const double stickerSize = 34.0;

  /// Ratio of the gutter to a photo cell, used by previews that size cells from
  /// the available space so their gaps match the exported strip.
  static double gutterRatio(PhotoLayout layout) => gutter / cellWidth(layout);

  /// Width of one photo cell.
  static double cellWidth(PhotoLayout layout) {
    final double usable = exportWidth - (outerPadding * 2);
    return (usable - (layout.cols - 1) * gutter) / layout.cols;
  }

  /// Height of one photo cell.
  static double cellHeight(PhotoLayout layout) =>
      cellWidth(layout) / cellAspect(layout);

  /// Height of the photo grid, excluding the branding footer.
  static double contentHeight(PhotoLayout layout) {
    return (cellHeight(layout) * layout.rows) +
        (outerPadding * 2) +
        ((layout.rows - 1) * gutter);
  }

  /// Full canvas height including the branding footer.
  static double totalHeight(PhotoLayout layout) =>
      contentHeight(layout) + footerHeight;

  /// Width / height of the finished strip, used to size previews without
  /// stretching or cropping.
  static double aspectRatio(PhotoLayout layout) =>
      exportWidth / totalHeight(layout);

  /// Top-left corner of the photo cell at [index], in canvas coordinates.
  ///
  /// Index order is row-major (left to right, then down), matching capture
  /// order, so photo order is identical on every surface.
  static Rect cellRect(PhotoLayout layout, int index) {
    final int row = index ~/ layout.cols;
    final int col = index % layout.cols;
    final double w = cellWidth(layout);
    final double h = cellHeight(layout);
    return Rect.fromLTWH(
      outerPadding + (col * (w + gutter)),
      outerPadding + (row * (h + gutter)),
      w,
      h,
    );
  }
}
