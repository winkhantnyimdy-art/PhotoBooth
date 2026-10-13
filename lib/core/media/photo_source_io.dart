import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Reads the encoded bytes of a captured photo straight off the local file.
///
/// Used by the strip renderer and the filter pipeline.
Future<Uint8List> readPhotoBytes(XFile photo) => File(photo.path).readAsBytes();

/// Returns [photo], flipped horizontally when [flipHorizontal] is true.
///
/// On native the flipped bytes are written to a temporary file so the existing
/// file-backed photo pipeline (review grid, decorate preview, renderer) keeps
/// working unchanged. When no flip is needed the original [photo] is returned
/// untouched, so the common path never re-encodes a photo.
Future<XFile> flipPhotoIfNeeded(
  XFile photo, {
  required bool flipHorizontal,
}) async {
  if (!flipHorizontal) return photo;

  try {
    final Uint8List source = await readPhotoBytes(photo);
    final Uint8List? flipped = await flipHorizontally(source);
    // A failed flip must never lose a capture: fall back to the original.
    if (flipped == null) return photo;

    final Directory dir = await getTemporaryDirectory();
    final Directory output = Directory('${dir.path}/photobooth_flipped');
    if (!await output.exists()) {
      await output.create(recursive: true);
    }
    final File file = File('${output.path}/${_nextFlippedName(photo.name)}');
    await file.writeAsBytes(flipped, flush: true);
    return XFile(file.path, mimeType: 'image/png');
  } on Object {
    // Unreadable source bytes, missing temp directory, or a failed encode:
    // keep the original capture rather than failing the whole session.
    return photo;
  }
}

/// Serial suffix making each flipped file unique.
///
/// `XFile.name` is empty for most native captures, so deriving the output name
/// from it alone would give every shot the same `flip.png` and the second
/// capture would silently overwrite the first - leaving the strip showing the
/// same photo four times.
int _flipCounter = 0;

String _nextFlippedName(String originalName) {
  final String base = _basename(originalName);
  return '${base.isEmpty ? 'flip' : base}_${_flipCounter++}.png';
}

/// Strips directories and the extension from a file name.
///
/// `XFile` builds `name` from the *path* when constructed with one, so the
/// value routinely contains separators. Keeping them would make the output path
/// point into a directory that does not exist.
String _basename(String name) {
  final int slash = name.lastIndexOf(RegExp(r'[/\\]'));
  final String file = slash < 0 ? name : name.substring(slash + 1);
  final int dot = file.lastIndexOf('.');
  if (dot <= 0) return file;
  return file.substring(0, dot);
}

/// Horizontally mirrors encoded image bytes.
///
/// Returns null when the bytes cannot be decoded.
Future<Uint8List?> flipHorizontally(Uint8List bytes) async {
  ui.ImmutableBuffer? buffer;
  ui.Codec? codec;
  ui.Image? source;
  ui.Image? target;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    codec = await ui.instantiateImageCodecFromBuffer(buffer);
    final ui.FrameInfo frame = await codec.getNextFrame();
    source = frame.image;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.translate(source.width.toDouble(), 0);
    canvas.scale(-1, 1);
    canvas.drawImage(source, Offset.zero, Paint());

    final ui.Picture picture = recorder.endRecording();
    target = await picture.toImage(source.width, source.height);
    picture.dispose();

    final ByteData? encoded =
        await target.toByteData(format: ui.ImageByteFormat.png);
    if (encoded == null) return null;
    return encoded.buffer.asUint8List();
  } on Object {
    return null;
  } finally {
    target?.dispose();
    source?.dispose();
    codec?.dispose();
  }
}



/// Paints a captured photo on Android/iOS.
///
/// Delegates to [Image.file] so the existing decode/cache behaviour is
/// unchanged for the native builds.
///
/// [decodeWidth] caps the decode. Left null (the default) the photo is decoded
/// at full resolution, which is what the exporter wants; pass a value from
/// [PreviewDecode] for interactive previews so a 12 MP frame does not become a
/// 48 MB bitmap just to fill a 340 px cell.
class PhotoImage extends StatelessWidget {
  const PhotoImage({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.decodeWidth,
  });

  final XFile photo;
  final BoxFit fit;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;

  /// Maximum width in pixels to decode this photo at, or null for full size.
  final int? decodeWidth;

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object> provider = decodeWidth == null
        ? FileImage(File(photo.path))
        // ResizeImage keys its cache entry on the target size, so the small
        // preview never forces the full-resolution decode to exist at all.
        // A null height keeps the source aspect ratio intact.
        : ResizeImage.resizeIfNeeded(
            decodeWidth,
            null,
            FileImage(File(photo.path)),
          );

    return Image(
      image: provider,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      filterQuality: filterQuality,
    );
  }
}