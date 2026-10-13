import 'dart:typed_data';

import 'album_record.dart';

/// A storage failure with enough structure for the UI to explain it.
///
/// The album never surfaces a raw exception string: it maps this to a title
/// and a recovery hint.
class AlbumStorageError implements Exception {
  const AlbumStorageError(this.message, {this.kind = AlbumErrorKind.unknown});

  final String message;
  final AlbumErrorKind kind;

  @override
  String toString() => 'AlbumStorageError($kind): $message';
}

/// Why an album operation failed.
enum AlbumErrorKind {
  /// Device or browser refused access to storage entirely.
  unavailable,

  /// The origin has run out of room (browser quota, or a full disk).
  quotaExceeded,

  /// A write was interrupted or the stored row is not readable.
  corrupt,

  /// Read failed for a reason we cannot classify.
  unknown,
}

/// User-facing copy for a storage failure.
///
/// Centralised so the album never shows a raw driver string such as
/// `QuotaExceededError` and every failure is explained in the same voice.
String albumErrorMessage(AlbumStorageError error) {
  switch (error.kind) {
    case AlbumErrorKind.quotaExceeded:
      return 'This device is out of storage space. Delete a saved session '
          'from the album and try again.';
    case AlbumErrorKind.unavailable:
      return 'This device will not let the app use local storage. '
          'Sessions cannot be saved right now.';
    case AlbumErrorKind.corrupt:
      return error.message;
    case AlbumErrorKind.unknown:
      return error.message;
  }
}

/// Low-level, platform-neutral key/value storage for the album.
///
/// Split from [AlbumService] for two reasons:
///
///  * the service layer deals in domain objects ([AlbumSession]) while this
///    layer deals in rows and blobs, which is what IndexedDB and the
///    filesystem actually store;
///  * it makes the whole persistence stack testable on the Dart VM by swapping
///    in [InMemoryAlbumStore], with no browser or plugin involved.
///
/// Implementations must never delete data as a side effect of a failed write.
abstract class AlbumStore {
  /// Human-readable backend name, shown in Settings ("IndexedDB", "Files").
  String get backendName;

  /// Whether usage can be measured by the backend.
  ///
  /// Safari's private mode refuses `navigator.storage.estimate()`, so the
  /// album reports usage as unavailable instead of showing a fake number.
  bool get supportsUsageReporting;

  /// Opens the backend. Safe to call repeatedly.
  Future<void> open();

  /// Every stored record, newest first.
  ///
  /// Rows that cannot be decoded are skipped rather than thrown, so one bad
  /// row cannot hide the rest of the album.
  Future<List<AlbumRecord>> readAllRecords();

  Future<AlbumRecord?> readRecord(String id);

  /// Inserts or replaces [record].
  Future<void> writeRecord(AlbumRecord record);

  /// Removes a record. Never throws when the record is simply absent.
  Future<void> deleteRecord(String id);

  /// Removes every record and photo.
  Future<void> clear();

  Future<Uint8List?> readPhoto(String key);

  Future<void> writePhoto(String key, Uint8List bytes);

  Future<void> deletePhotos(Iterable<String> keys);

  /// Keys of every stored photo blob.
  ///
  /// Read once per album listing so the grid can tell a healthy session from
  /// one whose photos were evicted, without one round-trip per photo.
  Future<List<String>> listPhotoKeys();

  /// Total bytes held by records plus photos, or null when not measurable.
  Future<int?> usageBytes();

  Future<void> close();
}

/// Non-persistent [AlbumStore] used by tests and as a last-resort fallback
/// when IndexedDB is unavailable (notably Safari private browsing, where
/// opening a database can throw).
///
/// Rows are held as **JSON maps, not as [AlbumRecord] objects**, mirroring the
/// real stores. That keeps the tolerant-decode path - which is where a corrupt
/// or outdated row is caught - under test; an in-memory store that short-
/// circuited it would let broken data through unnoticed.
class InMemoryAlbumStore implements AlbumStore {
  InMemoryAlbumStore();

  final Map<String, Map<String, dynamic>> _records = <String, Map<String, dynamic>>{};
  final Map<String, Uint8List> _photos = <String, Uint8List>{};

  @override
  String get backendName => 'Memory';

  @override
  bool get supportsUsageReporting => true;

  @override
  Future<void> open() async {}

  @override
  Future<List<AlbumRecord>> readAllRecords() async {
    final List<AlbumRecord> all = <AlbumRecord>[
      for (final Map<String, dynamic> row in _records.values)
        if (AlbumRecord.decodeTolerant(row) case final AlbumRecord record) record,
    ]..sort((AlbumRecord a, AlbumRecord b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Future<AlbumRecord?> readRecord(String id) async {
    final Map<String, dynamic>? row = _records[id];
    return row == null ? null : AlbumRecord.decodeTolerant(row);
  }

  @override
  Future<void> writeRecord(AlbumRecord record) async {
    _records[record.id] = record.toJson();
  }

  @override
  Future<void> deleteRecord(String id) async {
    _records.remove(id);
  }

  @override
  Future<void> clear() async {
    _records.clear();
    _photos.clear();
  }

  @override
  Future<Uint8List?> readPhoto(String key) async => _photos[key];

  @override
  Future<void> writePhoto(String key, Uint8List bytes) async {
    _photos[key] = bytes;
  }

  @override
  Future<void> deletePhotos(Iterable<String> keys) async {
    for (final String key in keys) {
      _photos.remove(key);
    }
  }

  @override
  Future<List<String>> listPhotoKeys() async => _photos.keys.toList()..sort();

  @override
  Future<int?> usageBytes() async {
    int total = 0;
    for (final Map<String, dynamic> row in _records.values) {
      final Object? thumb = row['thumbnail'];
      if (thumb is String) total += thumb.length;
    }
    for (final Uint8List b in _photos.values) {
      total += b.length;
    }
    return total;
  }

  @override
  Future<void> close() async {}

  /// Number of stored records, for assertions.
  int get recordCount => _records.length;

  /// Number of stored photo blobs, for assertions.
  int get photoCount => _photos.length;

  /// Photo keys currently held, for assertions.
  Iterable<String> get photoKeys => _photos.keys;
}