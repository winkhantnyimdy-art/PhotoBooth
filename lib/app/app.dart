import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// System bars for the Minimal Dark theme.
  ///
  /// PhotoBooth is a near-black app, so Android's default status-bar icons
  /// (dark) were invisible against the `#101012` background. `statusBarIconBrightness: Brightness.light`
  /// forces white icons, and the navigation bar is made transparent so the
  /// gesture pill and the three-button bar read against the app's own dark
  /// surface rather than a light scrim.
  static const SystemUiOverlayStyle darkSystemBars = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  @override
  Widget build(BuildContext context) {
    if (albumService != null) {
      return AlbumScope(
        service: albumService!,
        child: _buildApp(const HomeScreen()),
      );
    }
    return _AlbumBootstrap(factory: albumFactory);
  }

  /// The single MaterialApp of the app.
  ///
  /// [AlbumScope] always sits *outside* this widget - never as `home:` - so
  /// that routes pushed on top of the navigator (album, settings, export)
  /// all reach the same album instance. Scoped inside `home`, the album
  /// would only be visible to the first route and every pushed screen would
  /// fail to resolve it.
  static Widget _buildApp(Widget home) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkSystemBars,
      // The Navigator paints every route inside this one AnnotatedRegion, so
      // pushed screens (Camera, Review, Decorate, Export) keep white system
      // icons for free instead of each declaring its own overlay style.
      child: MaterialApp(
        title: AppTheme.brand,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: home,
      ),
    );
  }
}

/// Creates the album before the first screen paints.
///
/// Storage can take a moment on the web (opening IndexedDB) and must never be
/// awaited inside a `build`, so the bootstrap shows a brief branded splash and
/// hands the finished service down through [AlbumScope].
class _AlbumBootstrap extends StatefulWidget {
  const _AlbumBootstrap({this.factory});

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
          return App._buildApp(const HomeScreen());
        }
        final AlbumService? service = snapshot.data;
        if (service == null) {
          return App._buildApp(const _AlbumSplash());
        }
        return AlbumScope(
          service: service,
          child: App._buildApp(const HomeScreen()),
        );
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
            color: AppColors.onDark,
          ),
        ),
      ),
    );
  }
}
