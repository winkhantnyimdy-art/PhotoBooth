/// The photo layouts a session can be composed into.
///
/// [cols] and [rows] are the single source of truth for every surface: the
/// Home card, the Camera crop guide, the Review grid, the Decorate preview and
/// the exported PNG all derive their cells from
/// `PhotoStripGeometry`, which reads these values. Changing a layout therefore
/// cannot desynchronise the previews from the export.
///
/// Grid order is row-major (left to right, then down), which is also capture
/// order.
enum PhotoLayout {
  /// Four portrait frames stacked vertically - the Korean photo-booth strip and
  /// the default, because it keeps faces large and unforeshortened.
  korean4('4 CUT', 'Popular', 1, 4),

  /// Four frames in a balanced two-by-two arrangement.
  grid4('2×2', null, 2, 2),

  /// Two frames stacked vertically.
  pair2('2 CUT', null, 1, 2),

  /// Six frames in a 2x3 arrangement.
  cut6('6 CUT', null, 2, 3),

  /// Three frames in a single column.
  cut3('3 CUT', null, 1, 3);

  const PhotoLayout(this.label, this.badge, this.cols, this.rows);

  /// Short name shown on the Home card.
  final String label;

  /// Optional marketing badge, e.g. "Popular".
  final String? badge;

  final int cols;
  final int rows;

  int get photoCount => cols * rows;

  /// True when every cell is portrait (taller than wide).
  bool get isColumnStack => cols == 1;

  String get contentSignature => '${cols}x$rows';

  String get description => '$photoCount photos · $cols×$rows';

  /// Aspect ratio (width / height) of one cell for this layout.
  ///
  /// Column stacks use a 3:4 portrait cell; multi-column grids use 3:4 as well
  /// so every frame in the app shares one frame shape and users are never
  /// surprised when switching layouts mid-session.
  double get cellAspect => 3.0 / 4.0;

  /// The largest layout that can hold [availablePhotos] captured photos.
  ///
  /// Used when the user switches layout mid-session: picking a layout that fits
  /// the photos already taken means no capture is ever lost. Returns null only
  /// when there are no photos at all.
  static PhotoLayout? fitForPhotos(int availablePhotos) {
    if (availablePhotos <= 0) return null;
    PhotoLayout? best;
    for (final PhotoLayout candidate in PhotoLayout.values) {
      if (candidate.photoCount <= availablePhotos &&
          (best == null || candidate.photoCount > best.photoCount)) {
        best = candidate;
      }
    }
    return best;
  }
}

/// The layout a fresh session starts with.
const PhotoLayout kDefaultPhotoLayout = PhotoLayout.korean4;