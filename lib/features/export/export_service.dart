/// Selects the correct `ExportService` for the current platform.
///
/// Android/iOS get `AppExportService` (`gal` + native share sheet); browsers
/// get the Web Share API with a PNG download fallback.
///
/// The conditional export keeps `gal`, `path_provider` and `dart:io` out of the
/// web bundle, so no Android-only plugin is required in the browser.
library;

export 'export_service_io.dart'
    if (dart.library.js_interop) 'export_service_web.dart';