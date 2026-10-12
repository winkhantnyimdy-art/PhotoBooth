/// Selects the correct `AlbumService` for the current platform.
///
/// Android/iOS/macOS/Windows/Linux get `AppAlbumService` (file-based storage);
/// browsers get the IndexedDB implementation.
///
/// The conditional export keeps `dart:io` and `path_provider` out of the
/// web bundle, so no native-only plugin is required in the browser.
library;

export 'album_service_io.dart'
    if (dart.library.js_interop) 'album_service_web.dart';