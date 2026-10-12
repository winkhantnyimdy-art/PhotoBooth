import 'package:flutter/material.dart';

import 'decoration_model.dart';

/// The premium frame themes offered in the Decorate editor.
///
/// A theme is a complete visual identity - paper colour, border artwork,
/// corner accents and wordmark typography - not merely a background tint. Each
/// one paints its own border and accents through
/// `FrameThemePainter`, and the *same* painter runs on the Decorate preview and
/// inside the PNG renderer, so the preview is an honest picture of the export.
///
/// [retroPop] is the original Retro Film Pop treatment, kept so existing
/// compositions still look the way they did.
enum FrameTheme {
  retroPop('Retro Pop'),
  y2kPop('Y2K Pop'),
  vintageFilm('Vintage Film'),
  cherryBlossom('Cherry Blossom'),
  kawaii('Kawaii'),
  minimalWhite('Minimal White'),
  darkFilm('Dark Film'),
  birthday('Birthday');

  const FrameTheme(this.label);

  /// Name shown on the theme chip.
  final String label;

  /// A short line of supporting copy for the chip's tooltip.
  String get tagline {
    switch (this) {
      case FrameTheme.retroPop:
        return 'Polka-dot pink scrapbook';
      case FrameTheme.y2kPop:
        return 'Chrome, bubbles and starbursts';
      case FrameTheme.vintageFilm:
        return 'Sepia rails and an orange date stamp';
      case FrameTheme.cherryBlossom:
        return 'Sakura petals on soft pink';
      case FrameTheme.kawaii:
        return 'Pastel scallops and tiny hearts';
      case FrameTheme.minimalWhite:
        return 'Quiet hairline and small caps';
      case FrameTheme.darkFilm:
        return 'Black rail, amber marks, sprocket edge';
      case FrameTheme.birthday:
        return 'Bunting, confetti and a cake';
    }
  }

  /// Legacy border treatment this theme builds on.
  ///
  /// Reusing the original [FrameStyle] painters where they already suit the
  /// theme keeps the artwork in one place instead of forking it.
  FrameStyle get baseBorder {
    switch (this) {
      case FrameTheme.retroPop:
      case FrameTheme.cherryBlossom:
        return FrameStyle.polkaDot;
      case FrameTheme.vintageFilm:
      case FrameTheme.darkFilm:
        return FrameStyle.filmEdge;
      case FrameTheme.kawaii:
        return FrameStyle.scallop;
      case FrameTheme.minimalWhite:
        return FrameStyle.minimal;
      case FrameTheme.y2kPop:
      case FrameTheme.birthday:
        return FrameStyle.minimal;
    }
  }

  /// The colour identity of the theme.
  FrameThemeSpec get spec {
    switch (this) {
      case FrameTheme.retroPop:
        return const FrameThemeSpec(
          paper: Color(0xFFFFF7F0),
          ink: Color(0xFF121212),
          accent: Color(0xFFFF6696),
          secondary: Color(0xFFFED759),
          wordmark: 'PHOTOBOOTH',
          onDarkPaper: false,
          showsDateStamp: false,
        );
      case FrameTheme.y2kPop:
        return const FrameThemeSpec(
          paper: Color(0xFFF2F6FF),
          ink: Color(0xFF1B2440),
          accent: Color(0xFF6C7BFF),
          secondary: Color(0xFF00D9E8),
          wordmark: 'Y2K POP',
          onDarkPaper: false,
          showsDateStamp: false,
        );
      case FrameTheme.vintageFilm:
        return const FrameThemeSpec(
          paper: Color(0xFFF3E7CE),
          ink: Color(0xFF3A2C1B),
          accent: Color(0xFFC8712F),
          secondary: Color(0xFF8C6239),
          wordmark: 'PHOTOBOOTH',
          onDarkPaper: false,
          showsDateStamp: true,
        );
      case FrameTheme.cherryBlossom:
        return const FrameThemeSpec(
          paper: Color(0xFFFFF1F5),
          ink: Color(0xFF6B2B3E),
          accent: Color(0xFFF2A0BE),
          secondary: Color(0xFF7BA05B),
          wordmark: 'PHOTOBOOTH',
          onDarkPaper: false,
          showsDateStamp: false,
        );
      case FrameTheme.kawaii:
        return const FrameThemeSpec(
          paper: Color(0xFFFFF7FB),
          ink: Color(0xFF5B4A6B),
          accent: Color(0xFFFFB3D1),
          secondary: Color(0xFFBFE6FF),
          wordmark: 'PHOTOBOOTH',
          onDarkPaper: false,
          showsDateStamp: false,
        );
      case FrameTheme.minimalWhite:
        return const FrameThemeSpec(
          paper: Color(0xFFFFFFFF),
          ink: Color(0xFF2B2B2B),
          accent: Color(0xFFE4E4E4),
          secondary: Color(0xFF9A9A9A),
          wordmark: 'PHOTO BOOTH',
          onDarkPaper: false,
          showsDateStamp: false,
        );
      case FrameTheme.darkFilm:
        return const FrameThemeSpec(
          paper: Color(0xFF141416),
          ink: Color(0xFFF2EFE8),
          accent: Color(0xFFE08A3C),
          secondary: Color(0xFF6F6A63),
          wordmark: 'PHOTOBOOTH',
          onDarkPaper: true,
          showsDateStamp: true,
        );
      case FrameTheme.birthday:
        return const FrameThemeSpec(
          paper: Color(0xFFFFF6E9),
          ink: Color(0xFF3D2B33),
          accent: Color(0xFFFF5D8F),
          secondary: Color(0xFF5AC8FA),
          wordmark: 'HAPPY DAY',
          onDarkPaper: false,
          showsDateStamp: false,
        );
    }
  }
}

/// The concrete colours and typography choices for a [FrameTheme].
@immutable
class FrameThemeSpec {
  const FrameThemeSpec({
    required this.paper,
    required this.ink,
    required this.accent,
    required this.secondary,
    required this.wordmark,
    required this.onDarkPaper,
    required this.showsDateStamp,
  });

  /// The paper colour behind the photo grid.
  final Color paper;

  /// Primary text/ink colour on the paper.
  final Color ink;

  /// The theme's signature colour, used for borders and accents.
  final Color accent;

  /// A supporting colour for two-tone artwork.
  final Color secondary;

  /// The footer wordmark. Distinct per theme so the typography reads as part
  /// of the identity rather than a constant.
  final String wordmark;

  /// True when the paper is dark and ink colours must invert.
  final bool onDarkPaper;

  /// Whether this theme always prints the date stamp in its footer.
  final bool showsDateStamp;
}