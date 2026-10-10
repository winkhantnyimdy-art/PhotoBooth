import 'package:flutter/material.dart';

import '../home/layout_model.dart';

/// Formats the stamped date used by the composition footer.
///
/// Shared by the Decorate live preview and the exported PNG so the date the
/// user sees while styling is character-for-character the date they get.
String formatExportDate(DateTime date) =>
    '${date.year}.${_twoDigits(date.month)}.${_twoDigits(date.day)}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// The decoration state for a PhotoBooth composition.
///
/// This model represents the user's customization choices for the
/// final photo strip composition. It is passed from DecorateScreen to
/// ExportScreen (Checkpoint 5) for final rendering.
///
/// No rendered bitmap bytes are stored here — only the configuration
/// needed to generate the final image later.
class DecorationState {
  const DecorationState({
    required this.layout,
    required this.background,
    required this.style,
    this.showDate = false,
    this.stickers = const [],
    this.dateOverride, // for testability
  });

  /// The layout that determines photo placement and count.
  final PhotoLayout layout;

  /// Background/frame color choice.
  final BackgroundChoice background;

  /// Decorative style choice.
  final DecorativeStyle style;

  /// Whether to show the date in the branding area.
  final bool showDate;

  /// User-placed stickers in the composition.
  final List<StickerPlacement> stickers;

  /// Optional fixed date for testing (uses local session date if null).
  final DateTime? dateOverride;

  /// Returns the date to display, either the override or current date.
  DateTime get displayDate => dateOverride ?? DateTime.now();

  /// Creates a copy with the given fields replaced.
  DecorationState copyWith({
    PhotoLayout? layout,
    BackgroundChoice? background,
    DecorativeStyle? style,
    bool? showDate,
    List<StickerPlacement>? stickers,
    DateTime? dateOverride,
  }) {
    return DecorationState(
      layout: layout ?? this.layout,
      background: background ?? this.background,
      style: style ?? this.style,
      showDate: showDate ?? this.showDate,
      stickers: stickers ?? this.stickers,
      dateOverride: dateOverride ?? this.dateOverride,
    );
  }
}

/// Background/frame color choices for the photo strip.
///
/// Aligned with the app palette so an exported strip feels like the product
/// that produced it.
enum BackgroundChoice {
  cream('Cream', Color(0xFFFFF9F5)),
  softPink('Soft Pink', Color(0xFFFFE4EB)),
  white('White', Color(0xFFFFFFFF)),
  charcoal('Charcoal', Color(0xFF302B30)),
  lavender('Lavender', Color(0xFFF2ECFF)),
  skyBlue('Sky Blue', Color(0xFFEAF4FB));

  const BackgroundChoice(this.label, this.color);

  final String label;
  final Color color;
}

/// Decorative style choices for ornamental accents.
enum DecorativeStyle {
  clean('Clean'),
  hearts('Hearts'),
  stars('Stars'),
  sparkle('Sparkle');

  const DecorativeStyle(this.label);

  final String label;
}

/// A user-placed sticker in the composition.
///
/// Uses normalized coordinates (0.0-1.0) relative to the composition
/// bounds so positions are device-independent.
class StickerPlacement {
  const StickerPlacement({
    required this.type,
    required this.x,
    required this.y,
  });

  /// The type of sticker (emoji/icon-based).
  final StickerType type;

  /// Horizontal position (0.0 = left, 1.0 = right).
  final double x;

  /// Vertical position (0.0 = top, 1.0 = bottom).
  final double y;

  /// Creates a copy with the given fields replaced.
  StickerPlacement copyWith({StickerType? type, double? x, double? y}) {
    return StickerPlacement(
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}

enum StickerType {
  heart,
  star,
  sparkle,
  cherry,
  bow,
  smiley,
  bear,
  crown,
  car,
  rainbow,
  strawberry,
  cloud,
  flower,
  love,
  cuteText,
  hiBubble,
  bunny;

  String get label {
    switch (this) {
      case StickerType.heart:
        return 'Heart';
      case StickerType.star:
        return 'Star';
      case StickerType.sparkle:
        return 'Sparkle';
      case StickerType.cherry:
        return 'Cherry';
      case StickerType.bow:
        return 'Bow';
      case StickerType.smiley:
        return 'Smiley';
      case StickerType.bear:
        return 'Bear';
      case StickerType.crown:
        return 'Crown';
      case StickerType.car:
        return 'Car';
      case StickerType.rainbow:
        return 'Rainbow';
      case StickerType.strawberry:
        return 'Strawberry';
      case StickerType.cloud:
        return 'Cloud';
      case StickerType.flower:
        return 'Flower';
      case StickerType.love:
        return 'Love';
      case StickerType.cuteText:
        return 'Cute!';
      case StickerType.hiBubble:
        return 'Hi!';
      case StickerType.bunny:
        return 'Bunny';
    }
  }
}
