import 'album_store.dart';
import 'legacy_migration.dart';

/// A no-op [LegacyAlbumMigration] for builds that never had localStorage album
/// data.
///
/// The native album has always used files, so there is nothing to migrate and
/// this keeps the startup path identical across platforms without dragging
/// `dart:io` or browser globals into shared code.
LegacyAlbumMigration noLegacyMigration(AlbumStore store) => LegacyAlbumMigration(
      readLegacyPayload: () async => null,
      backupLegacyPayload: (String payload) async {},
      clearLegacyPayload: () async {},
      store: store,
    );

/// The migration appropriate for this platform.
LegacyAlbumMigration legacyMigrationForPlatform(AlbumStore store) =>
    noLegacyMigration(store);