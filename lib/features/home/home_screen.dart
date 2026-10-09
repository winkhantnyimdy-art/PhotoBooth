import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pressable.dart';
import 'layout_model.dart';
import 'layout_preview.dart';

import 'package:photo_booth/features/camera/camera_screen.dart';

/// The Home screen: brand, layout selection and the start flow.
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
        // Soft radial wash behind the brand keeps the cream canvas from
        // reading as flat white.
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.9),
            radius: 1.15,
            colors: <Color>[AppColors.surfaceTint, AppColors.background],
            stops: <double>[0.0, 0.62],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxHeight < 640;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(S.lg, S.md, S.lg, S.md),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (S.md * 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _BrandHeader(),
                      SizedBox(height: compact ? S.md : S.lg),
                      Text(
                        'Pick your strip',
                        style: AppText.title,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: S.xs),
                      Text(
                        'We will take ${_selected.photoCount} photos in a row.',
                        style: AppText.body,
                        textAlign: TextAlign.center,
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

/// Brand mark and wordmark.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const _BrandMark(),
        const SizedBox(height: S.md),
        Text(
          AppTheme.brand,
          textAlign: TextAlign.center,
          style: AppText.display.copyWith(letterSpacing: -1),
        ),
        const SizedBox(height: S.xs),
        Text(
          'Little moments, printed beautifully.',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
      ],
    );
  }
}

/// Rounded brand tile with a soft pink glow.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: R.all(R.xl),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.42),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.photo_camera_rounded,
        size: 38,
        color: AppColors.onAccent,
      ),
    );
  }
}

/// The two layout choices, side by side so both stay visible without
/// scrolling on short screens.
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
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: const Text('Start Photo Booth'),
      ),
    );
  }
}
