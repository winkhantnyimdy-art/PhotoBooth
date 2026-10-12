import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'album_service.dart';
import 'album_session.dart';

export 'album_service.dart';

/// Production implementation of [AlbumService] for Android/iOS/macOS/Windows/Linux.
///
/// Stores sessions as individual JSON files in the app's documents directory.
/// Each session is a separate file to allow incremental loading and avoid
/// loading all data into memory at once.
class AppAlbumService implements AlbumService {
  AppAlbumService();

  Directory? _sessionsDir;
  bool _initialized = false;

  @override
  Future<AlbumResult<void>> initialize() async {
    if (_initialized) return const AlbumResult.success(null);

    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      _sessionsDir = Directory('${appDir.path}/photo_booth_sessions');
      if (!await _sessionsDir!.exists()) {
        await _sessionsDir!.create(recursive: true);
      }
      _initialized = true;
      return const AlbumResult.success(null);
    } catch (e) {
      return AlbumResult.failure('Failed to initialize album storage: $e');
    }
  }

  @override
  Future<AlbumResult<List<AlbumSession>>> listSessions() async {
    final initResult = await _ensureInitialized();
    if (initResult case AlbumFailure(:final error)) {
      return AlbumResult.failure(error);
    }

    try {
      final List<FileSystemEntity> entities =
          await _sessionsDir!.list().toList();
      final List<AlbumSession> sessions = [];

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final String content = await entity.readAsString();
            final Map<String, dynamic> json = jsonDecode(content);
            sessions.add(AlbumSession.fromJson(json));
          } catch (e) {
            // Skip corrupted files but log the error
            // In production, you might want to report this
            continue;
          }
        }
      }

      // Sort newest first
      sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return AlbumResult.success(sessions);
    } catch (e) {
      return AlbumResult.failure('Failed to list sessions: $e');
    }
  }

  @override
  Future<AlbumResult<void>> saveSession(AlbumSession session) async {
    final initResult = await _ensureInitialized();
    if (initResult case AlbumFailure(:final error)) {
      return AlbumResult.failure(error);
    }

    try {
      final File file = File('${_sessionsDir!.path}/${session.id}.json');
      final String content = jsonEncode(session.toJson());
      await file.writeAsString(content);
      return const AlbumResult.success(null);
    } catch (e) {
      return AlbumResult.failure('Failed to save session: $e');
    }
  }

  @override
  Future<AlbumResult<void>> deleteSession(String id) async {
    final initResult = await _ensureInitialized();
    if (initResult case AlbumFailure(:final error)) {
      return AlbumResult.failure(error);
    }

    try {
      final File file = File('${_sessionsDir!.path}/$id.json');
      if (await file.exists()) {
        await file.delete();
      }
      return const AlbumResult.success(null);
    } catch (e) {
      return AlbumResult.failure('Failed to delete session: $e');
    }
  }

  @override
  Future<AlbumResult<void>> clearAll() async {
    final initResult = await _ensureInitialized();
    if (initResult case AlbumFailure(:final error)) {
      return AlbumResult.failure(error);
    }

    try {
      final List<FileSystemEntity> entities =
          await _sessionsDir!.list().toList();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.json')) {
          await entity.delete();
        }
      }
      return const AlbumResult.success(null);
    } catch (e) {
      return AlbumResult.failure('Failed to clear sessions: $e');
    }
  }

  @override
  Future<AlbumResult<int>> getStorageUsage() async {
    final initResult = await _ensureInitialized();
    if (initResult case AlbumFailure(:final error)) {
      return AlbumResult.failure(error);
    }

    try {
      int totalBytes = 0;
      final List<FileSystemEntity> entities =
          await _sessionsDir!.list().toList();
      for (final entity in entities) {
        if (entity is File) {
          final stat = await entity.stat();
          totalBytes += stat.size;
        }
      }
      return AlbumResult.success(totalBytes);
    } catch (e) {
      return AlbumResult.failure('Failed to calculate storage usage: $e');
    }
  }

  @override
  Future<void> close() async {
    // No persistent resources to close for file-based storage
    _initialized = false;
    _sessionsDir = null;
  }

  Future<AlbumResult<void>> _ensureInitialized() async {
    if (!_initialized) {
      return await initialize();
    }
    return const AlbumResult.success(null);
  }
}