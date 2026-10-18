import 'package:flutter/material.dart';

import '../../core/filters/photo_effect.dart';
import '../../core/filters/photo_filter.dart';
import '../home/layout_model.dart';
import 'frame_theme.dart';

/// Formats the stamped date used by the composition footer.
///
/// Shared by the Decorate live preview and the exported PNG so the date the
/// user sees while styling is character-for-character the date they get.
String formatExportDate(DateTime date) =>
    '${date.year}.${_twoDigits(date.month)}.${_twoDigits(date.day)}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Possible undo actions that can be performed on the decoration state.
enum UndoRedoAction {
  stickerAdded,
  stickerRemoved,
  stickerMoved,
  stickerScaled,
  stickerRotated,
  stickerDuplicated,
  stickerReordered,
  textAdded,
  textRemoved,
  textEdited,
  textMoved,
  filterChanged,
  adjustmentsReset,
  frameThemeChanged,
}

/// The decoration state for a PhotoBooth composition.
///
/// This model represents the user's customization choices for the
/// final photo strip composition. It is passed from DecorateScreen to
/// ExportScreen (Checkpoint 5) for final rendering.
///
/// No rendered bitmap bytes are stored here  Eonly the configuration
/// needed to generate the final image later.
class DecorationState {
  const DecorationState({
    required this.layout,
    required this.background,
    required this.style,
    this.showDate = false,
    this.stickers = const [],
    this.texts = const [],
    this.filter = PhotoEffect.original,
    this.filterIntensity = 1.0,
    this.frameStyle = FrameStyle.polkaDot,
    this.frameTheme = FrameTheme.retroPop,
    this.adjustments = const PhotoAdjustments(),
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

  /// Free text lines the user has placed on the strip.
  final List<TextPlacement> texts;

  /// The chosen effect applied to every photo.
  final PhotoEffect filter;

  /// How strongly [filter] is applied, 0 (none) … 1 (full).
  final double filterIntensity;

  /// The paper/border treatment around the strip.
  final FrameStyle frameStyle;

  /// The premium frame theme  Ea complete visual identity.
  final FrameTheme frameTheme;

  /// Manual brightness/contrast/saturation/warmth tweaks.
  final PhotoAdjustments adjustments;

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
    List<TextPlacement>? texts,
    PhotoEffect? filter,
    double? filterIntensity,
    FrameStyle? frameStyle,
    FrameTheme? frameTheme,
    PhotoAdjustments? adjustments,
    DateTime? dateOverride,
  }) {
    return DecorationState(
      layout: layout ?? this.layout,
      background: background ?? this.background,
      style: style ?? this.style,
      showDate: showDate ?? this.showDate,
      stickers: stickers ?? this.stickers,
      texts: texts ?? this.texts,
      filter: filter ?? this.filter,
      filterIntensity: filterIntensity ?? this.filterIntensity,
      frameStyle: frameStyle ?? this.frameStyle,
      frameTheme: frameTheme ?? this.frameTheme,
      adjustments: adjustments ?? this.adjustments,
      dateOverride: dateOverride ?? this.dateOverride,
    );
  }
}

/// The paper/border treatment that frames the whole strip.
enum FrameStyle {
  polkaDot('Polka Dot'),
  filmEdge('Film Edge'),
  scallop('Scallop'),
  minimal('Minimal');

  const FrameStyle(this.label);

  final String label;
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
/// bounds so positions are device-independent. [scale] and [rotation] allow
/// pinch-resize and rotation gestures.
class StickerPlacement {
  const StickerPlacement({
    required this.type,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  /// The type of sticker (emoji/icon-based).
  final StickerType type;

  /// Horizontal position (0.0 = left, 1.0 = right).
  final double x;

  /// Vertical position (0.0 = top, 1.0 = bottom).
  final double y;

  /// Size multiplier (1.0 = default, 0.5 = half, 2.0 = double).
  final double scale;

  /// Rotation in radians.
  final double rotation;

  /// Creates a copy with the given fields replaced.
  StickerPlacement copyWith({
    StickerType? type,
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) {
    return StickerPlacement(
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StickerPlacement &&
      other.type == type &&
      other.x == x &&
      other.y == y &&
      other.scale == scale &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(type, x, y, scale, rotation);
}

/// A free-text caption placed on the strip.
///
/// Position is normalised (0…1) against the whole strip so the same text lands
/// in the same place on the Decorate preview and the exported PNG. [scale] is
/// the font size expressed as a fraction of the strip width, which keeps the
/// text proportional at every preview size.
class TextPlacement {
  const TextPlacement({
    required this.text,
    required this.x,
    required this.y,
    this.color = Colors.white,
    this.scale = 0.07,
  });

  /// The caption itself.
  final String text;

  /// Horizontal position (0 = left, 1 = right), centre-anchored.
  final double x;

  /// Vertical position (0 = top, 1 = bottom), centre-anchored.
  final double y;

  /// Fill colour of the text.
  final Color color;

  /// Font size as a fraction of the strip width.
  final double scale;

  /// Creates a copy with the given fields replaced.
  TextPlacement copyWith({
    String? text,
    double? x,
    double? y,
    Color? color,
    double? scale,
  }) {
    return TextPlacement(
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      color: color ?? this.color,
      scale: scale ?? this.scale,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TextPlacement &&
      other.text == text &&
      other.x == x &&
      other.y == y &&
      other.color == color &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(text, x, y, color, scale);
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

// -----------------------------------------------------------------------------
// Undo/Redo
// -----------------------------------------------------------------------------

/// Manages undo and redo for decoration edits.
///
/// Every sticker/text action pushes the *previous* state onto the undo stack,
/// so undo restores exactly what the user had before the action. Redo stores
/// the state that was undone, allowing the user to step forward again.
///
/// The stacks are capped at 30 entries to bound memory on long editing
/// sessions.
class UndoRedoDecoration {
  UndoRedoDecoration({this.capacity = 30});

  final int capacity;
  final List<DecorationState> _undoStack = <DecorationState>[];
  final List<DecorationState> _redoStack = <DecorationState>[];

  /// Whether there is an action available to undo.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there is an action available to redo.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Records a new state, pushing the previous one onto the undo stack.
  ///
  /// Call this *before* applying the edit to [next]. The [previous] state is
  /// what undo will restore.
  void record(DecorationState previous) {
    _undoStack.add(previous);
    if (_undoStack.length > capacity) {
      _undoStack.removeAt(0);
    }
    // Any new action invalidates the redo history.
    _redoStack.clear();
  }

  /// Returns the state to restore when undoing, or null if nothing to undo.
  DecorationState? undo(DecorationState current) {
    if (_undoStack.isEmpty) return null;
    _redoStack.add(current);
    return _undoStack.removeLast();
  }

  /// Returns the state to restore when redoing, or null if nothing to redo.
  DecorationState? redo(DecorationState current) {
    if (_redoStack.isEmpty) return null;
    _undoStack.add(current);
    return _redoStack.removeLast();
  }

  /// Clears both stacks (e.g. when starting a new composition).
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
