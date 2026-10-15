import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/media/photo_source.dart';
import '../../core/media/preview_decode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/minimal_dark.dart';
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
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildHeader(context),
            Expanded(child: _buildStage()),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  /// Minimal Dark header: back, the layout the session is shooting, and the
  /// live photo count.
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.sm, S.sm, S.md, S.xs),
      child: Row(
        children: <Widget>[
          MinimalIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
          ),
          const SizedBox(width: S.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Review',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.heading.copyWith(color: AppColors.onDark),
                ),
                Text(
                  '${_layout.label} · ${_photos.length} '
                  '${_photos.length == 1 ? 'photo' : 'photos'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: AppColors.darkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The photo stage.
  ///
  /// The grid deliberately re-arranges a single-column layout for *review*:
  /// the exported 4 CUT is a 1x4 column that cannot be shown at a useful size
  /// on a portrait phone, so the four frames are presented 2x2. Each cell
  /// still keeps the exported 3:4 cell aspect and each photo is cover-cropped,
  /// so nothing is stretched, rotated or cropped tighter than the strip will
  /// crop it. The strip geometry used by the exporter is untouched.
  Widget _buildStage() {
    if (_photos.isEmpty) return _buildEmptyState();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gutter = S.sm;
        const double padding = S.lg;
        final double available = constraints.maxWidth - (padding * 2);
        final int columns = _reviewColumns(available);

        final double cellWidth =
            (available - (gutter * (columns - 1))) / columns;
        // The exported cell aspect (3:4 portrait) is the contract: matching it
        // means the reviewer sees the same shape that gets exported.
        final double cellHeight =
            cellWidth / PhotoStripGeometry.cellAspect(_layout);

        final int rowCount = (_photos.length / columns).ceil();

        // The grid is sized from the width, never stretched to the viewport, and the
        // whole stage scrolls when a tall grid needs the room. IntrinsicHeight
        // plus the min-height box centres the grid in whatever space is left
        // instead of stranding it at the top with a large empty band below.
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(padding, S.md, padding, S.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int row = 0; row < rowCount; row++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: row == rowCount - 1 ? 0 : gutter,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (int col = 0; col < columns; col++)
                            Padding(
                              padding: EdgeInsets.only(
                                right: col == columns - 1 ? 0 : gutter,
                              ),
                              child: _ReviewCell(
                                index: row * columns + col,
                                selected: (row * columns + col) == _selected,
                                width: cellWidth,
                                height: cellHeight,
                                photo: row * columns + col < _photos.length
                                    ? _photos[row * columns + col]
                                    : null,
                                onTap: _select,
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: S.md),
                  _SelectionCaption(selected: _selected, total: _photos.length),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// How many columns the review grid uses.
  ///
  /// Multi-column layouts keep their own arrangement. A single-column layout is
  /// fanned out to two columns so the photos are shown side by side at a size
  /// the user can actually judge, instead of one narrow ribbon the height of
  /// the whole screen.
  int _reviewColumns(double availableWidth) {
    if (_layout.cols > 1) return _layout.cols;
    if (_photos.length < 2) return 1;
    // Never let a cell get so small the photo becomes unreadable.
    const double minCellWidth = 110;
    final int fit = (availableWidth / (minCellWidth + S.sm)).floor();
    return fit.clamp(2, 2);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(S.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.photo_camera_back_outlined,
              size: 44,
              color: AppColors.darkMuted,
            ),
            const SizedBox(height: S.md),
            Text(
              'No photos yet',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: AppColors.onDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    // The actions sit on the dark review stage, below the scrollable stage,
    // and must clear the home indicator on devices with a bottom safe area.
    return Container(
      padding: EdgeInsets.fromLTRB(
        S.md,
        S.sm,
        S.md,
        S.sm + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkBackground,
        border: Border(top: BorderSide(color: AppColors.darkLine)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Side by side while there is room, stacked when the viewport is
          // genuinely narrow, so neither label is ever clipped.
          final bool stacked = constraints.maxWidth < 300;
          if (stacked) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _RetakeButton(busy: _retaking, onPressed: _retakeSelected),
                const SizedBox(height: S.sm),
                _NextButton(onPressed: _next),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(
                child: _RetakeButton(
                  busy: _retaking,
                  onPressed: _retakeSelected,
                ),
              ),
              const SizedBox(width: S.sm),
              Expanded(child: _NextButton(onPressed: _next)),
            ],
          );
        },
      ),
    );
  }
}

/// "Tap a photo to select it · Retake replaces just that one".
class _SelectionCaption extends StatelessWidget {
  const _SelectionCaption({required this.selected, required this.total});

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

/// One tappable frame in the review grid.
///
/// The photo is painted with `BoxFit.cover` against the exported 3:4 cell
/// aspect, so a frame that does not match the cell exactly is cropped the same
/// way the exporter crops it - never stretched, never rotated.
class _ReviewCell extends StatelessWidget {
  const _ReviewCell({
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
  final XFile? photo;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final XFile? file = photo;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Photo ${index + 1}',
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          key: ValueKey<String>('review-cell-$index'),
          duration: AppMotion.of(context, AppMotion.fast),
          width: width,
          height: height,
          padding: EdgeInsets.all(selected ? 2 : 0),
          decoration: BoxDecoration(
            borderRadius: R.all(R.sm),
            border: Border.all(
              color: selected ? AppColors.onDark : AppColors.darkLine,
              width: selected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: R.all(R.xs),
            child: file == null
                ? const ColoredBox(color: AppColors.darkSurface)
                : PhotoImage(
                    photo: file,
                    // Decode at the painted size, not the stored 12 MP.
                    decodeWidth: PreviewDecode.forWidth(
                      width,
                      MediaQuery.devicePixelRatioOf(context),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The secondary action: an outlined pill on the dark stage.
///
/// The app theme paints every `OutlinedButton` with a near-white
/// `backgroundColor`, so this button has to set its own dark fill. Without it
/// the label rendered white-on-white and was effectively invisible.
class _RetakeButton extends StatelessWidget {
  const _RetakeButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      enabled: !busy,
      child: OutlinedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onDark,
                ),
              )
            : const Icon(Icons.refresh_rounded, size: 20),
        label: const Text(
          'Retake',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          // Dark fill + hairline border keeps "Retake" legible while staying
          // visually distinct from the solid white "Continue".
          backgroundColor: AppColors.darkElevated,
          foregroundColor: AppColors.onDark,
          disabledBackgroundColor: AppColors.darkSurface,
          disabledForegroundColor: AppColors.darkMuted,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: S.sm),
          side: const BorderSide(color: AppColors.darkLine, width: 2),
          shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
        ),
      ),
    );
  }
}

/// The primary action: a solid white pill with dark text.
class _NextButton extends StatelessWidget {
  const _NextButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: const Text('Next', maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: S.sm),
          backgroundColor: AppColors.onDark,
          foregroundColor: AppColors.darkBackground,
          shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
        ),
      ),
    );
  }
}
