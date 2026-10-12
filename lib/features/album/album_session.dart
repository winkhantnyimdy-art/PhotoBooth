import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../decorate/decoration_model.dart';
import '../decorate/frame_theme.dart';
import '../home/layout_model.dart';
import '../../core/filters/photo_filter.dart';

/// A saved PhotoBooth session that can be reopened for editing or re-export.
///
/// Contains the original captured photos (as bytes for persistence), the complete
/// decoration state, and a generated thumbnail for the album grid.
class AlbumSession {
  const AlbumSession({
    required this.id,
    required this.createdAt,
    required this.layout,
    required this.photoBytes,
    required this.decorationState,
    required this.thumbnailBytes,
    this.name,
  });

  /// Unique identifier for this session.
  final String id;

  /// When this session was originally created.
  final DateTime createdAt;

  /// The photo layout used for this session.
  final PhotoLayout layout;

  /// Original captured photo bytes, in capture order.
  ///
  /// Stored as bytes rather than file paths because temporary camera files
  /// are not guaranteed to persist across app launches.
  final List<Uint8List> photoBytes;

  /// Complete decoration state at the time of saving.
  final DecorationState decorationState;

  /// Thumbnail image bytes for the album grid (typically 200x200).
  final Uint8List thumbnailBytes;

  /// Optional user-assigned name.
  final String? name;

  /// Number of photos in this session.
  int get photoCount => photoBytes.length;

  /// Display name for the album grid.
  String get displayName => name ?? 'Session ${_formatDate(createdAt)}';

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  /// Creates a copy with the given fields replaced.
  AlbumSession copyWith({
    String? id,
    DateTime? createdAt,
    PhotoLayout? layout,
    List<Uint8List>? photoBytes,
    DecorationState? decorationState,
    Uint8List? thumbnailBytes,
    String? name,
  }) {
    return AlbumSession(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      layout: layout ?? this.layout,
      photoBytes: photoBytes ?? this.photoBytes,
      decorationState: decorationState ?? this.decorationState,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      name: name ?? this.name,
    );
  }

  /// Converts to a JSON-serializable map.
  ///
  /// Binary data is base64-encoded for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'layout': layout.name,
      'photoBytes': photoBytes.map((b) => base64Encode(b)).toList(),
      'decorationState': _decorationStateToJson(decorationState),
      'thumbnailBytes': base64Encode(thumbnailBytes),
      'name': name,
    };
  }

  /// Creates an [AlbumSession] from a JSON map.
  ///
  /// Binary data is base64-decoded.
  factory AlbumSession.fromJson(Map<String, dynamic> json) {
    return AlbumSession(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      layout: PhotoLayout.values.byName(json['layout'] as String),
      photoBytes: (json['photoBytes'] as List)
          .map((s) => base64Decode(s as String))
          .toList(),
      decorationState: _decorationStateFromJson(json['decorationState'] as Map<String, dynamic>),
      thumbnailBytes: base64Decode(json['thumbnailBytes'] as String),
      name: json['name'] as String?,
    );
  }
}

/// Converts [DecorationState] to a JSON-serializable map.
Map<String, dynamic> _decorationStateToJson(DecorationState state) {
  return {
    'layout': state.layout.name,
    'background': state.background.name,
    'style': state.style.name,
    'showDate': state.showDate,
    'stickers': state.stickers.map(_stickerPlacementToJson).toList(),
    'texts': state.texts.map(_textPlacementToJson).toList(),
    'filter': state.filter.name,
    'filterIntensity': state.filterIntensity,
    'frameStyle': state.frameStyle.name,
    'frameTheme': state.frameTheme.name,
    'adjustments': _photoAdjustmentsToJson(state.adjustments),
    'dateOverride': state.dateOverride?.toIso8601String(),
  };
}

/// Creates [DecorationState] from a JSON map.
DecorationState _decorationStateFromJson(Map<String, dynamic> json) {
  return DecorationState(
    layout: PhotoLayout.values.byName(json['layout'] as String),
    background: BackgroundChoice.values.byName(json['background'] as String),
    style: DecorativeStyle.values.byName(json['style'] as String),
    showDate: json['showDate'] as bool,
    stickers: (json['stickers'] as List)
        .map((e) => _stickerPlacementFromJson(e as Map<String, dynamic>))
        .toList(),
    texts: (json['texts'] as List)
        .map((e) => _textPlacementFromJson(e as Map<String, dynamic>))
        .toList(),
    filter: PhotoFilterType.values.byName(json['filter'] as String),
    filterIntensity: (json['filterIntensity'] as num).toDouble(),
    frameStyle: FrameStyle.values.byName(json['frameStyle'] as String),
    frameTheme: FrameTheme.values.byName(json['frameTheme'] as String),
    adjustments: _photoAdjustmentsFromJson(json['adjustments'] as Map<String, dynamic>),
    dateOverride: json['dateOverride'] != null
        ? DateTime.parse(json['dateOverride'] as String)
        : null,
  );
}

Map<String, dynamic> _stickerPlacementToJson(StickerPlacement s) {
  return {
    'type': s.type.name,
    'x': s.x,
    'y': s.y,
    'scale': s.scale,
    'rotation': s.rotation,
  };
}

StickerPlacement _stickerPlacementFromJson(Map<String, dynamic> json) {
  return StickerPlacement(
    type: StickerType.values.byName(json['type'] as String),
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    scale: (json['scale'] as num).toDouble(),
    rotation: (json['rotation'] as num).toDouble(),
  );
}

Map<String, dynamic> _textPlacementToJson(TextPlacement t) {
  return {
    'text': t.text,
    'x': t.x,
    'y': t.y,
    'color': t.color.toARGB32(),
    'scale': t.scale,
  };
}

TextPlacement _textPlacementFromJson(Map<String, dynamic> json) {
  return TextPlacement(
    text: json['text'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    color: Color(json['color'] as int),
    scale: (json['scale'] as num).toDouble(),
  );
}

Map<String, dynamic> _photoAdjustmentsToJson(PhotoAdjustments a) {
  return {
    'brightness': a.brightness,
    'contrast': a.contrast,
    'saturation': a.saturation,
    'warmth': a.warmth,
  };
}

PhotoAdjustments _photoAdjustmentsFromJson(Map<String, dynamic> json) {
  return PhotoAdjustments(
    brightness: (json['brightness'] as num).toDouble(),
    contrast: (json['contrast'] as num).toDouble(),
    saturation: (json['saturation'] as num).toDouble(),
    warmth: (json['warmth'] as num).toDouble(),
  );
}

// Need to import dart:convert for base64Encode/decode
// Added at top of file