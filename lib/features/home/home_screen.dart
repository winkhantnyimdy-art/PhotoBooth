import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pressable.dart';
import '../../shared/retro_brand.dart';
import 'layout_model.dart';
import 'layout_preview.dart';

import 'package:photo_booth/features/camera/camera_screen.dart';

/// The Home screen: brand, layout selection and the start flow.
///
/// Concept C: pale yellow chrome, a coral decal wordmark, white layout cards
/// and one unmissable coral call to action.
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
      body: DecoratedBox(
        // Faint pink wash in the corner keeps the flat yellow from looking
        // like an empty page.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: <Color>[AppColors.accentSoft, AppColors.background],
            stops: <double>[0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxHeight < 620;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  S.lg,
                  S.md,
                  S.lg,
                  S.md,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (S.md * 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _Hero(),
                      SizedBox(height: compact ? S.md : S.lg),
                      Text(
                        'Pick your strip',
                        textAlign: TextAlign.center,
                        style: AppText.title,
                      ),
                      const SizedBox(height: S.xxs),
                      Text(
                        'We will take ${_selected.photoCount} photos in a row.',
                        textAlign: TextAlign.center,
                        style: AppText.body,
                      ),
                      SizedBox(height: compact ? S.md : S.lg),
                      _LayoutChoices(
                        selected: _selected,
                        onSelected: (PhotoLayout layout) {
                          setState(() => _selected = layout);
                        },
                      ),
                      SizedBox(height: compact ? S.lg : S.xl),
                      _StartButton(
                        layout: _selected,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CameraScreen(layout: _selected),
                            ),
                          );
                        },
                      ),
                      SizedBox(
                        height: S.md + MediaQuery.paddingOf(context).bottom,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Brand block: decal wordmark with playful sticker confetti.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhotoBoothWordmark(fontSize: 34),
            SizedBox(height: S.xs),
            Text(
              'Little moments, printed beautifully.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ],
        ),
        // Confetti pinned to the corners of the hero block.
        const Positioned(
          left: 0,
          top: 6,
          child: RetroSparkleDot(size: 20, color: AppColors.popBlue),
        ),
        const Positioned(
          right: 6,
          top: 0,
          child: RetroSparkleDot(size: 16, color: AppColors.popPink),
        ),
      ],
    );
  }
}

/// The layout choices, side by side so both stay visible without scrolling.
class _LayoutChoices extends StatelessWidget {
  const _LayoutChoices({required this.selected, required this.onSelected});

  final PhotoLayout selected;
  final ValueChanged<PhotoLayout> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final PhotoLayout layout in PhotoLayout.values) ...<Widget>[
          Expanded(
            child: LayoutPreview(
              layout: layout,
              selected: layout == selected,
              onTap: () => onSelected(layout),
            ),
          ),
          if (layout != PhotoLayout.values.last)
            const SizedBox(width: S.sm + S.xs),
        ],
      ],
    );
  }
}

/// Prominent primary call to action with a gentle press response.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.layout, required this.onPressed});

  final PhotoLayout layout;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: R.pillRadius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            textStyle: AppText.button.copyWith(fontSize: 17),
          ),
          icon: const Icon(Icons.auto_awesome_rounded, size: 22),
          label: const Text('Start Photo Booth'),
        ),
      ),
    );
  }
}
