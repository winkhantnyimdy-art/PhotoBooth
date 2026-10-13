import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../../core/media/photo_source.dart';
import '../decorate/decoration_model.dart';
import '../home/layout_model.dart';
import 'album_session.dart';
import 'album_thumbnail.dart';

/// Builds an [AlbumSession] from a finished composition, ready to persist.
///
/// Photo bytes are read through the platform photo source, so the bytes stored
/// are the *originals* - the strip renderer never resamples or re-encodes the
/// captured files. That is what lets a reopened session be re-exported at the
/// same quality as the first export.
///
/// [existingId] makes this an update: saving over an existing album entry
/// replaces it in place rather than creating a duplicate.
Future<AlbumSession> buildAlbumSession({
  required PhotoLayout layout,
  required List<XFile> photos,
  required DecorationState decorationState,
  String? existingId,
  String? name,
}) async {
  final List<Uint8List> bytes = <Uint8List>[];
  for (final XFile photo in photos) {
    bytes.add(await readPhotoBytes(photo));
  }

  // The thumbnail is generated from the first shot; the grid only needs one
  // representative frame and generating per-shot tiles would multiply the cost
  // of every save for no visible benefit.
  final Uint8List? thumbnail =
      bytes.isEmpty ? null : await generateAlbumThumbnail(bytes.first);

  return AlbumSession(
    id: existingId ?? newAlbumSessionId(),
    createdAt: DateTime.now(),
    layout: layout,
    photoBytes: bytes,
    decorationState: decorationState,
    thumbnailBytes: thumbnail ?? Uint8List(0),
    name: name,
  );
}

/// Unique id for a new session.
///
/// Time-ordered so a lexicographic listing is also chronological, and suffixed
/// with a monotonic counter rather than a random number: two sessions saved in
/// the same millisecond must not collide, and that has to hold on every
/// platform, including ones without a strong PRNG.
String newAlbumSessionId() {
  final DateTime now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final String stamp = '${now.year.toString().padLeft(4, '0')}'
      '${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}'
      '${two(now.second)}';
  _sequence += 1;
  return 'session-$stamp-${_sequence.toRadixString(36)}';
}

/// Monotonic per-process counter guaranteeing same-second uniqueness.
int _sequence = 0;