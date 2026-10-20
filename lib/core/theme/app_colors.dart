import 'package:flutter/material.dart';

abstract final class AppColors {
  // --- Cream / paper scrapbook surface (Home) ------------------------------
  /// Warm cream canvas, per the Retro Film Pop "background_cream" token.
  static const Color background = Color(0xFFFFF7F0);
  static const Color surface = Color(0xFFFFFDF8);
  static const Color surfaceMuted = Color(0xFFF9F0E7);
  static const Color surfaceTint = Color(0xFFFEEEB8);
  static const Color scrim = Color(0x59121212);

  // --- Pink primary --------------------------------------------------------
  static const Color accent = Color(0xFFFF6696);
  static const Color accentDeep = Color(0xFFE63E7A);
  static const Color accentSoft = Color(0xFFFFE4E9);
  static const Color accentInk = Color(0xFFB21B2E);

  static const Color popYellow = Color(0xFFFED759);
  static const Color popPink = Color(0xFFFF6696);
  static const Color popBlue = Color(0xFF8FB8FC);
  static const Color popNavy = Color(0xFF2A4B9B);
  static const Color popInk = Color(0xFF121212);
  static const Color onAccent = Colors.white;

  static const Color bubblePink = Color(0xFFFF6696);
  static const Color bubbleBlue = Color(0xFF87CEEB);
  static const Color bubbleOutline = Color(0xFFFFFFFF);

  static const Color checkerPink = Color(0xFFFFB6C1);
  static const Color hotPink = Color(0xFFFF4D8D);

  static const Color cherry = Color(0xFFE53935);
  static const Color cherryStem = Color(0xFF4CAF50);
  static const Color bearBrown = Color(0xFF8D6E63);
  static const Color crownGold = Color(0xFFFFD700);
  static const Color rainbowRed = Color(0xFFFF0000);
  static const Color rainbowOrange = Color(0xFFFF7F00);
  static const Color rainbowYellow = Color(0xFFFFFF00);
  static const Color rainbowGreen = Color(0xFF00FF00);
  static const Color rainbowBlue = Color(0xFF0000FF);
  static const Color rainbowPurple = Color(0xFF8B00FF);
  static const Color strawberry = Color(0xFFFF4444);
  static const Color cloudWhite = Color(0xFFF5F5F5);

  static const Color textPrimary = Color(0xFF121212);
  static const Color textSecondary = Color(0xFF6E6A63);
  static const Color textMuted = Color(0xFF9C978E);
  static const Color onDark = Colors.white;

  static const Color line = Color(0xFFEFE2C4);
  static const Color lineStrong = Color(0xFFE2D2AE);
  static const Color danger = Color(0xFFEB3E54);
  static const Color success = Color(0xFF4F9D7E);
  static const Color previewBackdrop = Color(0xFF1B1A18);

  // --- Minimal Dark workspace (PhotoBooth V3) -----------------------------
  /// Locked app background.
  static const Color darkBackground = Color(0xFF101012);

  /// Locked surfaces used by cards, panels, inputs.
  static const Color darkSurface = Color(0xFF1C1C20);

  /// Slightly lifted panels and chips on [darkSurface].
  static const Color darkElevated = Color(0xFF26262C);

  /// Borders/dividers on dark surfaces.
  static const Color darkLine = Color(0xFF303036);

  /// Secondary text on dark surfaces.
  static const Color darkMuted = Color(0xFFA6A6AD);

  /// Subtle silver accent for selection and affordances.
  static const Color silver = Color(0xFFC7C7CC);

  /// Selected pills on [darkSurface].
  ///
  /// A light fill keeps the chosen option obvious at a glance, while the dark
  /// ink keeps the label readable. The old pair used white for both, which is
  /// why selected Frame Theme and Pattern chips rendered as blank capsules.
  static const Color darkChipSelectedSurface = Color(0xFFF2F2F4);
  static const Color darkChipSelectedInk = Color(0xFF16161A);

  /// Disabled pills on [darkSurface].
  ///
  /// Kept lighter than an unselected chip and paired with muted ink, so an
  /// unavailable option cannot be mistaken for one that is merely unselected.
  static const Color darkChipDisabledSurface = Color(0xFF26262C);
  static const Color darkChipDisabledInk = Color(0xFFA6A6AD);
}
