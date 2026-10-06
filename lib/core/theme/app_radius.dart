import 'package:flutter/material.dart';

/// Centralized border-radius tokens for the rounded UI direction.
///
/// Use [R.xs] through [R.xl] for discrete sizes and [R.pill] for fully
/// rounded controls (chips, buttons, avatar shapes).
abstract final class R {
  /// 4 logical pixels — used for small internal elements.
  static const double xs = 4;

  /// 10 logical pixels — small buttons, input fields.
  static const double sm = 10;

  /// 18 logical pixels — standard cards and controls.
  static const double md = 18;

  /// 28 logical pixels — large cards, sheets.
  static const double lg = 28;

  /// 40 logical pixels — hero surfaces.
  static const double xl = 40;

  /// Fully rounded.
  static const double pill = 999;

  /// Convenience [BorderRadius] for a uniform [size].
  static BorderRadius all(double size) => BorderRadius.circular(size);

  /// Convenience [BorderRadius] for a uniform pill shape.
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
}
