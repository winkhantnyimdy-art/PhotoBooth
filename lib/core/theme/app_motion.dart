import 'package:flutter/material.dart';

/// Centralized motion tokens.
///
/// PhotoBooth animates sparingly — selection feedback, state crossfades and a
/// shutter press — so the app feels considered rather than busy. Every animated
/// surface routes its duration through [of], which collapses motion to zero
/// when the platform has "remove animations" enabled.
abstract final class AppMotion {
  /// Selection and chip feedback.
  static const Duration fast = Duration(milliseconds: 140);

  /// Default state transition (crossfades, panel entrances).
  static const Duration medium = Duration(milliseconds: 260);

  /// Deliberate, slower reveals such as the finished keepsake.
  static const Duration slow = Duration(milliseconds: 420);

  /// Default easing — decelerates quickly then settles.
  static const Curve curve = Curves.easeOutCubic;

  /// Slight emphasis for selection pops.
  static const Curve emphasis = Curves.easeOutBack;

  /// Returns [duration], or [Duration.zero] when reduced motion is requested.
  static Duration of(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}
