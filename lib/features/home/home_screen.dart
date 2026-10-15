import 'package:flutter/material.dart';

import '../../core/art/bubble_logo.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/minimal_dark.dart';
import '../../shared/pressable.dart';
import '../album/album_scope.dart';
import '../album/album_service_contract.dart';
import '../album/album_screen.dart';
import '../camera/camera_screen.dart';
import '../camera/preferences_service.dart';
import '../settings/settings_screen.dart';
import 'layout_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PhotoLayout _selected = kDefaultPhotoLayout;

  void _openAlbum() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AlbumScreen(
          albumService: albumOf(context),
          photoFiles: createPlatformAlbumPhotoFiles(),
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _SettingsRoute()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.lg),
          child: Column(
            children: <Widget>[
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(height: S.lg),
                      const PhotoBoothBubbleLogo(width: 118),
                      const SizedBox(height: S.sm),
                      Text(
                        'PhotoBooth',
                        style: AppText.display.copyWith(color: AppColors.onDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Capture, decorate, and save portrait strips.',
                        textAlign: TextAlign.center,
                        style: AppText.caption
                            .copyWith(color: AppColors.darkMuted),
                      ),
                      const SizedBox(height: S.xl),
                      MinimalPrimaryButton(
                        label: 'Start Photo Booth',
                        icon: Icons.camera_alt_rounded,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CameraScreen(layout: _selected),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: S.xl),
                      const MinimalSectionHeading(
                        title: 'Choose layout',
                        subtitle: 'Tap a card to set the capture grid.',
                      ),
                      const SizedBox(height: S.md),
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
                      const SizedBox(height: S.xl),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: MinimalSecondaryButton(
                              label: 'Album',
                              icon: Icons.photo_library_rounded,
                              onPressed: _openAlbum,
                            ),
                          ),
                          const SizedBox(width: S.sm),
                          Expanded(
                            child: MinimalSecondaryButton(
                              label: 'Settings',
                              icon: Icons.settings_rounded,
                              onPressed: _openSettings,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: S.lg),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: S.sm),
      child: Row(
        children: <Widget>[
          MinimalIconButton(
            icon: Icons.photo_library_rounded,
            onPressed: _openAlbum,
            tooltip: 'Album',
          ),
          const Expanded(
            child: Center(
              child: Icon(
                Icons.local_see_rounded,
                color: AppColors.darkMuted,
                size: 20,
              ),
            ),
          ),
          MinimalIconButton(
            icon: Icons.settings_rounded,
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
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
            backgroundColor: AppColors.darkBackground,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.onDark),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            backgroundColor: AppColors.darkBackground,
            body: Center(
              child: Text(
                'Could not load settings',
                style: AppText.body.copyWith(color: AppColors.onDark),
              ),
            ),
          );
        }
        return SettingsScreen(preferencesService: snapshot.data!);
      },
    );
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
      child: PressableScale(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(S.xs),
          decoration: BoxDecoration(
            color: AppColors.darkElevated,
            borderRadius: R.all(R.md),
            border: Border.all(
              color: selected ? AppColors.onDark : AppColors.darkLine,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 42,
                child: _GridThumbnail(layout: layout),
              ),
              const SizedBox(height: S.xs),
              Text(
                layout.label,
                style: AppText.caption.copyWith(
                  color: selected ? AppColors.onDark : AppColors.darkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }).toList(),
    );
  }
}