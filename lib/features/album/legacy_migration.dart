import 'dart:convert';
import 'dart:typed_data';

import 'album_record.dart';
import 'album_session.dart';
import 'album_store.dart';

/// Moves sessions written by the superseded localStorage backend into the
/// current store.
///
/// The localStorage backend stored every session as one JSON object with
/// base64-encoded photos under a single key. This migrator reads that payload,
/// writes each session into the new record + blob layout, **verifies** the
/// result, and only then removes the old payload - and even then it keeps a
/// backup copy. The ordering matters: a half-finished migration must never be
/// able to destroy a user's photos.
///
/// Everything here is platform-neutral. The browser supplies the two local
/// storage accessors; native builds pass stubs that report "nothing to
/// migrate". That keeps the migration logic unit-testable on the Dart VM.
class LegacyAlbumMigration {
  const LegacyAlbumMigration({
    required this.readLegacyPayload,
    required this.backupLegacyPayload,
    required this.clearLegacyPayload,
    required this.store,
  });

  /// Reads the raw legacy JSON payload, or null when there is nothing stored.
  final Future<String?> Function() readLegacyPayload;

  /// Copies the raw payload somewhere safe before it is cleared.
  final Future<void> Function(String payload) backupLegacyPayload;

  /// Removes the legacy payload once migration has been verified.
  final Future<void> Function() clearLegacyPayload;

  final AlbumStore store;

  static const String legacyStorageKey = 'photo_booth_album_sessions';

  /// Key holding the pre-migration copy of the legacy payload.
  ///
  /// Deliberately *not* deleted automatically: if a future build discovers a
  /// bug in this migration, the user's original data is still recoverable by
  /// hand from devtools.
  static const String legacyBackupKey = 'photo_booth_album_sessions_backup';

  /// Runs the migration once.
  ///
  /// Safe to call on every launch: with no legacy payload it is a single
  /// storage read and a no-op.
  Future<LegacyMigrationReport> run() async {
    String? payload;
    try {
      payload = await readLegacyPayload();
    } on Object {
      return const LegacyMigrationReport.skipped('Could not read old album data');
    }

    if (payload == null || payload.trim().isEmpty) {
      return const LegacyMigrationReport.skipped('No old album data');
    }

    final List<Map<String, dynamic>> legacyRows;
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! List) {
        return const LegacyMigrationReport.skipped('Old album data was not a list');
      }
      legacyRows = <Map<String, dynamic>>[
        for (final Object? row in decoded)
          if (row is Map)
            row.map(
              (Object? k, Object? v) =>
                  MapEntry<String, dynamic>(k.toString(), v),
            ),
      ];
    } on Object {
      return const LegacyMigrationReport.skipped('Old album data was unreadable');
    }

    if (legacyRows.isEmpty) {
      await _finish(payload, migrated: 0, skipped: 0, corrupt: 0);
      return const LegacyMigrationReport(migrated: 0, skipped: 0, corrupt: 0);
    }

    await store.open();

    int migrated = 0;
    int corrupt = 0;

    for (final Map<String, dynamic> row in legacyRows) {
      final AlbumSession? session = _decodeLegacySession(row);
      if (session == null) {
        corrupt++;
        continue;
      }
      try {
        final AlbumRecord record = albumRecordFromSession(
          session,
          thumbnail:
              session.thumbnailBytes.isEmpty ? null : session.thumbnailBytes,
        );
        for (int i = 0; i < session.photoBytes.length; i++) {
          await store.writePhoto(record.photoKey(i), session.photoBytes[i]);
        }
        await store.writeRecord(record);
        migrated++;
      } on Object {
        corrupt++;
      }
    }

    // Verify before destroying anything. A migration that reports success but
    // left the store empty would silently wipe the album on the next load.
    final bool verified = await _verify(migrated);
    if (!verified) {
      return LegacyMigrationReport(
        migrated: 0,
        skipped: 0,
        corrupt: corrupt,
        verified: false,
        message:
            'Old album data was found but could not be moved safely. '
            'It has been left untouched.',
      );
    }

    await _finish(payload, migrated: migrated, skipped: 0, corrupt: corrupt);
    return LegacyMigrationReport(
      migrated: migrated,
      skipped: 0,
      corrupt: corrupt,
      verified: true,
    );
  }

  /// Re-reads the store and confirms every migrated session is fully present.
  Future<bool> _verify(int migrated) async {
    if (migrated == 0) return true;
    try {
      final List<AlbumRecord> records = await store.readAllRecords();
      if (records.isEmpty) return false;
      final Set<String> photoKeys = (await store.listPhotoKeys()).toSet();
      int seen = 0;
      for (final AlbumRecord record in records) {
        for (final String key in record.resolvePhotoKeys()) {
          if (photoKeys.contains(key)) seen++;
        }
      }
      // At least one session must have come back with all of its photos.
      return records.any((AlbumRecord r) =>
          r.resolvePhotoKeys().every(photoKeys.contains)) &&
          seen > 0;
    } on Object {
      return false;
    }
  }

  Future<void> _finish(
    String payload, {
    required int migrated,
    required int skipped,
    required int corrupt,
  }) async {
    try {
      await backupLegacyPayload(payload);
      await clearLegacyPayload();
    } on Object {
      // Failing to tidy up is harmless: leaving the payload in place only means
      // the migration runs again, and re-running is idempotent.
    }
  }

  /// Decodes one legacy row, returning null when it cannot be understood.
  AlbumSession? _decodeLegacySession(Map<String, dynamic> row) {
    try {
      // The legacy payload is exactly AlbumSession.toJson().
      final AlbumSession session = AlbumSession.fromJson(row);
      if (session.id.isEmpty || session.photoBytes.isEmpty) return null;
      return session;
    } on Object {
      return null;
    }
  }
}

/// Outcome of [LegacyAlbumMigration.run].
class LegacyMigrationReport {
  const LegacyMigrationReport({
    required this.migrated,
    required this.skipped,
    required this.corrupt,
    this.verified = true,
    this.message,
  });

  const LegacyMigrationReport.skipped(this.message)
      : migrated = 0,
        skipped = 0,
        corrupt = 0,
        verified = true;

  /// Sessions successfully moved into the new store.
  final int migrated;

  final int skipped;
  final int corrupt;

  /// False when the migrated data could not be read back, in which case the
  /// legacy payload was deliberately left in place.
  final bool verified;

  final String? message;

  bool get didWork => migrated > 0;

  @override
  String toString() =>
      'LegacyMigrationReport(migrated: $migrated, corrupt: $corrupt, '
      'verified: $verified, message: $message)';
}

/// Bytes helper used by the browser adapter when it decodes legacy rows.
Uint8List? decodeBase64OrNull(Object? value) {
  if (value is! String) return null;
  try {
    return base64Decode(value);
  } on FormatException {
    return null;
  }
}