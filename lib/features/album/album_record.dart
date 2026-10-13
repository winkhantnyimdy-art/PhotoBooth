import 'dart:convert';
import 'dart:typed_data';

import '../home/layout_model.dart';
import 'album_session.dart';

/// Schema version of the persisted album record.
///
/// Bump this when [AlbumRecord]'s JSON shape changes. [AlbumService] keeps
/// records of unknown versions readable through
/// [AlbumRecord.decodeTolerant], so an old build never destroys data written
/// by a newer one.
const int kAlbumRecordSchemaVersion = 1;

/// The on-disk / in-IndexedDB shape of a saved session.
///
/// A session is deliberately split in two: the **record** carries only the
/// small metadata (dates, layout, decoration state, thumbnail and a list of
/// photo keys) while the **photo blobs** live separately under those keys.
///
/// The reason is memory: the album grid only needs a thumbnail, so listing
/// sessions must not pull ~1-4 MB of JPEG per shot into memory. Keeping the
/// blobs out of the record also means the record stays cheap to parse and, on
/// the web, lets IndexedDB store real binary instead of a base64 string that
/// inflates by a third.
class AlbumRecord {
  const AlbumRecord({
    required this.id,
    required this.createdAt,
    required this.layoutName,
    required this.decoration,
    required this.photoKeys,
    this.thumbnail,
    this.name,
    this.schemaVersion = kAlbumRecordSchemaVersion,
  });

  final String id;
  final DateTime createdAt;

  /// [PhotoLayout.name] of the captured layout.
  final String layoutName;

  /// Serialised [DecorationState].
  final Map<String, dynamic> decoration;

  /// Keys of the photo blobs for this session, in capture order.
  final List<String> photoKeys;

  /// Album-grid thumbnail. May be null if it could not be generated.
  final Uint8List? thumbnail;

  final String? name;
  final int schemaVersion;

  /// Photo key for [index] within this session.
  String photoKey(int index) => '$id/$index';

  /// Canonical photo keys for this session, in capture order.
  ///
  /// Keys are positional (`"<id>/<index>"`) rather than stored verbatim, so a
  /// session cannot end up pointing at another session's blobs and a reordered
  /// or hand-edited key list cannot desynchronise photos from their record.
  List<String> resolvePhotoKeys() => <String>[
        for (int i = 0; i < photoKeys.length; i++) photoKey(i),
      ];

  /// Number of photos this session is expected to have.
  int get photoCount => photoKeys.length;

