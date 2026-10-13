import 'package:flutter/widgets.dart';

import 'album_service_contract.dart';

/// Creates the album for the current platform.
///
/// Overridden in widget tests so they can inject an in-memory album instead of
/// touching IndexedDB or the filesystem.
typedef AlbumServiceFactory = Future<AlbumService> Function();

AlbumServiceFactory _defaultFactory = _createPlatformAlbum;

/// Replaces the album factory. Passing null restores the platform default.
@visibleForTesting
void debugSetAlbumServiceFactory(AlbumServiceFactory? factory) {
  _defaultFactory = factory ?? _createPlatformAlbum;
}

Future<AlbumService> _createPlatformAlbum() async {
  final AppAlbumService service = AppAlbumService();
  await service.initialize();
  return service;
}

/// Makes a single [AlbumService] available to the whole widget tree.
///
/// One instance matters for correctness, not just tidiness: the album screen,
/// the export screen's "Save to Album" action and the settings screen must all
/// observe the same backend so a session saved on one screen is visible on the
/// others without a restart.
class AlbumScope extends InheritedWidget {
  const AlbumScope({
    super.key,
    required this.service,
    required super.child,
  });

  final AlbumService service;

  /// The album for this subtree.
  ///
  /// Throws rather than returning null when absent, so a missing provider is a
  /// loud programming error instead of a null-dereference at save time.
  static AlbumService of(BuildContext context) {
    final AlbumScope? scope =
        context.dependOnInheritedWidgetOfExactType<AlbumScope>();
    assert(scope != null, 'No AlbumScope found in the widget tree');
    return scope!.service;
  }

  @override
  bool updateShouldNotify(AlbumScope oldWidget) =>
      oldWidget.service != service;
}

/// The album for this subtree, or null when no [AlbumScope] is installed.
///
/// Used by screens that can work with or without persistence (the exporter, for
/// instance, still downloads a PNG when the album failed to open).
AlbumService? maybeAlbumOf(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<AlbumScope>()?.service;

/// Convenience for the common "give me the album" call in feature code.
AlbumService albumOf(BuildContext context) => AlbumScope.of(context);

/// Creates the platform album, initialising storage.
Future<AlbumService> defaultAlbumFactory() => _defaultFactory();