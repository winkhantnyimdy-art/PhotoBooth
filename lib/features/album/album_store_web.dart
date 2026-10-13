import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:idb_shim/idb_shim.dart';
import 'package:web/web.dart' as web;

import 'album_record.dart';
import 'album_store.dart';

export 'album_store.dart';

/// IndexedDB-backed [AlbumStore] for the web/PWA build.
///
/// Binary photos are written into the `photos` object store as `Uint8List`,
/// which `idb_shim` hands to the browser as a `Uint8Array`. The browser stores
/// that through the structured-clone algorithm, so there is **no base64
/// round-trip** and no third-size inflation like the localStorage backend this
/// replaces.
///
/// Two object stores are used:
///
/// * `records` - small JSON rows keyed by session id;
/// * `photos`  - raw photo bytes keyed by `"<sessionId>/<index>"`.
///
/// Persistence is genuinely durable here: bytes come back out of IndexedDB
/// after a reload, which is why nothing in the album depends on a temporary
/// `blob:` URL surviving.
class IndexedDbAlbumStore implements AlbumStore {
  IndexedDbAlbumStore({this.databaseName = 'photobooth_album'});

  final String databaseName;

  static const String _recordsStore = 'records';
  static const String _photosStore = 'photos';

  /// Schema version of the IndexedDB layout.
  ///
  /// IndexedDB applies upgrades transactionally: bumping this runs
  /// [onUpgradeNeeded] on the next open, and existing rows survive unless the
  /// callback explicitly drops the store. That is the migration hook for any
  /// future record-schema change.
  static const int _idbVersion = 1;

  Database? _db;
  Completer<void>? _opening;

  /// True when the browser exposes a real IndexedDB (false in some private
  /// browsing modes, where we transparently fall back to memory).
  static bool get isIndexedDbAvailable {
    try {
      return idbFactoryWebSupported;
    } on Object {
      return false;
    }
  }

  @override
  String get backendName => isIndexedDbAvailable ? 'IndexedDB' : 'Memory (this tab only)';

  @override
  bool get supportsUsageReporting => true;

  @override
  Future<void> open() async {
    if (_db != null) return;
    if (_opening != null) return _opening!.future;

    final Completer<void> completer = Completer<void>();
    _opening = completer;
    try {
      final IdbFactory factory = _resolveFactory();
      final Database db = await factory.open(
        databaseName,
        version: _idbVersion,
        onUpgradeNeeded: (VersionChangeEvent event) {
          final Database database = event.database;
          if (!database.objectStoreNames.contains(_recordsStore)) {
            database.createObjectStore(_recordsStore, keyPath: 'id');
          }
          if (!database.objectStoreNames.contains(_photosStore)) {
            database.createObjectStore(_photosStore);
          }
        },
      );
      _db = db;
      completer.complete();
    } on Object catch (error) {
      _opening = null;
      completer.completeError(error);
      rethrow;
    }
  }

  /// Prefers real IndexedDB, falling back to an in-memory shim.
  ///
  /// The fallback is the Safari private-browsing / hardened-Safari case where
  /// opening a database can fail: the album then still works for the current
  /// launch and simply does not persist, rather than the app refusing to open.
  IdbFactory _resolveFactory() {
    try {
      if (idbFactoryWebSupported) return idbFactoryWeb;
    } on Object {
      // Fall through to memory.
    }
    return idbFactoryMemory;
  }

  Database get _requireDb {
    final Database? db = _db;
    if (db == null) {
      throw const AlbumStorageError(
        'Album database is not open',
        kind: AlbumErrorKind.unavailable,
      );
    }
    return db;
  }

  Transaction _txn(String store, String mode) =>
      _requireDb.transaction(store, mode);

  @override
  Future<List<AlbumRecord>> readAllRecords() async {
    await open();
    try {
      final List<Object> rows = await _txn(_recordsStore, idbModeReadOnly)
          .objectStore(_recordsStore)
          .getAll();
      final List<AlbumRecord> records = <AlbumRecord>[];
      for (final Object row in rows) {
        final AlbumRecord? record = AlbumRecord.decodeTolerant(row);
        if (record != null) records.add(record);
      }
      records.sort(
        (AlbumRecord a, AlbumRecord b) => b.createdAt.compareTo(a.createdAt),
      );
      return records;
    } on AlbumStorageError {
      rethrow;
    } on Object catch (error) {
      throw _wrap(error, 'Could not read the album');
    }
  }

  @override
  Future<AlbumRecord?> readRecord(String id) async {
    await open();
    try {
      final Object? row =
          await _txn(_recordsStore, idbModeReadOnly).objectStore(_recordsStore).getObject(id);
      return AlbumRecord.decodeTolerant(row);
    } on Object catch (error) {
      throw _wrap(error, 'Could not read that session');
    }
  }

