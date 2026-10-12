import 'dart:typed_data';

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
  });

  final XFile photo;
  final BoxFit fit;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;

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
    return Image.memory(
      bytes,
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