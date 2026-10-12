import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/art/bubble_logo.dart';
import '../../core/art/checkerboard.dart';
import '../../core/art/frame_decorations.dart';
import '../../core/art/retro_sticker.dart';
import '../../core/media/photo_source.dart';
import '../../core/theme/app_colors.dart';
import '../decorate/decoration_model.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pressable.dart';
import '../camera/camera_screen.dart';
import '../decorate/decorate_screen.dart';
import '../home/layout_geometry.dart';
import '../home/layout_model.dart';

/// The shot review: a dark stage showing the captured frames as a grid.
///
/// The screen owns the photo list so an individual retake can swap a single
/// frame in place. Every other shot - and any decoration applied later - is
/// untouched by a retake.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.layout,
    required this.photos,
    this.aspectRatio,
    this.retakeCameraBuilder,
  });

  final PhotoLayout layout;
  final List<XFile> photos;
  final double? aspectRatio;

  /// Builds the camera used for a single-photo retake.
  ///
  /// Defaults to a plain [CameraScreen]. Exposed as a seam so a test - or a host
  /// that already owns a configured camera - can supply one without the review
  /// screen having to know about camera plumbing.
  final Widget Function(BuildContext context, int index)? retakeCameraBuilder;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late List<XFile> _photos;
  int _selected = 0;
  bool _retaking = false;

  @override
  void initState() {
    super.initState();
    _photos = List<XFile>.of(widget.photos);
    if (_photos.isNotEmpty) _selected = _photos.length - 1;
  }

  PhotoLayout get _layout => widget.layout;

  void _select(int index) {
    if (index < 0 || index >= _photos.length) return;
    setState(() => _selected = index);
  }

  /// Replaces just the selected frame, keeping every other photo.
  Future<void> _retakeSelected() async {
    if (_retaking || _selected >= _photos.length) return;
    setState(() => _retaking = true);

    final XFile? replacement = await Navigator.of(context).push<XFile>(
      MaterialPageRoute<XFile>(
        builder: (BuildContext context) {
          final builder = widget.retakeCameraBuilder;
          return builder != null
              ? builder(context, _selected)
              : CameraScreen(layout: _layout, retakeIndex: _selected);
        },
      ),
    );

    if (!mounted) return;
    setState(() {
      _retaking = false;
      if (replacement != null && _selected < _photos.length) {
        _photos[_selected] = replacement;
      }
    });
  }

  void _next() {
    final NavigatorState navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => DecorateScreen(
          layout: _layout,
          photos: List<XFile>.unmodifiable(_photos),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: S.lg),
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: S.md),
                    _StripPreview(
                      layout: _layout,
                      photos: _photos,
                      selected: _selected,
                      onSelect: _select,
                    ),
                    const SizedBox(height: S.lg),
                    _ThumbnailRow(
                      photos: _photos,
                      selectedIndex: _selected,
                      onSelect: _select,
                    ),
                    const SizedBox(height: S.md),
                    _SelectionCaption(
                      layout: _layout,
                      selected: _selected,
                      total: _photos.length,
                    ),
                    const SizedBox(height: S.lg),
                  ],
                ),
              ),
            ),
            _buildActions(context),
            const CheckerboardPattern(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
      child: Row(
        children: <Widget>[
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Review',
                style: AppText.title.copyWith(color: AppColors.onDark),
              ),
            ),
          ),
          _CircleButton(
            icon: Icons.delete_outline_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        S.lg,
        S.md,
        S.lg,
        S.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(color: AppColors.darkSurface),
      child: Row(
        children: <Widget>[
          Expanded(
            child: PressableScale(
              enabled: !_retaking,
              child: OutlinedButton.icon(
                onPressed: _retaking ? null : _retakeSelected,
                icon: _retaking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onDark,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Retake'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColors.onDark,
                  disabledForegroundColor: AppColors.darkMuted,
                  side: const BorderSide(color: AppColors.darkLine, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
                ),
              ),
            ),
          ),
          const SizedBox(width: S.md),
          Expanded(
            child: PressableScale(
              child: FilledButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: const Text('Next'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.hotPink,
                  shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Tap a photo to select it · Retake replaces just that one".
class _SelectionCaption extends StatelessWidget {
  const _SelectionCaption({
    required this.layout,
    required this.selected,
    required this.total,
  });

  final PhotoLayout layout;
  final int selected;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        total == 0
            ? 'No photos yet'
            : 'Photo ${selected + 1} of $total selected  ·  '
                  'Retake replaces only this one',
        textAlign: TextAlign.center,
        style: AppText.caption.copyWith(color: AppColors.darkMuted),
      ),
    );
  }
}

class _StripPreview extends StatelessWidget {
  const _StripPreview({
    required this.layout,
    required this.photos,
    required this.selected,
    required this.onSelect,
  });

  final PhotoLayout layout;
  final List<XFile> photos;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: -8,
          top: -8,
          child: RetroSticker(type: StickerType.cherry, size: 36),
        ),
        Positioned(
          right: -4,
          top: 12,
          child: RetroSticker(type: StickerType.sparkle, size: 20),
        ),
        Positioned(
          right: -12,
          bottom: 40,
          child: RetroSticker(type: StickerType.heart, size: 24),
        ),
        Positioned(
          left: -12,
          bottom: 20,
          child: RetroSticker(type: StickerType.star, size: 22),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.lifted,
          ),
          child: AspectRatio(
            aspectRatio: PhotoStripGeometry.aspectRatio(layout),
            child: CustomPaint(
              foregroundPainter: _PolkaDotFramePainter(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _PhotoGrid(
                  layout: layout,
                  photos: photos,
                  selected: selected,
                  onSelect: onSelect,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: Center(
            child: SizedBox(
              width: 120,
              child: PhotoBoothBubbleLogo(width: 120),
            ),
          ),
        ),
      ],
    );
  }
}

class _PolkaDotFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    FrameDecorations.paintPolkaDotFrame(
      canvas,
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderWidth: 10,
      dotSpacing: 18,
      dotRadius: 3.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The grid is derived from [PhotoStripGeometry], so the cells here have the
/// same aspect as the exported ones - and each photo is cover-cropped, never
/// stretched.
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.layout,
    required this.photos,
    required this.selected,
    required this.onSelect,
  });

  final PhotoLayout layout;
  final List<XFile> photos;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;
        final double gutter = 6.0;

        final double cellWidth = layout.cols > 1
            ? (maxWidth - gutter * (layout.cols - 1)) / layout.cols
            : maxWidth;
        final double cellHeight = layout.rows > 1
            ? (maxHeight - gutter * (layout.rows - 1)) / layout.rows
            : maxHeight;

        return Wrap(
          spacing: gutter,
          runSpacing: gutter,
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          children: <Widget>[
            for (int i = 0; i < photos.length; i++)
              _SelectableCell(
                index: i,
                selected: i == selected,
                width: cellWidth,
                height: cellHeight,
                photo: photos[i],
                onTap: () => onSelect(i),
              ),
          ],
        );
      },
    );
  }
}

