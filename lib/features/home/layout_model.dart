/// Layout options available in the PhotoBooth home screen.
enum PhotoLayout {
  cut4('4 CUT', 'Popular', 2, 2),
  cut2('2 CUT', null, 2, 1);

  const PhotoLayout(this.label, this.badge, this.cols, this.rows);

  /// Human-readable label shown on the option chip.
  final String label;

  /// Optional badge text (e.g. 'Popular').
  final String? badge;

  /// Grid columns for this layout.
  final int cols;

  /// Grid rows for this layout.
  final int rows;

  /// Number of photos this layout holds — the number of captures and the
  /// number of grid cells always agree.
  int get photoCount => cols * rows;

  /// Grid arrangement signature, e.g. '2x2'. Two layouts are visually
  /// identical only if their signatures match.
  String get contentSignature => '${cols}x$rows';

  /// Short human description, e.g. '4 photos · 2×2'.
  String get description => '$photoCount photos · $cols×$rows';
}
