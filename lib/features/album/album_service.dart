import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../home/layout_model.dart';
import 'album_record.dart';
import 'album_store.dart';
import 'album_session.dart';
import 'legacy_migration.dart';

/// Result of an album operation.
///
/// Sealed so callers must handle the failure case instead of silently
/// ignoring it - a swallowed storage error is how users lose photos.
sealed class AlbumResult<T> {
  const AlbumResult();

  /// The operation succeeded.
  const factory AlbumResult.success(T value) = AlbumSuccess<T>;

  /// The operation failed, carrying a message intended for the user.
  const factory AlbumResult.failure(
    String error, {
    AlbumErrorKind kind,
  }) = AlbumFailure<T>;
}

class AlbumSuccess<T> extends AlbumResult<T> {
  const AlbumSuccess(this.value);
  final T value;
}

class AlbumFailure<T> extends AlbumResult<T> {
  const AlbumFailure(this.error, {this.kind = AlbumErrorKind.unknown});
  final String error;
  final AlbumErrorKind kind;
}

/// Offline album of editable PhotoBooth sessions.
///
/// The album is the only thing in the app that persists user data, and it is
/// entirely local: no accounts, no cloud, no external database.
abstract class AlbumService {
  /// Human-readable backend name, e.g. "IndexedDB" or "Local files".
  String get backendName;

  /// True when [getStorageUsage] can return a real number.
  bool get supportsUsageReporting;

  /// Opens storage. Must be called before any other method.
  Future<AlbumResult<void>> initialize();

  /// Every saved session as a grid summary, newest first.
  ///
  /// Cheap by contract: summaries never carry original photo bytes, only the
  /// thumbnail, so the album grid does not decode full-resolution shots.
  Future<AlbumResult<List<AlbumSummary>>> listSessions();

  /// Loads one session in full, including the original photo bytes.
  ///
  /// Fails with [AlbumErrorKind.corrupt] when the stored photos are missing,
  /// so the caller can explain the problem instead of opening a blank editor.
  Future<AlbumResult<AlbumSession>> loadSession(String id);

  /// Saves a new session, or updates the existing one with the same id.
  ///
  /// Updating in place is what makes "edit a saved session and re-export"
  /// overwrite rather than duplicate.
  Future<AlbumResult<void>> saveSession(AlbumSession session);

  /// Deletes one session and its photos. Requires user confirmation in the UI.
  Future<AlbumResult<void>> deleteSession(String id);

  /// Deletes every session. Requires explicit user confirmation in the UI.
  Future<AlbumResult<void>> clearAll();

  /// Bytes used by the album, or null when the platform cannot measure it.
  Future<AlbumResult<int?>> getStorageUsage();

  Future<void> close();
}

/// Reads stored photo bytes back into [XFile]s the editor can render.
///
/// Implemented per platform because an [XFile] is path-backed on native and
/// blob-backed in the browser; both feed the same `readPhotoBytes` /
/// `PhotoImage` surface used by the capture pipeline, so a reopened session
/// renders through exactly the same code as a fresh capture.
abstract class AlbumPhotoFiles {
  /// Materialises [bytes] into an [XFile] usable by the editor and exporter.
  Future<XFile> materialize(Uint8List bytes, String fileName);

  /// Removes any temporary files created by [materialize].
  Future<void> dispose();
}

/// Concrete [AlbumService] built on an [AlbumStore].
///
/// All persistence logic lives here, once, rather than being duplicated per
/// platform. That also makes the whole album stack testable on the Dart VM by
/// injecting an in-memory store.
class StoreBackedAlbumService implements AlbumService {
  StoreBackedAlbumService(this.store, {this._migrations = const []});

  /// One-shot schema/data migrations run exactly once, after the store opens.
  ///
  /// The web build registers the localStorage-to-IndexedDB migration here so a
  /// user's existing album survives the backend change.
  final List<LegacyAlbumMigration> _migrations;
  final AlbumStore store;

