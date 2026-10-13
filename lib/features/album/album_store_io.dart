import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'album_record.dart';
import 'album_store.dart';

export 'album_store.dart';

/// Filesystem-backed [AlbumStore] for Android/iOS and desktop.
///
/// Layout under the app documents directory:
///
/// ```
/// photo_booth_album/
///   records/<sessionId>.json     metadata row
///   photos/<sessionId>/<n>.jpg   original photo bytes, untouched
/// ```
///
/// Photos are written to their own files rather than being embedded as base64
/// inside the JSON row: it keeps the original JPEG bytes bit-for-bit (so
/// re-export quality is identical to the capture), and it means listing the
/// album only parses small metadata files.
class FileAlbumStore implements AlbumStore {
  FileAlbumStore({Directory? rootDirectory})
      : _rootOverride = rootDirectory;

  final Directory? _rootOverride;
  Directory? _root;
  bool _opened = false;

  static const String _recordsDir = 'records';
  static const String _photosDir = 'photos';
  static const String _photoExtension = '.jpg';

  @override
  String get backendName => 'Local files';

  @override
  bool get supportsUsageReporting => true;

  @override
  Future<void> open() async {
    if (_opened) return;
    final Directory root = _rootOverride ??
        Directory('${(await getApplicationDocumentsDirectory()).path}'
            '/photo_booth_album');
    _root = root;
    await Directory('${root.path}/$_recordsDir').create(recursive: true);
    await Directory('${root.path}/$_photosDir').create(recursive: true);
    _opened = true;
  }

  Directory get _requireRoot {
    final Directory? root = _root;
    if (root == null) {
      throw const AlbumStorageError(
        'Album storage is not open',
        kind: AlbumErrorKind.unavailable,
      );
    }
    return root;
  }

  File _recordFile(String id) =>
      File('${_requireRoot.path}/$_recordsDir/$id.json');

  /// A photo key is `"<sessionId>/<index>"`.
  File _photoFile(String key) =>
      File('${_requireRoot.path}/$_photosDir/$key$_photoExtension');

  @override
  Future<List<AlbumRecord>> readAllRecords() async {
    await open();
    try {
      final Directory records = Directory('${_requireRoot.path}/$_recordsDir');
      final List<AlbumRecord> out = <AlbumRecord>[];
      await for (final FileSystemEntity entity in records.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final Map<String, dynamic> json =
              jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
          final AlbumRecord? record = AlbumRecord.decodeTolerant(json);
          if (record != null) out.add(record);
        } on Object {
          // A truncated or corrupt row must not hide the rest of the album.
          continue;
        }
      }
      out.sort((AlbumRecord a, AlbumRecord b) => b.createdAt.compareTo(a.createdAt));
      return out;
    } on AlbumStorageError {
      rethrow;
    } on Object catch (error) {
      throw _wrap(error, 'Could not read the album');
    }
  }

  @override
  Future<AlbumRecord?> readRecord(String id) async {
    await open();
    final File file = _recordFile(id);
    if (!await file.exists()) return null;
    try {
      final Map<String, dynamic> json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return AlbumRecord.decodeTolerant(json);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writeRecord(AlbumRecord record) async {
    await open();
    try {
      // Write via a temp file then rename so an interrupted write cannot leave
      // a half-written row that would read as corrupt on next launch.
      final File target = _recordFile(record.id);
      final File temp = File('${target.path}.tmp');
      await temp.writeAsString(jsonEncode(record.toJson()), flush: true);
      if (await target.exists()) {
        await target.delete();
      }
      await temp.rename(target.path);
    } on Object catch (error) {
      throw _wrap(error, 'Could not save this session');
    }
  }

  @override
  Future<void> deleteRecord(String id) async {
    await open();
    try {
      final File file = _recordFile(id);
      if (await file.exists()) await file.delete();
      final Directory photos = Directory('${_requireRoot.path}/$_photosDir/$id');
      if (await photos.exists()) await photos.delete(recursive: true);
    } on Object catch (error) {
      throw _wrap(error, 'Could not delete this session');
    }
  }

  @override
  Future<void> clear() async {
    await open();
    try {
      for (final String name in <String>[_recordsDir, _photosDir]) {
        final Directory dir = Directory('${_requireRoot.path}/$name');
        if (await dir.exists()) {
          await for (final FileSystemEntity entity in dir.list()) {
            await entity.delete(recursive: true);
          }
        }
      }
    } on Object catch (error) {
      throw _wrap(error, 'Could not clear the album');
    }
  }

  @override
  Future<Uint8List?> readPhoto(String key) async {
    await open();
    final File file = _photoFile(key);
    if (!await file.exists()) return null;
    try {
      return await file.readAsBytes();
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writePhoto(String key, Uint8List bytes) async {
    await open();
    try {
      final File file = _photoFile(key);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } on Object catch (error) {
      throw _wrap(error, 'Could not save a photo');
    }
  }

  @override
  Future<void> deletePhotos(Iterable<String> keys) async {
    await open();
    for (final String key in keys) {
      final File file = _photoFile(key);
      if (await file.exists()) {
        try {
          await file.delete();
        } on Object {
          // Best effort: an orphaned blob is preferable to a failed delete.
        }
      }
    }
  }

  @override
  Future<List<String>> listPhotoKeys() async {
    await open();
    final Directory photos = Directory('${_requireRoot.path}/$_photosDir');
    if (!await photos.exists()) return const <String>[];
    final List<String> keys = <String>[];
    await for (final FileSystemEntity entity
        in photos.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith(_photoExtension)) continue;
      final String relative = entity.path
          .substring('${photos.path}${Platform.pathSeparator}'.length);
      keys.add(relative.substring(0, relative.length - _photoExtension.length));
    }
    return keys;
  }

  @override
  Future<int?> usageBytes() async {
    await open();
    try {
      int total = 0;
      await for (final FileSystemEntity entity
          in _requireRoot.list(recursive: true)) {
        if (entity is File) {
          total += await entity.stat().then((FileStat s) => s.size);
        }
      }
      return total;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> close() async {
    _opened = false;
    _root = null;
  }

  static AlbumStorageError _wrap(Object error, String context) {
    final String lower = error.toString().toLowerCase();
    if (lower.contains('no space') ||
        lower.contains('disk full') ||
        lower.contains('quota')) {
      return AlbumStorageError(
        'This device is out of storage space.',
        kind: AlbumErrorKind.quotaExceeded,
      );
    }
    return AlbumStorageError('$context: $error', kind: AlbumErrorKind.unknown);
  }
}