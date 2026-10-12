/// Platform-agnostic access to a captured photo.
///
/// Both the Android/iOS and the browser implementations expose exactly the
/// same surface:
///
/// - `readPhotoBytes` turns a captured `XFile` into raw bytes. The exporter and
///   the filter engine use it so a strip renders identically everywhere.
/// - `PhotoImage` paints a captured photo. On Android/iOS it streams the file
///   straight off disk; on the web it resolves the blob URL into bytes and
///   paints from memory, because `dart:io` and `File` do not exist there.
///
/// The conditional export keeps `dart:io` out of the web build entirely, so the
/// browser bundle never references a missing library.
library;

export 'photo_source_io.dart'
    if (dart.library.js_interop) 'photo_source_web.dart';