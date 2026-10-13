import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

/// Reads the encoded bytes of a captured photo in the browser.
///
/// On the web an [XFile] wraps a `blob:` URL produced by `canvas.toBlob`, so
/// the bytes are re-hydrated from the blob through the XFile API. The result is
/// memoised in [_byteCache] because the review, decorate and export screens all
/// ask for the same photos.
Future<Uint8List> readPhotoBytes(XFile photo) async {
  final Uint8List? cached = _byteCache[photo.path];
  if (cached != null) return cached;
  final Uint8List bytes = await photo.readAsBytes();
  _cacheBytes(photo.path, bytes);
  return bytes;
}

/// Small FIFO cache so a 4-shot strip is decoded once, not once per screen.
///
/// These bytes live only in the tab's memory: nothing is written to disk, to
/// IndexedDB or to the service worker cache.
final Map<String, Uint8List> _byteCache = <String, Uint8List>{};

const int _maxCachedPhotos = 12;

void _cacheBytes(String key, Uint8List bytes) {
  if (_byteCache.length >= _maxCachedPhotos && !_byteCache.containsKey(key)) {
    _byteCache.remove(_byteCache.keys.first);
  }
  _byteCache[key] = bytes;
}

/// Returns [photo], flipped horizontally when [flipHorizontal] is true.
///
/// Flipping happens **here**, at capture time, rather than as a widget
/// transform, so that Review, Decorate, the album and the exported PNG all show
/// the same orientation. A preview-only transform would leave the saved bytes
/// in whatever orientation the platform happened to produce.
///
/// The decode/encode round-trip is done with `dart:ui`, which works unchanged
/// on every platform. When no flip is needed the original [photo] is returned
/// untouched, so the common path costs nothing and never re-encodes.
Future<XFile> flipPhotoIfNeeded(XFile photo, {required bool flipHorizontal}) async {
  if (!flipHorizontal) return photo;

  final Uint8List source = await readPhotoBytes(photo);
  final Uint8List? flipped = await flipHorizontally(source);
  // If the flip failed for any reason, the original photo is still usable; a
  // capture must never be lost to a cosmetic transform.
  if (flipped == null) return photo;

  return XFile.fromData(
    flipped,
    mimeType: _mimeTypeFor(photo.path),
    name: photo.name,
  );
}

/// Horizontally mirrors encoded image bytes.
///
/// Returns null when the bytes cannot be decoded, so callers can fall back to
/// the original image rather than losing the photo.
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

String _mimeTypeFor(String path) {
  final String lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Paints a captured photo in the browser.
///
/// `Image.file` cannot be used here — there is no `dart:io` on the web — so the
/// photo bytes are read from the blob URL and painted with [MemoryImage]. This
/// keeps the browser preview identical to the exported PNG, because both come
/// from the same decoded pixels.
class PhotoImage extends StatefulWidget {
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
  ///
  /// Pass a value from `PreviewDecode.forWidth` for interactive previews. The
  /// exporter does not use this widget at all - it reads the original bytes and
  /// decodes them at export resolution - so downscaling here cannot affect the
  /// quality of a saved PNG.
  final int? decodeWidth;

  @override
  State<PhotoImage> createState() => _PhotoImageState();
}

class _PhotoImageState extends State<PhotoImage> {
  Uint8List? _bytes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.path != widget.photo.path) {
      _bytes = null;
      _error = null;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final Uint8List bytes = await readPhotoBytes(widget.photo);
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = _bytes;
    if (bytes == null) {
      if (_error != null) {
        return SizedBox(width: widget.width, height: widget.height);
      }
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const _PhotoPlaceholder(),
      );
    }
    return Image(
      // ResizeImage keys its cache entry on the target size, so the small
      // preview never forces the full-resolution decode to exist at all.
      // Without it every preview surface held a full-size bitmap: about 48 MB
      // per 12 MP capture, and a four-shot strip meant four of them at once.
      image: widget.decodeWidth == null
          ? MemoryImage(bytes)
          : ResizeImage.resizeIfNeeded(
              widget.decodeWidth,
              null,
              MemoryImage(bytes),
            ),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      filterQuality: widget.filterQuality,
      gaplessPlayback: true,
    );
  }
}

/// Neutral loading block shown while the blob is decoded.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Color(0xFF2A262D)),
      child: SizedBox.expand(),
    );
  }
}