  bool _initialized = false;
  bool _migrated = false;

  @override
  String get backendName => store.backendName;

  @override
  bool get supportsUsageReporting => store.supportsUsageReporting;

  @override
  Future<AlbumResult<void>> initialize() async {
    if (_initialized) return const AlbumResult.success(null);
    try {
      await store.open();
      _initialized = true;
      await _runMigrationsOnce();
      return const AlbumResult.success(null);
    } on AlbumStorageError catch (error) {
      return AlbumResult.failure(albumErrorMessage(error), kind: error.kind);
    } on Object catch (error) {
      return AlbumResult.failure('Could not open the album: $error');
    }
  }

  /// Runs pending migrations at most once per service instance.
  ///
  /// A failing migration is intentionally not surfaced as a hard failure: the
  /// migration itself keeps the legacy data intact, and refusing to open the
  /// album would be worse than opening it without the migrated rows.
  Future<void> _runMigrationsOnce() async {
    if (_migrated || _migrations.isEmpty) return;
    _migrated = true;
    for (final LegacyAlbumMigration migration in _migrations) {
      try {
        await migration.run();
      } on Object {
        // Ignored on purpose, see doc comment.
      }
    }
  }

  @override
  Future<AlbumResult<List<AlbumSummary>>> listSessions() async {
    final AlbumResult<void> ready = await initialize();
    if (ready is AlbumFailure) return AlbumResult.failure(ready.error, kind: ready.kind);

    try {
      final List<AlbumRecord> records = await store.readAllRecords();
      final Set<String> presentKeys = (await store.listPhotoKeys()).toSet();

      final List<AlbumSummary> summaries = <AlbumSummary>[];
      for (final AlbumRecord record in records) {
        int missing = 0;
        for (final String key in record.resolvePhotoKeys()) {
          if (!presentKeys.contains(key)) missing++;
        }
        summaries.add(record.toSummary(missingPhotos: missing));
      }
      summaries.sort(
        (AlbumSummary a, AlbumSummary b) => b.createdAt.compareTo(a.createdAt),
      );
      return AlbumResult.success(summaries);
    } on AlbumStorageError catch (error) {
      return AlbumResult.failure(albumErrorMessage(error), kind: error.kind);
    } on Object catch (error) {
      return AlbumResult.failure('Could not read the album: $error');
    }
  }

  @override
  Future<AlbumResult<AlbumSession>> loadSession(String id) async {
    final AlbumResult<void> ready = await initialize();
    if (ready is AlbumFailure) return AlbumResult.failure(ready.error, kind: ready.kind);

    try {
      final AlbumRecord? record = await store.readRecord(id);
      if (record == null) {
        return const AlbumResult.failure(
          'That session is no longer in your album.',
          kind: AlbumErrorKind.corrupt,
        );
      }

      final List<Uint8List> photos = <Uint8List>[];
      final List<int> missing = <int>[];
      final List<String> keys = record.resolvePhotoKeys();
      for (int i = 0; i < keys.length; i++) {
        final Uint8List? bytes = await store.readPhoto(keys[i]);
        if (bytes == null || bytes.isEmpty) {
          missing.add(i);
        } else {
          photos.add(bytes);
        }
      }

      if (missing.isNotEmpty) {
        return AlbumResult.failure(
          missing.length == keys.length
              // Web storage can be evicted by the browser; on native the
              // album lives in app-private files, so a different cause.
              ? kIsWeb
                  ? 'The photos for this session could not be found. The browser may '
                      'have cleared this site\'s data.'
                  : 'The photos for this session could not be found. The app\'s '
                      'stored data may have been cleared.'
              : '${missing.length} of ${keys.length} photos for this session '
                  'could not be found.',
          kind: AlbumErrorKind.corrupt,
        );
      }

      return AlbumResult.success(
        AlbumSession(
          id: record.id,
          createdAt: record.createdAt,
          layout: _layoutByName(record.layoutName),
          photoBytes: photos,
          decorationState: decorationStateFromJson(record.decoration),
          thumbnailBytes: record.thumbnail ?? Uint8List(0),
          name: record.name,
           thumbnailIsStrip: record.thumbnailIsStrip,
        ),
      );
    } on AlbumStorageError catch (error) {
      return AlbumResult.failure(albumErrorMessage(error), kind: error.kind);
    } on Object catch (error) {
      return AlbumResult.failure(
        'That session could not be opened: $error',
        kind: AlbumErrorKind.corrupt,
      );
    }
  }

