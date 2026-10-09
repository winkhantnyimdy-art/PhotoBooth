import 'package:flutter/material.dart';

/// Centralized colour tokens for PhotoBooth — **Concept C, Retro Pop**.
///
/// Values were sampled directly from the approved reference
/// (`design/retro_pop_reference.png`) rather than eyeballed, so the app and
/// the specification cannot drift apart.
///
/// The Retro Pop direction is loud but friendly: a pale yellow chrome, coral
/// red for anything actionable, and pink / cornflower / sunny-yellow as the
/// playful sticker trio. Stickers and the wordmark are finished with a thick
/// navy outline, which is what gives the reference its "decal" character.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Chrome / surfaces
  // ---------------------------------------------------------------------------

  /// Pale yellow app canvas (sampled `#FDF6BC`).
  static const Color background = Color(0xFFFDF6BC);

  /// Card white — layout cards, keepsake paper, sticker outlines.
  static const Color surface = Color(0xFFFFFFFF);

  /// Warm cream panel behind the capture controls (sampled `#FCF6E8`).
  static const Color surfaceMuted = Color(0xFFFCF6E8);

  /// Pale yellow tint used for selected wells and chips.
  static const Color surfaceTint = Color(0xFFFEEEB8);

  /// Neutral scrim for overlays, countdown backdrops and dialogs.
  static const Color scrim = Color(0x59121212);

  // ---------------------------------------------------------------------------
  // Accents
  // ---------------------------------------------------------------------------

  /// Coral red — the one "do it" colour: shutter, selected layout, primary
  /// buttons, and the PhotoBooth wordmark (sampled `#EB3E54`).
  static const Color accent = Color(0xFFEB3E54);

  /// Deeper coral for pressed states and small emphases.
  static const Color accentDeep = Color(0xFFC8283C);

  /// Blush pink for decorative fills.
  static const Color accentSoft = Color(0xFFFFE4E9);

  /// Accessible coral-family ink for accent *text* on pale yellow.
  static const Color accentInk = Color(0xFFB21B2E);

  /// Sunny yellow — active tab pill, Save button, star stickers
  /// (sampled `#FED759`).
  static const Color popYellow = Color(0xFFFED759);

  /// Soft pink — Share button, heart stickers (sampled `#FC8799`).
  static const Color popPink = Color(0xFFFC8799);

  /// Cornflower blue — frame dashes, script footer, blue stickers
  /// (sampled `#8FB8FC`).
  static const Color popBlue = Color(0xFF8FB8FC);

  /// Deep navy — the thick sticker outline and the "Besties Forever" script
  /// (sampled `#2A4B9B`). This is the single most recognisable detail in the
  /// reference: nothing is drawn without it.
  static const Color popNavy = Color(0xFF2A4B9B);

  /// Near-black ink for icons and heavy text.
  static const Color popInk = Color(0xFF121212);

  /// Text and icons rendered on top of [accent].
  static const Color onAccent = Colors.white;

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  /// Charcoal-black primary text (sampled near `#121212`).
  static const Color textPrimary = Color(0xFF121212);

  /// Warm grey secondary text.
  static const Color textSecondary = Color(0xFF6E6A63);

  /// Muted grey for captions and disabled labels.
  static const Color textMuted = Color(0xFF9C978E);

  /// Text and icons rendered on dark surfaces.
  static const Color onDark = Colors.white;

  // ---------------------------------------------------------------------------
  // Lines and status
  // ---------------------------------------------------------------------------

  /// Hairline separators and soft card borders.
  static const Color line = Color(0xFFEFE2C4);

  /// Slightly stronger border for emphasized or selected outlines.
  static const Color lineStrong = Color(0xFFE2D2AE);

  /// Error / destructive accent used for failure feedback.
  static const Color danger = Color(0xFFEB3E54);

  /// Confirmation accent used for success feedback.
  static const Color success = Color(0xFF4F9D7E);

  /// Backdrop behind the live camera feed.
  ///
  /// A camera viewport must stay dark: a device whose camera cannot deliver
  /// frames then reads as an empty viewfinder rather than a blank white page.
  static const Color previewBackdrop = Color(0xFF1B1A18);
}
