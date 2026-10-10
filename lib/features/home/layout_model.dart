enum PhotoLayout {
  cut4('4 CUT', 'Popular', 2, 2),
  cut6('6 CUT', null, 2, 3),
  cut2('2 CUT', null, 2, 1),
  cut3('3 CUT', null, 1, 3);

  const PhotoLayout(this.label, this.badge, this.cols, this.rows);

  final String label;
  final String? badge;
  final int cols;
  final int rows;

  int get photoCount => cols * rows;

  String get contentSignature => '${cols}x$rows';

  String get description => '$photoCount photos · $cols×$rows';
}