  @override
  Future<void> writeRecord(AlbumRecord record) async {
    await open();
    try {
      await _txn(_recordsStore, idbModeReadWrite)
          .objectStore(_recordsStore)
          .put(record.toJson(), record.id);
    } on Object catch (error) {
      throw _wrap(error, 'Could not save this session');
    }
  }

  @override
  Future<void> deleteRecord(String id) async {
    await open();
    try {
      await _txn(_recordsStore, idbModeReadWrite)
          .objectStore(_recordsStore)
          .delete(id);
    } on Object catch (error) {
      throw _wrap(error, 'Could not delete this session');
    }
  }

  @override
  Future<void> clear() async {
    await open();
    try {
      await _txn(_photosStore, idbModeReadWrite).objectStore(_photosStore).clear();
      await _txn(_recordsStore, idbModeReadWrite).objectStore(_recordsStore).clear();
    } on Object catch (error) {
      throw _wrap(error, 'Could not clear the album');
    }
  }

  @override
  Future<Uint8List?> readPhoto(String key) async {
    await open();
    try {
      final Object? value =
          await _txn(_photosStore, idbModeReadOnly).objectStore(_photosStore).getObject(key);
      return _coerceBytes(value);
    } on Object catch (error) {
      throw _wrap(error, 'Could not read a stored photo');
    }
  }

  @override
  Future<void> writePhoto(String key, Uint8List bytes) async {
    await open();
    try {
      // Stored as real binary; idb_shim converts Uint8List to a Uint8Array,
      // which the browser structured-clones into a Blob.
      await _txn(_photosStore, idbModeReadWrite)
          .objectStore(_photosStore)
          .put(bytes, key);
    } on Object catch (error) {
      throw _wrap(error, 'Could not save a photo');
    }
  }

  @override
  Future<void> deletePhotos(Iterable<String> keys) async {
    if (keys.isEmpty) return;
    await open();
    try {
      final ObjectStore store =
          _txn(_photosStore, idbModeReadWrite).objectStore(_photosStore);
      for (final String key in keys) {
        await store.delete(key);
      }
    } on Object catch (error) {
      throw _wrap(error, 'Could not remove photos');
    }
  }

  @override
  Future<List<String>> listPhotoKeys() async {
    await open();
    try {
      // One getAllKeys call covers the whole album rather than a probe per
      // photo, so the grid can detect evicted blobs cheaply.
      final List<Object> keys = await _txn(_photosStore, idbModeReadOnly)
          .objectStore(_photosStore)
          .getAllKeys();
      return <String>[for (final Object key in keys) key.toString()];
    } on Object catch (error) {
      throw _wrap(error, 'Could not read stored photos');
    }
  }

  @override
  Future<int?> usageBytes() async {
    // `navigator.storage.estimate()` is the only honest measure of what the
    // origin actually occupies, and it is absent in Safari private browsing,
    // where this correctly returns null so the UI says "not available"
    // instead of inventing a number.
    try {
      final web.StorageEstimate estimate =
          await web.window.navigator.storage.estimate().toDart;
      return estimate.usage;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> close() async {
    _db?.close();
    _db = null;
    _opening = null;
  }

  /// Maps a raw stored value back to bytes.
  ///
  /// Browsers may hand back a `Uint8Array`, an `ArrayBuffer`, or - for a row
  /// written by an older build - a base64 string.
  static Uint8List? _coerceBytes(Object? value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is ByteBuffer) return value.asUint8List();
    if (value is String) {
      try {
        return base64Decode(value);
      } on FormatException {
        return null;
      }
    }
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is List<Object?>) {
      return Uint8List.fromList(<int>[
        for (final Object? v in value)
          if (v is int) v else if (v is num) v.toInt() else 0,
      ]);
    }
    return null;
  }

  /// Turns a driver exception into a user-presentable [AlbumStorageError].
  static AlbumStorageError _wrap(Object error, String context) {
    final String message = error.toString();
    final String lower = message.toLowerCase();
    if (lower.contains('quota') || lower.contains('exceeded')) {
      return AlbumStorageError(
        'This device is out of storage space.',
        kind: AlbumErrorKind.quotaExceeded,
      );
    }
    if (lower.contains('security') || lower.contains('denied')) {
      return AlbumStorageError(
        'The browser blocked access to local storage.',
        kind: AlbumErrorKind.unavailable,
      );
    }
    return AlbumStorageError('$context: $message', kind: AlbumErrorKind.unknown);
  }
}