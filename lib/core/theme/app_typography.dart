import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralized type scale for PhotoBooth.
///
/// Screens compose copy from these roles instead of declaring font sizes inline,
/// which keeps hierarchy consistent as the visual design evolves. Sizes stay
/// modest so text remains readable on 320dp-wide screens and when the platform
/// text scale is increased.
abstract final class AppText {
  /// Screen-defining headline. Used once per screen at most.
  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    height: 1.15,
    color: AppColors.textPrimary,
  );

  /// Screen headline, e.g. "Your photos are ready!".
  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// Section or card heading.
  static const TextStyle heading = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  /// Default reading style.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  /// Emphasised inline label.
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  /// Secondary supporting copy and metadata.
  static const TextStyle caption = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textSecondary,
  );

  /// Small uppercase eyebrow used above groups of controls.
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.4,
    color: AppColors.textMuted,
  );

  /// Primary button label.
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
  );

  /// Compact button / chip label.
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  /// Tabular numerals for countdowns and counters.
  static const TextStyle numeric = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w900,
    letterSpacing: -1,
    height: 1,
    color: AppColors.textPrimary,
  );

  /// The PhotoBooth wordmark: heavy, tight and coloured, so it can be dropped
  /// straight into the white-halo decal treatment used on the header and in
  /// the exported strip's caption band.
  static const TextStyle wordmark = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.6,
    height: 1.1,
    color: AppColors.accent,
  );
}
