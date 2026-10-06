import 'package:flutter/material.dart';

/// Centralized color tokens for PhotoBooth.
///
/// All visual color decisions live here. Widgets must reference these tokens
/// rather than declaring their own hex/`Color()` values, so the cream/pastel
/// direction stays consistent as features are added.
abstract final class AppColors {
  /// Warm cream/off-white app background.
  static const Color background = Color(0xFFFFF8F1);

  /// Slightly deeper cream for elevated cards and secondary surfaces.
  static const Color surface = Color(0xFFFBEFE4);

  /// Soft pink accent used for primary actions and emphasis.
  static const Color accent = Color(0xFFEE9FB1);

  /// Deeper pink for pressed/hover states and small accents.
  static const Color accentDeep = Color(0xFFD97C93);

  /// Dark charcoal primary text.
  static const Color textPrimary = Color(0xFF2A2522);

  /// Warm grey for secondary text.
  static const Color textSecondary = Color(0xFF6B6259);

  /// Muted warm grey for captions and disabled text.
  static const Color textMuted = Color(0xFF9A8F84);

  /// Hairline separators and subtle borders.
  static const Color line = Color(0xFFEBDDD0);

  /// Text/controls rendered on the accent color.
  static const Color onAccent = Colors.white;
}
