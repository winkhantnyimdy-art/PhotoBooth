import 'package:flutter/material.dart';

import '../../core/art/bubble_logo.dart';
import '../../core/art/collage_banner.dart';
import '../../core/art/checkerboard.dart';
import '../../core/art/scrapbook_doodles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pressable.dart';
import 'layout_model.dart';
import '../album/album_screen.dart';
import '../album/album_service_io.dart'
    if (dart.library.js_interop) '../album/album_service_web.dart';
import '../camera/camera_screen.dart';
import '../camera/preferences_service.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PhotoLayout _selected = kDefaultPhotoLayout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: ScrapbookDoodles()),
            Column(
              children: <Widget>[
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: S.sm),
                        const PhotoBoothBubbleLogo(width: 130),
                        const SizedBox(height: S.sm),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: S.lg),
                          child: CollageBanner(height: 124),
                        ),
                        const SizedBox(height: S.md),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: S.lg),
                          child: Text(
                            'Pick a layout, smash the shutter, make it yours.',
                            textAlign: TextAlign.center,
                            style: AppText.caption,
                          ),
                        ),
                        const SizedBox(height: S.sm),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: S.lg),
                          child: PressableScale(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => CameraScreen(layout: _selected),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.camera_alt_rounded, size: 20),
                              label: const Text('Start Photo Booth  →'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: AppColors.hotPink,
                                textStyle: AppText.button.copyWith(fontSize: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: R.pillRadius,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: S.md),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: S.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Choose Layout', style: AppText.label),
                              const SizedBox(height: S.xs),
                              Row(
                                children: <Widget>[
                                  for (final PhotoLayout layout in PhotoLayout.values) ...<Widget>[
                                    Expanded(
                                      child: _LayoutCard(
                                        layout: layout,
                                        selected: layout == _selected,
                                        onTap: () => setState(() => _selected = layout),
                                      ),
                                    ),
                                    if (layout != PhotoLayout.values.last)
                                      const SizedBox(width: S.xs),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: S.md),
                      ],
                    ),
                  ),
                ),
                const CheckerboardPattern(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
      child: Row(
        children: <Widget>[
          _CircleButton(
            icon: Icons.photo_library_rounded,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _AlbumRoute(),
                ),
              );
            },
            tooltip: 'Album',
          ),
          Expanded(
            child: Center(
              child: Text(
                'PhotoBooth',
                style: AppText.title.copyWith(color: AppColors.onDark),
              ),
            ),
          ),
          _CircleButton(
            icon: Icons.settings_rounded,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _SettingsRoute(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: enabled ? AppColors.surface : AppColors.background,
        shape: CircleBorder(side: BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 22,
              color: enabled ? AppColors.onDark : AppColors.darkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Route wrapper that initializes PreferencesService before showing SettingsScreen.
class _SettingsRoute extends StatelessWidget {
  const _SettingsRoute();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PreferencesService>(
      future: PreferencesService.create(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.hotPink),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Text('Failed to load settings: ${snapshot.error}'),
            ),
          );
        }
        return SettingsScreen(preferencesService: snapshot.data!);
      },
    );
  }
}

/// Route wrapper that initializes AlbumService before showing AlbumScreen.
class _AlbumRoute extends StatelessWidget {
  const _AlbumRoute();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppAlbumService>(
      future: _createAlbumService(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.hotPink),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Text('Failed to load album: ${snapshot.error}'),
            ),
          );
        }
        return AlbumScreen(albumService: snapshot.data!);
      },
    );
  }

  static Future<AppAlbumService> _createAlbumService() async {
    final service = AppAlbumService();
    await service.initialize();
    return service;
  }
}

class _LayoutCard extends StatelessWidget {
  const _LayoutCard({
    required this.layout,
    required this.selected,
    required this.onTap,
  });

  final PhotoLayout layout;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.popPink : AppColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 40,
              child: _GridThumbnail(layout: layout),
            ),
            const SizedBox(height: 2),
            Text(layout.label, style: AppText.overline.copyWith(fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _GridThumbnail extends StatelessWidget {
  const _GridThumbnail({required this.layout});

  final PhotoLayout layout;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: layout.cols,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: List<int>.generate(layout.photoCount, (int i) => i).map((_) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }
}
