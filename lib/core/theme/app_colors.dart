import 'package:flutter/material.dart';

/// Centralized color tokens for PhotoBooth.
///
/// All visual color decisions live here. Widgets must reference these tokens
/// rather than declaring their own hex/`Color()` values, so the cream/pastel
/// direction stays consistent as features are added.
///
/// The palette targets a warm, premium photo-booth feel: a cream canvas, soft
/// pastel pink accents and elegant charcoal typography.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  /// Warm cream app canvas.
  static const Color background = Color(0xFFFFF9F5);

  /// Pure white card / keepsake surface. Sits above [background].
  static const Color surface = Color(0xFFFFFFFF);

  /// Sunken cream panel used for grouped controls and wells.
  static const Color surfaceMuted = Color(0xFFFDF0E6);

  /// Soft pink wash for selected and highlighted regions.
  static const Color surfaceTint = Color(0xFFFFE4EB);

  /// Neutral scrim for image overlays, countdown backdrops and dialogs.
  static const Color scrim = Color(0x59302B30);

  // ---------------------------------------------------------------------------
  // Accents
  // ---------------------------------------------------------------------------

  /// Primary pastel pink — primary actions, active states, progress.
  static const Color accent = Color(0xFFF4A7B9);

  /// Lightest pink — decorative fills and soft chips.
  static const Color accentSoft = Color(0xFFFFE4EB);

  /// Saturated pink — pressed states, emphasis fills, decorative overlays.
  static const Color accentDeep = Color(0xFFE3819A);

  /// Dark pink with AA contrast on cream — accent *text* on light surfaces.
  static const Color accentInk = Color(0xFF9C4A61);

  /// Text and icons rendered on top of [accent].
  static const Color onAccent = Colors.white;

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  /// Charcoal primary text.
  static const Color textPrimary = Color(0xFF302B30);

  /// Warm grey secondary text.
  static const Color textSecondary = Color(0xFF81777D);

  /// Muted grey for captions, hints and disabled labels.
  static const Color textMuted = Color(0xFFAFA4A9);

  /// Text and icons rendered on dark surfaces such as the charcoal frame.
  static const Color onDark = Colors.white;

  // ---------------------------------------------------------------------------
  // Lines, dividers and status
  // ---------------------------------------------------------------------------

  /// Hairline separators and subtle card borders.
  static const Color line = Color(0xFFF2E4DA);

  /// Slightly stronger border for emphasized or selected outlines.
  static const Color lineStrong = Color(0xFFE6D3C7);

  /// Error / destructive accent used for failure feedback.
  static const Color danger = Color(0xFFC8503F);

  /// Confirmation accent used for success feedback.
  static const Color success = Color(0xFF4F9D7E);
}
