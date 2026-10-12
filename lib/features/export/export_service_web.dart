import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'export_service_contract.dart';

export 'export_service_contract.dart';

/// Browser implementation of `ExportService`.
///
/// Honest about what a browser can do:
///
/// - **Save** triggers a real PNG download. On iOS Safari that file lands in
///   the Files app (or the Downloads folder) — *not* in the Apple Photos
///   library. There is no web API that writes to Photos, so the UI says
///   "Download PNG" instead of "Save to Photos".
/// - **Share** uses the Web Share API with the PNG attached, which is what lets
///   an iPhone user pick "Save Image" from the system share sheet and end up
///   with the photo in their library. When `navigator.canShare` reports no file
///   support, or the share is dismissed, the PNG is downloaded instead.
///
/// No bytes leave the device: nothing is uploaded and nothing is persisted.
class AppExportService implements ExportService {
  @override
  String get saveLabel => 'Download PNG';

  @override
  String get saveMessage => 'PNG downloaded';

  @override
  String? get saveHint =>
      'On iPhone the PNG saves to Files — tap Share and choose '
      '"Save Image" to keep it in Photos.';

  @override
  Future<void> saveToGallery(Uint8List bytes, String fileName) async {
    _download(bytes, fileName);
  }

  @override
  Future<void> shareImage(Uint8List bytes, String fileName) async {
    // Everything up to navigator.share is synchronous on purpose: iOS Safari
    // only grants the share sheet while the tap's user activation is still
    // live, so no await may sit between the button press and this call.
    final web.File file = _asWebFile(bytes, fileName);
    final web.ShareData data = web.ShareData(
      title: 'My PhotoBooth Strip!',
      files: <web.File>[file].toJS,
    );

    if (_canShare(data)) {
      try {
        await web.window.navigator.share(data).toDart;
        return;
      } catch (error) {
        // AbortError means the user closed the sheet — not a failure, but we
        // still leave them with the file via the download fallback.
        if (_isAbort(error)) return;
      }
    }

    _download(bytes, fileName);
  }

  bool _canShare(web.ShareData data) {
    try {
      return web.window.navigator.canShare(data);
    } catch (_) {
      // Older Safari throws NoSuchMethodError rather than returning false.
      return false;
    }
  }

  bool _isAbort(Object error) {
    // ignore: invalid_runtime_check_with_js_interop_types
    return error is web.DOMException && error.name == 'AbortError';
  }

  web.File _asWebFile(Uint8List bytes, String fileName) {
    return web.File(
      <JSUint8Array>[bytes.toJS].toJS,
      fileName,
      web.FilePropertyBag(type: _mimeTypeFor(fileName)),
    );
  }

  static String _mimeTypeFor(String fileName) {
    final String lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }

  /// Triggers a download through a transient `<a download>` element.
  ///
  /// A blob URL is used rather than a data URI: iOS Safari handles multi-
  /// megabyte PNGs over `blob:` but chokes on very long `data:` URLs.
  void _download(Uint8List bytes, String fileName) {
    final web.Blob blob = web.Blob(
      <JSUint8Array>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: _mimeTypeFor(fileName)),
    );
    final String url = web.URL.createObjectURL(blob);
    final web.HTMLAnchorElement anchor =
        web.document.createElement('a') as web.HTMLAnchorElement
          ..href = url
          ..download = fileName
          ..style.display = 'none';
    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();
    // Give Safari time to start the download before releasing the blob.
    Future<void>.delayed(
      const Duration(seconds: 30),
      () => web.URL.revokeObjectURL(url),
    );
  }
}