/// One tappable frame in the review grid.
class _SelectableCell extends StatelessWidget {
  const _SelectableCell({
    required this.index,
    required this.selected,
    required this.width,
    required this.height,
    required this.photo,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final double width;
  final double height;
  final XFile photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Photo ${index + 1}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          key: ValueKey<String>('review-cell-$index'),
          duration: AppMotion.of(context, AppMotion.fast),
          width: width,
          height: height,
          padding: EdgeInsets.all(selected ? 3 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.hotPink : Colors.transparent,
              width: 3,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: PhotoImage(photo: photo),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailRow extends StatelessWidget {
  const _ThumbnailRow({
    required this.photos,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<XFile> photos;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < photos.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              button: true,
              selected: i == selectedIndex,
              label: 'Select photo ${i + 1}',
              child: GestureDetector(
                onTap: () => onSelect(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  key: ValueKey<String>('review-thumbnail-$i'),
                  duration: AppMotion.of(context, AppMotion.fast),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i == selectedIndex
                          ? AppColors.hotPink
                          : AppColors.darkLine,
                      width: i == selectedIndex ? 3 : 1.5,
                    ),
                    boxShadow: i == selectedIndex
                        ? <BoxShadow>[
                            BoxShadow(
                              color: AppColors.hotPink.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: PhotoImage(photo: photos[i]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Material(
      color: enabled ? AppColors.darkElevated : AppColors.darkSurface,
      shape: CircleBorder(side: BorderSide(color: AppColors.darkLine)),
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
    );
  }
}