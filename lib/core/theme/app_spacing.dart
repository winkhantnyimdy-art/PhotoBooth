/// Centralized spacing tokens.
///
/// Prefer these over literal pixel values so spacing stays consistent across
/// features. The scale is intentionally coarse so every screen lands on the
/// same rhythm.
abstract final class S {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;
  static const double xxl = 64;

  /// Default horizontal page gutter. Screens use this so every page aligns.
  static const double gutter = md;

  /// Minimum comfortable interactive height for a tappable control.
  static const double touchTarget = 48;
}
