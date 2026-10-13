/// Selects the correct [AlbumStore] for the current platform.
///
/// Android/iOS/desktop get the filesystem store; the web/PWA build gets
/// IndexedDB. The conditional export keeps `dart:io` and `path_provider` out of
/// the browser bundle.
library;

export 'album_store_io.dart'
    if (dart.library.js_interop) 'album_store_web.dart';