import 'dart:typed_data';
import 'dart:ui' as ui;

/// Formats a byte count for the storage footer, e.g. `4.2 MB`.
///
/// Deliberately uses decimal units because browsers report `navigator.storage`
/// figures in the same decimal ballpark; mixing in binary units would make the
/// number look wrong next to the browser's own storage settings.
String formatAlbumBytes(int bytes) {
  if (bytes < 1000) return '$bytes B';
  if (bytes < 1000 * 1000) {
    return '${(bytes / 1000).toStringAsFixed(bytes < 10000 ? 1 : 0)} KB';
  }
  if (bytes < 1000 * 1000 * 1000) {
    return '${(bytes / (1000 * 1000)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1000 * 1000 * 1000)).toStringAsFixed(2)} GB';
}

/// Longest edge of an album-grid thumbnail, in pixels.
///
/// Deliberately small: the inspector re-renders the strip from the originals
/// when the user wants to see it large, so the grid does not carry (and every
/// record does not store) multi-hundred-KB previews for a ~180 dp tile.
const int kAlbumThumbnailSize = 240;

/// Renders a small preview of [photoBytes] for the album grid.
///
/// Returns null when the bytes cannot be decoded, so the caller can fall back
/// to a neutral tile rather than crashing the album over one bad photo.
///
/// This never modifies the stored bytes: it decodes a separate, downscaled copy,
/// which is why saving a session keeps the original photos at full resolution.
Future<Uint8List?> generateAlbumThumbnail(Uint8List photoBytes) async {
  if (photoBytes.isEmpty) return null;

  ui.ImmutableBuffer? buffer;
  ui.Codec? codec;
  ui.Image? source;
  ui.Image? scaled;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(photoBytes);
    codec = await ui.instantiateImageCodecFromBuffer(
      buffer,
      // Cap the decode so a 12 MP camera frame does not become a 48 MB bitmap
      // just to produce a 240 px tile.
      targetWidth: kAlbumThumbnailSize,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    source = frame.image;

    // A local, non-nullable alias: `source` is declared nullable so it can be
    // disposed in the finally block.
    final ui.Image decoded = source;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final double side = decoded.width > decoded.height
        ? decoded.width.toDouble()
        : decoded.height.toDouble();
    final double scale = side <= 0 ? 1 : kAlbumThumbnailSize / side;
    final ui.Rect dst = ui.Rect.fromLTWH(
      0,
      0,
      decoded.width * scale,
      decoded.height * scale,
    );
    canvas.drawImageRect(
      decoded,
      ui.Rect.fromLTWH(0, 0, decoded.width.toDouble(), decoded.height.toDouble()),
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );

    final ui.Picture picture = recorder.endRecording();
    scaled = await picture.toImage(
      dst.width.ceil().clamp(1, 4096),
      dst.height.ceil().clamp(1, 4096),
    );
    picture.dispose();

    final ByteData? encoded =
        await scaled.toByteData(format: ui.ImageByteFormat.png);
    if (encoded == null) return null;
    return encoded.buffer.asUint8List();
  } on Object {
    return null;
  } finally {
    // ui.Image holds native memory; releasing it here keeps repeated saves from
    // growing the heap without bound.
    scaled?.dispose();
    source?.dispose();
    codec?.dispose();
  }
}