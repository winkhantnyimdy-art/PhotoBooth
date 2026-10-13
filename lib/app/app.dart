import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/album/album_scope.dart';
import '../features/album/album_service_contract.dart';
import '../features/home/home_screen.dart';

/// Root widget: wires the centralized theme to the top-level screen.
class App extends StatelessWidget {
  const App({super.key, this.albumService, this.albumFactory});

  /// Album to use. Supplied by tests; production builds create the platform
  /// album once and share it through [AlbumScope].
  final AlbumService? albumService;

  /// Overrides how the album is created. Used by tests to inject a fake.
  final AlbumServiceFactory? albumFactory;

  @override
  Widget build(BuildContext context) {
    const Widget home = HomeScreen();
    final Widget content = albumService != null
        ? AlbumScope(service: albumService!, child: home)
        : _AlbumBootstrap(factory: albumFactory, child: home);

    return MaterialApp(
      title: AppTheme.brand,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // AlbumScope deliberately sits *outside* MaterialApp so that routes
      // pushed on top of the navigator - the album, settings and export
      // screens - all reach the same album instance. Placed inside `home` it
      // would only be visible to the first route.
      home: content,
    );
  }
}

/// Creates the album before the first screen paints.
///
/// Storage can take a moment on the web (opening IndexedDB) and must never be
/// awaited inside a `build`, so the bootstrap shows a brief branded splash and
/// hands the finished service down through [AlbumScope].
class _AlbumBootstrap extends StatefulWidget {
  const _AlbumBootstrap({required this.child, this.factory});

  final Widget child;
  final AlbumServiceFactory? factory;

  @override
  State<_AlbumBootstrap> createState() => _AlbumBootstrapState();
}

class _AlbumBootstrapState extends State<_AlbumBootstrap> {
  late final Future<AlbumService> _future =
      (widget.factory ?? defaultAlbumFactory)();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AlbumService>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<AlbumService> snapshot) {
        if (snapshot.hasError) {
          // A missing album must not brick the app: the camera and exporter do
          // not depend on it, so the user can still take and download photos.
          return widget.child;
        }
        final AlbumService? service = snapshot.data;
        if (service == null) {
          return const _AlbumSplash();
        }
        return AlbumScope(service: service, child: widget.child);
      },
    );
  }
}

class _AlbumSplash extends StatelessWidget {
  const _AlbumSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      body: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.hotPink,
          ),
        ),
      ),
    );
  }
}