/// Selects the legacy-storage adapter for the current platform.
///
/// Only the web/PWA build ever had localStorage album data, so the browser
/// adapter is chosen exclusively there; native builds get a no-op migration.
library;

export 'legacy_storage_native.dart'
    if (dart.library.js_interop) 'legacy_storage_web.dart';