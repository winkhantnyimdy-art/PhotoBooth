import 'dart:convert';

import 'package:web/web.dart' as web;

import 'album_service.dart';
import 'album_session.dart';

export 'album_service.dart';

/// Browser implementation of [AlbumService] using localStorage.
///
/// Uses localStorage for simplicity. Note: localStorage has a ~5-10MB limit
/// per origin, so this is suitable for a moderate number of sessions.
/// For production use with many sessions, IndexedDB would be preferred.
class AppAlbumService implements AlbumService {
  AppAlbumService();

  static const String _storageKey = 'photo_booth_album_sessions';
  bool _initialized = false;

  @override
  Future<AlbumResult<void>> initialize() async {
    if (_initialized) return const AlbumResult.success(null);
    _initialized = true;
    return const AlbumResult.success(null);
  }

  @override
  Future<AlbumResult<List<AlbumSession>>> listSessions() async {
    final initResult = await _ensureInitialized();
    if (initResult case AlbumFailure(:final error)) {
      return AlbumResult.failure(error);
    }

    try {
      final web.Storage storage = web.window.localStorage;
      final String? jsonString = storage.getItem(_storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        return const AlbumResult.success(<AlbumSession>[]);
      }

      final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;
      final List<AlbumSession> sessions = [];
      for (final item in list) {
        try {
          sessions.add(AlbumSession.fromJson(item as Map<String, dynamic>));
        } catch (_) {
          // Skip corrupted entries
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
      final web.Storage storage = web.window.localStorage;
      final String? jsonString = storage.getItem(_storageKey);
      final List<dynamic> list = jsonString != null && jsonString.isNotEmpty
          ? jsonDecode(jsonString) as List<dynamic>
          : <dynamic>[];

      // Remove existing session with same ID if present
      list.removeWhere((item) => item is Map && item['id'] == session.id);

      // Add new session at the beginning (newest first)
      list.insert(0, session.toJson());

      // Save back to localStorage
      storage.setItem(_storageKey, jsonEncode(list));
      return const AlbumResult.success(null);
    } catch (e) {
      // Check if it's a quota exceeded error
      if (e.toString().contains('QuotaExceeded') || e.toString().contains('quota')) {
        return AlbumResult.failure('Storage quota exceeded. Please delete some sessions to make space.');
      }
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
      final web.Storage storage = web.window.localStorage;
      final String? jsonString = storage.getItem(_storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        return const AlbumResult.success(null);
      }

      final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;
      list.removeWhere((item) => item is Map && item['id'] == id);
      storage.setItem(_storageKey, jsonEncode(list));
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
      final web.Storage storage = web.window.localStorage;
      storage.removeItem(_storageKey);
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
      final web.Storage storage = web.window.localStorage;
      final String? jsonString = storage.getItem(_storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        return const AlbumResult.success(0);
      }
      // Approximate size in bytes (UTF-16 encoding in localStorage)
      return AlbumResult.success(jsonString.length * 2);
    } catch (e) {
      return AlbumResult.failure('Failed to calculate storage usage: $e');
    }
  }

  @override
  Future<void> close() async {
    // No resources to close for localStorage
    _initialized = false;
  }

  Future<AlbumResult<void>> _ensureInitialized() async {
    if (!_initialized) {
      return await initialize();
    }
    return const AlbumResult.success(null);
  }
}