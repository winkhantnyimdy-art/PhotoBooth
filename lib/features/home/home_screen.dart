import 'package:flutter/material.dart';

import '../../core/art/bubble_logo.dart';
import '../../core/art/checkerboard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pressable.dart';
import 'layout_model.dart';

import 'package:photo_booth/features/camera/camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PhotoLayout _selected = PhotoLayout.cut4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: S.sm),
                    const PhotoBoothBubbleLogo(width: 130),
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
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: AppColors.hotPink,
                            textStyle: AppText.button.copyWith(fontSize: 15),
                            shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
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
      ),
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
