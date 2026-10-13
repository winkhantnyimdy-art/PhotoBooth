/// Selects the correct album persistence for the current platform.
///
/// Android/iOS/desktop store sessions as files under the app documents
/// directory; the web/PWA build stores them in IndexedDB with the real photo
/// bytes rather than a base64 string.
///
/// The conditional export keeps `dart:io`, `path_provider` and the native
/// store out of the browser bundle, so no native-only plugin is required in the
/// PWA and the two builds cannot accidentally diverge.
library;

import 'album_service_io.dart'
    if (dart.library.js_interop) 'album_service_web.dart';

export 'album_service_io.dart'
    if (dart.library.js_interop) 'album_service_web.dart';

/// Platform [AlbumPhotoFiles] builder.
///
/// On native this writes temporary files for [AlbumPhotoFiles.materialize];
/// in the browser it wraps the IndexedDB bytes in an in-memory `XFile` and
/// deliberately avoids temporary object URLs, which do not survive a reload.
AlbumPhotoFiles createPlatformAlbumPhotoFiles() => AppAlbumPhotoFiles();