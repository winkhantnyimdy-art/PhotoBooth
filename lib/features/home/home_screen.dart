import 'package:flutter/material.dart';

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
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const _SettingsRoute()));
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
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        // Fill the viewport so the layout is balanced on tall
                        // phones, but stay scrollable when text scaling or a
                        // short screen makes the content taller than the page.
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const Spacer(flex: 3),
                              const Center(
                                child: MinimalWordmark(fontSize: 30),
                              ),
                              const SizedBox(height: S.sm),
                              Text(
                                'Capture, decorate, and save portrait strips.',
                                textAlign: TextAlign.center,
                                style: AppText.caption.copyWith(
                                  color: AppColors.darkMuted,
                                ),
                              ),
                              const Spacer(flex: 4),
                              MinimalPrimaryButton(
                                label: 'Start Photo Booth',
                                icon: Icons.camera_alt_rounded,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          CameraScreen(layout: _selected),
                                    ),
                                  );
                                },
                              ),
                              const Spacer(flex: 4),
                              _buildLayoutSection(),
                              const Spacer(flex: 3),
                              _buildFooterActions(),
                              const SizedBox(height: S.lg),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The layout chooser, presented as one surface so it reads as a single
  /// decision rather than four loose cards.
  Widget _buildLayoutSection() {
    return Container(
      padding: const EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: R.all(R.lg),
        border: Border.all(color: AppColors.darkLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
                  const SizedBox(width: S.sm),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions() {
    return Row(
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
          const Spacer(),
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
    return Semantics(
      button: true,
      selected: selected,
      label: layout.label,
      child: GestureDetector(
        onTap: onTap,
        child: PressableScale(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: S.sm, horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? AppColors.darkElevated : Colors.transparent,
              borderRadius: R.all(R.md),
              border: Border.all(
                color: selected ? AppColors.onDark : AppColors.darkLine,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(height: 46, child: _GridThumbnail(layout: layout)),
                const SizedBox(height: S.xs),
                Text(
                  layout.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    fontSize: 11.5,
                    color: selected ? AppColors.onDark : AppColors.darkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
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
            color: AppColors.darkBackground,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }
}