  AlbumRecord copyWith({
    String? id,
    DateTime? createdAt,
    String? layoutName,
    Map<String, dynamic>? decoration,
    List<String>? photoKeys,
    Uint8List? thumbnail,
    String? name,
    int? schemaVersion,
  }) {
    return AlbumRecord(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      layoutName: layoutName ?? this.layoutName,
      decoration: decoration ?? this.decoration,
      photoKeys: photoKeys ?? this.photoKeys,
      thumbnail: thumbnail ?? this.thumbnail,
      name: name ?? this.name,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema': schemaVersion,
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'layout': layoutName,
        'decoration': decoration,
        'photoKeys': photoKeys,
        // Only the thumbnail is base64'd: it is a single small image kept in
        // the record so the album grid renders without touching photo blobs.
        'thumbnail': thumbnail == null ? null : base64Encode(thumbnail!),
        'name': name,
      };

  /// Strict decode used when writing.
  factory AlbumRecord.fromJson(Map<String, dynamic> json) => AlbumRecord(
        schemaVersion: (json['schema'] as num?)?.toInt() ?? 0,
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        layoutName: json['layout'] as String,
        decoration: Map<String, dynamic>.from(
          json['decoration'] as Map<dynamic, dynamic>,
        ),
        photoKeys: <String>[
          for (final Object? k in (json['photoKeys'] as List? ?? const <Object?>[]))
            k! as String,
        ],
        thumbnail: json['thumbnail'] == null
            ? null
            : base64Decode(json['thumbnail'] as String),
        name: json['name'] as String?,
      );

  /// Tolerant decode used when reading rows that may predate a schema change.
  ///
  /// Returns null when the row cannot be understood, so the caller can skip
  /// that row instead of failing the whole album. A row is "understandable"
  /// only when it carries the identity, timestamp and decoration fields the
  /// editor needs - a row with a truncated or empty decoration map would
  /// otherwise decode "successfully" here and blow up much later, when the user
  /// opens it.
  static AlbumRecord? decodeTolerant(Object? raw) {
    if (raw is! Map) return null;
    final Map<String, dynamic> json = raw.map(
      (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
    );
    final Object? id = json['id'];
    if (id is! String || id.isEmpty) return null;
    try {
      final Object? createdAt = json['createdAt'];
      final Object? decoration = json['decoration'];
      if (createdAt is! String || decoration is! Map) return null;
      if (!_hasRequiredDecorationFields(decoration)) return null;
      return AlbumRecord.fromJson(<String, dynamic>{
        ...json,
        'schema': (json['schema'] as num?)?.toInt() ?? 0,
        'createdAt': createdAt,
        'decoration': decoration,
      });
    } on Object {
      return null;
    }
  }

  /// Whether a stored decoration map contains the fields [DecorationState]
  /// requires to be reconstructed.
  static bool _hasRequiredDecorationFields(Map<Object?, Object?> decoration) {
    for (final String field in const <String>['layout', 'background', 'style']) {
      if (decoration[field] is! String) return false;
    }
    return true;
  }

  /// Lightweight grid entry derived from a record, without any photo bytes.
  AlbumSummary toSummary({required int missingPhotos}) => AlbumSummary(
        id: id,
        createdAt: createdAt,
        layoutName: layoutName,
        photoCount: photoKeys.length,
        thumbnail: thumbnail,
        name: name,
        missingPhotos: missingPhotos,
      );
}

/// A session as shown in the album grid: metadata and a thumbnail, no photos.
class AlbumSummary {
  const AlbumSummary({
    required this.id,
    required this.createdAt,
    required this.layoutName,
    required this.photoCount,
    this.thumbnail,
    this.name,
    this.missingPhotos = 0,
  });

  final String id;
  final DateTime createdAt;
  final String layoutName;
  final int photoCount;
  final Uint8List? thumbnail;
  final String? name;

  /// Number of photo blobs that could not be read for this session.
  ///
  /// A non-zero value means the metadata survived but some or all original
  /// photos are gone (cleared site data, an evicted blob, a partial write).
  /// The album surfaces this instead of offering a reopen that would fail.
  final int missingPhotos;

  bool get isDamaged => missingPhotos > 0;

  String get displayName => name ?? 'Session ${AlbumSession.formatDate(createdAt)}';
}

/// Short label for a stored layout name.
///
/// Unknown names (a layout removed in a later release) are shown verbatim
/// rather than hidden, so a strange album entry is diagnosable.
String albumLayoutLabel(String layoutName) {
  for (final PhotoLayout layout in PhotoLayout.values) {
    if (layout.name == layoutName) return layout.label;
  }
  return layoutName;
}

/// Builds an [AlbumRecord] from a full in-memory [AlbumSession].
///
/// The session's photo bytes are **not** stored in the record; the caller is
/// responsible for writing them under [AlbumRecord.resolvePhotoKeys].
AlbumRecord albumRecordFromSession(
  AlbumSession session, {
  Uint8List? thumbnail,
}) {
  return AlbumRecord(
    id: session.id,
    createdAt: session.createdAt,
    layoutName: session.layout.name,
    decoration: decorationStateToJson(session.decorationState),
    photoKeys: <String>[
      for (int i = 0; i < session.photoBytes.length; i++)
        '${session.id}/$i',
    ],
    thumbnail: thumbnail,
    name: session.name,
  );
}