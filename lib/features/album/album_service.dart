import 'album_session.dart';

/// Result of an album operation.
sealed class AlbumResult<T> {
  const AlbumResult();

  /// The operation succeeded.
  const factory AlbumResult.success(T value) = AlbumSuccess<T>;

  /// The operation failed with an error message.
  const factory AlbumResult.failure(String error) = AlbumFailure<T>;
}

class AlbumSuccess<T> extends AlbumResult<T> {
  const AlbumSuccess(this.value);
  final T value;
}

class AlbumFailure<T> extends AlbumResult<T> {
  const AlbumFailure(this.error);
  final String error;
}

/// Interface for platform-specific album storage operations.
///
/// Android/iOS use the local filesystem (app documents directory).
/// Web uses IndexedDB.
abstract class AlbumService {
  /// Initializes the storage backend. Must be called before any other method.
  Future<AlbumResult<void>> initialize();

  /// Returns all saved sessions, newest first.
  Future<AlbumResult<List<AlbumSession>>> listSessions();

  /// Saves a new session or updates an existing one.
  Future<AlbumResult<void>> saveSession(AlbumSession session);

  /// Deletes a session by ID.
  Future<AlbumResult<void>> deleteSession(String id);

  /// Deletes all sessions.
  Future<AlbumResult<void>> clearAll();

  /// Returns the approximate storage usage in bytes.
  Future<AlbumResult<int>> getStorageUsage();

  /// Closes any open resources.
  Future<void> close();
}