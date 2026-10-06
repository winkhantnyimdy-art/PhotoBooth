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
}
