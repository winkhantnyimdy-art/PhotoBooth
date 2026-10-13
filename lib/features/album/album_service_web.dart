import 'dart:typed_data';

import 'package:camera/camera.dart';

import 'album_service.dart';
import 'album_store_web.dart';
import 'legacy_migration.dart';
// Imported directly rather than through the conditional `legacy_storage.dart`:
// this file only ever compiles for the web, and the VM-side analyzer resolves
// conditional exports to the native variant.
import 'legacy_storage_web.dart';

export 'album_service.dart';

/// IndexedDB [AlbumService] for the web/PWA build.
///
/// Wraps [IndexedDbAlbumStore]; all behaviour is inherited from
/// [StoreBackedAlbumService].
///
/// The constructor wires in the localStorage -> IndexedDB migration so any
/// session saved by the previous backend is carried over on first launch.
class AppAlbumService extends StoreBackedAlbumService {
  AppAlbumService._(super.store, {required super.migrations});

  factory AppAlbumService() {
    // One store instance is shared by the service and the migration; building
    // two would let the migration write into a different database handle.
    final IndexedDbAlbumStore store = IndexedDbAlbumStore();
    return AppAlbumService._(
      store,
      migrations: <LegacyAlbumMigration>[
        BrowserLegacyAlbumStorage().migrationFor(store),
      ],
    );
  }
}

/// Materialises stored album bytes into in-memory [XFile]s.
///
/// The browser has no filesystem, and critically the app must never depend on
/// a temporary `blob:` URL created during a previous launch surviving: such
/// URLs are revoked when the tab closes and are meaningless after a reload.
/// Bytes therefore always come straight out of IndexedDB and are wrapped with
/// [XFile.fromData], which the web photo source re-hydrates through
/// `readPhotoBytes` - the same path a freshly captured photo takes.
class AppAlbumPhotoFiles implements AlbumPhotoFiles {
  @override
  Future<XFile> materialize(Uint8List bytes, String fileName) async {
    return XFile.fromData(
      bytes,
      mimeType: mimeTypeForAlbumFile(fileName),
      name: fileName,
    );
  }

  @override
  Future<void> dispose() async {
    // Nothing to release: the bytes are owned by IndexedDB and by the XFile.
  }
}

/// MIME type for an album photo file name.
String mimeTypeForAlbumFile(String fileName) {
  final String lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}