  @override
  Future<AlbumResult<void>> saveSession(AlbumSession session) async {
    final AlbumResult<void> ready = await initialize();
    if (ready is AlbumFailure) return AlbumResult.failure(ready.error, kind: ready.kind);

    if (session.photoBytes.isEmpty) {
      return const AlbumResult.failure(
        'Cannot save a session with no photos.',
        kind: AlbumErrorKind.corrupt,
      );
    }

    final AlbumRecord record = albumRecordFromSession(
      session,
      thumbnail: session.thumbnailBytes.isEmpty ? null : session.thumbnailBytes,
      thumbnailIsStrip: session.thumbnailIsStrip,
    );

    try {
      // Photos first: a record whose photos are missing is a broken session,
      // whereas orphaned photos are merely wasted space and are cleaned up by
      // the next overwrite of the same id.
      for (int i = 0; i < session.photoBytes.length; i++) {
        await store.writePhoto(record.photoKey(i), session.photoBytes[i]);
      }
      await store.writeRecord(record);
      return const AlbumResult.success(null);
    } on AlbumStorageError catch (error) {
      return AlbumResult.failure(albumErrorMessage(error), kind: error.kind);
    } on Object catch (error) {
      return AlbumResult.failure('Could not save this session: $error');
    }
  }

  @override
  Future<AlbumResult<void>> deleteSession(String id) async {
    final AlbumResult<void> ready = await initialize();
    if (ready is AlbumFailure) return AlbumResult.failure(ready.error, kind: ready.kind);

    try {
      final AlbumRecord? record = await store.readRecord(id);
      await store.deletePhotos(record?.resolvePhotoKeys() ?? const <String>[]);
      await store.deleteRecord(id);
      return const AlbumResult.success(null);
    } on AlbumStorageError catch (error) {
      return AlbumResult.failure(albumErrorMessage(error), kind: error.kind);
    } on Object catch (error) {
      return AlbumResult.failure('Could not delete this session: $error');
    }
  }

  @override
  Future<AlbumResult<void>> clearAll() async {
    final AlbumResult<void> ready = await initialize();
    if (ready is AlbumFailure) return AlbumResult.failure(ready.error, kind: ready.kind);

    try {
      await store.clear();
      return const AlbumResult.success(null);
    } on AlbumStorageError catch (error) {
      return AlbumResult.failure(albumErrorMessage(error), kind: error.kind);
    } on Object catch (error) {
      return AlbumResult.failure('Could not clear the album: $error');
    }
  }

  @override
  Future<AlbumResult<int?>> getStorageUsage() async {
    final AlbumResult<void> ready = await initialize();
    if (ready is AlbumFailure) return AlbumResult.failure(ready.error, kind: ready.kind);

    try {
      return AlbumResult.success(await store.usageBytes());
    } on Object {
      // Usage is advisory: an unmeasurable backend is not an error.
      return const AlbumResult.success(null);
    }
  }

  @override
  Future<void> close() => store.close();

  /// Resolves a stored layout name, falling back to the default when the name
  /// no longer exists (a layout removed in a later release must not make an
  /// otherwise-valid session unopenable).
  static PhotoLayout _layoutByName(String name) {
    for (final PhotoLayout layout in PhotoLayout.values) {
      if (layout.name == name) return layout;
    }
    return kDefaultPhotoLayout;
  }
}