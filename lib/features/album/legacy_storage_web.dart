import 'package:web/web.dart' as web;

import 'album_store.dart';
import 'legacy_migration.dart';

/// Reads and writes the superseded localStorage album payload.
///
/// Isolated in its own file so the migration logic in `legacy_migration.dart`
/// stays pure Dart and unit-testable on the VM: this is the only part that
/// touches browser globals.
class BrowserLegacyAlbumStorage {
  const BrowserLegacyAlbumStorage();

  web.Storage get _storage => web.window.localStorage;

  /// Raw legacy payload, or null when absent.
  ///
  /// Returns null rather than throwing when localStorage itself is
  /// unavailable (Safari private browsing historically threw on access).
  String? read() {
    try {
      final String? value = _storage.getItem(LegacyAlbumMigration.legacyStorageKey);
      return value;
    } on Object {
      return null;
    }
  }

  /// Copies the payload to a backup key before the original is cleared.
  void backup(String payload) {
    try {
      _storage.setItem(LegacyAlbumMigration.legacyBackupKey, payload);
    } on Object {
      // Best effort: a failed backup must not abort the migration, because the
      // original payload is still present at this point.
    }
  }

  void clear() {
    try {
      _storage.removeItem(LegacyAlbumMigration.legacyStorageKey);
    } on Object {
      // Ignore: leaving stale data only causes an idempotent re-run.
    }
  }

  /// A migration bound to this storage and [store].
  LegacyAlbumMigration migrationFor(AlbumStore store) => LegacyAlbumMigration(
        readLegacyPayload: () async => read(),
        backupLegacyPayload: (String payload) async => backup(payload),
        clearLegacyPayload: () async => clear(),
        store: store,
      );
}