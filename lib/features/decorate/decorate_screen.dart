import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/art/frame_theme_painter.dart';
import '../../core/art/retro_sticker.dart';
import '../../core/art/text_overlay.dart';
import '../../core/media/preview_decode.dart';
import '../../core/filters/effect_image.dart';
import '../../core/filters/photo_effect.dart';
import '../../core/filters/photo_filter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pressable.dart';
import '../../shared/strip_inspector.dart';
import '../album/album_scope.dart';
import '../export/export_screen.dart';
import '../home/layout_geometry.dart';
import '../home/layout_model.dart';
import 'decoration_model.dart';
import 'frame_theme.dart';

/// Presses the extension's request through the first live editor state, so
/// automated verification can record the genuine zoomed editing view. The
/// extension itself is registered in debug builds only - see `main.dart`.
void scheduleEditorZoomForCurrentEditor(double? factor) {
  if (factor == null) return;
  final Element? root = WidgetsBinding.instance.rootElement;
  StatefulElement? editor;
  void visit(Element el) {
    if (editor != null) return;
    if (el is StatefulElement && el.widget is DecorateScreen) {
      editor = el;
      return;
    }
    el.visitChildren(visit);
  }

  if (root != null) visit(root);
  final StatefulElement? editorElement = editor;
  if (editorElement == null) return;
  final _DecorateScreenState state = editorElement.state as _DecorateScreenState;

  // Anchor the scale on the viewport centre, so the strip grows in place the
  // way a pinch at the middle of the photo does. An uncompensated diagonal
  // matrix scales around the child's top-left corner and slides the strip
  // half out of view.
  Element? viewer;
  void findViewer(Element el) {
    if (viewer != null) return;
    if (el.widget is InteractiveViewer) {
      viewer = el;
      return;
    }
    el.visitChildren(findViewer);
  }

  findViewer(editorElement);
  final Element? viewerElement = viewer;
  if (viewerElement == null) {
    state._zoom.value = Matrix4.diagonal3Values(factor, factor, 1.0);
    return;
  }
  // The transform node reports the live viewport size.
  final RenderBox box = viewerElement.renderObject! as RenderBox;
  final double cx = box.size.width / 2;
  final double cy = box.size.height / 2;
  final Matrix4 anchored = Matrix4.identity()
    ..translateByDouble(cx, cy, 0, 1)
    ..scaleByDouble(factor, factor, 1, 1)
    ..translateByDouble(-cx, -cy, 0, 1);
  state._zoom.value = anchored;
}

/// The Decorate editor: a dark workspace with the live composition on top and a
/// compact five-tab tool tray below (Filters, Frames, Stickers, Text, Adjust).
///
/// Every control here is functional. Filters, adjustments and the film-grain
/// overlay all resolve through the same engine the exporter uses, so the preview
/// is a faithful preview of the saved PNG rather than a decorative mock-up.
class DecorateScreen extends StatefulWidget {
  const DecorateScreen({
    super.key,
    required this.layout,
    required this.photos,
    this.initialDecorationState,
    this.albumSessionId,
  });

  final PhotoLayout layout;
  final List<XFile> photos;

  /// Decoration state to start from when reopening a saved album session.
  ///
  /// Null for a fresh composition, which begins from the default styling. When
  /// supplied, every option - frame theme, background, pattern, stickers,
  /// captions, filter, strength and adjustments - is restored exactly, so
  /// editing a saved session continues the user's work rather than resetting it.
  final DecorationState? initialDecorationState;

  /// Album id to re-save under, so an edited session replaces its original
  /// instead of creating a duplicate entry.
  final String? albumSessionId;

  @override
  State<DecorateScreen> createState() => _DecorateScreenState();
}

class _DecorateScreenState extends State<DecorateScreen> {
  static const List<String> _tabLabels = <String>[
    'Filters',
    'Frames',
    'Stickers',
    'Text',
    'Adjust',
  ];
  static const List<IconData> _tabIcons = <IconData>[
    Icons.auto_awesome_rounded,
    Icons.crop_square_rounded,
    Icons.emoji_emotions_rounded,
    Icons.text_fields_rounded,
    Icons.tune_rounded,
  ];

  late DecorationState _state;

  /// Undo/redo history for decoration edits.
  final UndoRedoDecoration _undoRedo = UndoRedoDecoration();

  /// The layout currently being composed.
  ///
  /// Held separately from [DecorationState.layout] so the user can switch
  /// layout mid-session: the photos are untouched and only the arrangement
  /// changes. [PhotoLayout.fitForPhotos] guarantees the chosen layout always
  /// has a cell for every photo already captured.
  late PhotoLayout _layout;

  int _tab = 0;
  StickerType? _pendingSticker;
  int? _selectedSticker;
  int? _selectedText;

  final TextEditingController _textController = TextEditingController();
  Color _textColor = Colors.white;

  /// Horizontal controller for the effect shelf, kept so the selected effect
  /// can be scrolled into view as the user moves through the fifteen.
  final ScrollController _effectScroll = ScrollController();

  /// True while a thumbnail is held to compare against the original.
  ///
  /// Deliberately not part of [DecorationState]: a comparison is a transient
  /// view, never an edit, so it must not land in the undo history or be
  /// persisted.
  bool _comparing = false;

  /// Pinch-to-zoom for the photostrip.
  ///
  /// A 4 CUT strip is a tall 1x4 column, so at fit size it renders as a narrow
  /// ribbon. The controller lets the user inspect a frame closely while the
  /// default scale of 1 still shows the whole strip.
  final TransformationController _zoom = TransformationController();
  double _zoomScale = 1;

  /// Whether the Filters shelf still has effects off-screen to the right.
  ///
  /// Drives the edge fade + chevron that make the horizontal shelf
  /// discoverable; without an affordance, a full 15-chip shelf reads as a
  /// fixed row that ends at 35mm.
  bool _canScrollShelfRight = false;

  @override
  void initState() {
    super.initState();
    _layout = widget.layout;
    // A reopened album session keeps its own layout choice, which may differ
    // from the layout the photos were originally captured into.
    _state =
        widget.initialDecorationState ??
        DecorationState(
          layout: _layout,
          background: BackgroundChoice.cream,
          style: DecorativeStyle.clean,
        );
    _layout = _state.layout;
    _zoom.addListener(_onZoomChanged);
    _effectScroll.addListener(_onShelfScrolled);
    // The shelf controller only knows its scroll extents once the shelf has
    // been laid out for the first time.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onShelfScrolled());
  }

  /// Panning is only enabled once the strip is actually zoomed in, so a
  /// one-finger drag on a sticker at the default zoom is never stolen by the
  /// viewport.
  void _onZoomChanged() {
    final double next = _zoom.value.getMaxScaleOnAxis();
    const double threshold = 1.01;
    final bool crossed = (_zoomScale > threshold) != (next > threshold);
    if (!crossed && (next - _zoomScale).abs() < 0.001) return;
    if (!mounted) return;
    setState(() => _zoomScale = next);
  }

  void _onShelfScrolled() {
    bool canScroll() {
      if (!_effectScroll.hasClients) return false;
      final ScrollPosition position = _effectScroll.position;
      return position.maxScrollExtent - position.pixels > 1;
    }

    final bool next = canScroll();
    if (next == _canScrollShelfRight) return;
    if (!mounted) return;
    setState(() => _canScrollShelfRight = next);
  }

  void _resetZoom() {
    _zoom.value = Matrix4.identity();
  }

  /// Switches the composition to [next], keeping every photo and edit.
  ///
  /// A layout that cannot hold the photos already captured is refused, so
  /// switching can never silently drop a shot.
  void _switchLayout(PhotoLayout next) {
    if (next == _layout) return;
    if (next.photoCount < widget.photos.length) return;
    setState(() {
      _layout = next;
      _state = _state.copyWith(layout: next);
      // Stickers and captions are placed in normalised strip coordinates, so
      // they carry over to the new arrangement untouched.
    });
  }

  @override
  void dispose() {
    _effectScroll.removeListener(_onShelfScrolled);
    _effectScroll.dispose();
    _zoom.removeListener(_onZoomChanged);
    _zoom.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildTopBar(),
            // The photostrip is the point of this screen, so the preview
            // claims every pixel the bounded toolbar does not need. It used to
            // split the page 5:6, which squeezed a tall 4 CUT ribbon down to a
            // few dozen logical pixels.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(S.md, S.xs, S.md, S.sm),
                child: _buildCompositionPreview(),
              ),
            ),
            // Only shown while zoomed, and it sits *below* the strip rather
            // than over it, so no control ever covers the composition.
            if (_zoomScale > 1.01) _buildFitBar(),
            _buildTray(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.sm, S.sm, S.sm, S.xs),
      child: Row(
        children: <Widget>[
          _DarkCircleButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: S.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.albumSessionId == null ? 'Decorate' : 'Edit Session',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.heading.copyWith(color: AppColors.onDark),
                ),
                // Layout can be changed without losing any captured photo:
                // only options with a cell for every photo are offered.
                _LayoutSwitcher(
                  current: _layout,
                  photoCount: widget.photos.length,
                  onSelect: _switchLayout,
                ),
              ],
            ),
          ),
          _DarkCircleButton(
            icon: Icons.undo_rounded,
            onPressed: _undoRedo.canUndo ? _undo : null,
          ),
          _DarkCircleButton(
            icon: Icons.redo_rounded,
            onPressed: _undoRedo.canRedo ? _redo : null,
          ),
          _DarkCircleButton(
            icon: Icons.refresh_rounded,
            onPressed: _resetDecoration,
          ),
          Semantics(
            button: true,
            label: 'Inspect the photostrip full screen',
            child: _DarkCircleButton(
              icon: Icons.zoom_out_map_rounded,
              onPressed: _openInspection,
            ),
          ),
        ],
      ),
    );
  }

  /// The live composition, sized to the strip's aspect.
  ///
  /// Extracted so the editor preview and the full-screen inspector render the
  /// exact same widget tree - the inspection cannot drift from the preview.
  Widget _buildComposition() {
    final double stripAspect = PhotoStripGeometry.aspectRatio(_layout);
    return AspectRatio(
      aspectRatio: stripAspect,
      child: _Composition(
        layout: _layout,
        photos: widget.photos,
        // A comparison hold swaps only the effect, never the stickers,
        // text, frames or adjustments underneath it.
        state: _comparing
            ? _state.copyWith(filter: PhotoEffect.original)
            : _state,
        selectedSticker: _selectedSticker,
        selectedText: _selectedText,
        onStickerTap: (int i) => setState(() {
          _selectedSticker = _selectedSticker == i ? null : i;
          _selectedText = null;
        }),
        onStickerDrag: _moveSticker,
        onTextTap: (int i) => setState(() {
          _selectedText = _selectedText == i ? null : i;
          _selectedSticker = null;
          if (_selectedText != null) {
            _textController.text = _state.texts[i].text;
            _textColor = _state.texts[i].color;
          }
        }),
        onTextDrag: _moveText,
      ),
    );
  }

  Widget _buildCompositionPreview() {
    // The composition is sized purely from the viewport: AspectRatio fits the
    // exported strip inside whatever space is left after the header and the
    // bounded toolbar, so a tall 4 CUT ribbon grows as the toolbar collapses
    // instead of being hard-coded to one emulator's height.
    //
    // No wrapping Stack here: the composition's own Stack is the first Stack
    // inside DecorateScreen, and its paint order is a tested contract.
    return InteractiveViewer(
      transformationController: _zoom,
      // Panning is only armed once zoomed in, so at the default fit a
      // one-finger drag always belongs to the stickers underneath.
      panEnabled: _zoomScale > 1.01,
      scaleEnabled: true,
      minScale: 1.0,
      maxScale: 6.0,
      boundaryMargin: const EdgeInsets.all(160),
      child: Center(child: _buildComposition()),
    );
  }

  /// Slim bar that returns the preview to fit scale. Present only while the
  /// strip is zoomed, so at default size every pixel belongs to the photo.
  Widget _buildFitBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.md, 0, S.md, S.sm),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.zoom_in_rounded,
            size: 16,
            color: AppColors.darkMuted,
          ),
          const SizedBox(width: S.xs),
          Expanded(
            child: Text(
              'Preview zoomed ${_zoomScale.toStringAsFixed(1)}x',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: AppColors.darkMuted),
            ),
          ),
          Semantics(
            button: true,
            label: 'Reset preview zoom',
            child: _PreviewUtilityButton(
              icon: Icons.fit_screen_rounded,
              label: 'Fit',
              onPressed: _resetZoom,
            ),
          ),
        ],
      ),
    );
  }

  /// Full-screen inspection at a larger size, sharing the gesture set with the
  /// album's inspection of saved sessions.
  void _openInspection() {
    showStripInspection(
      context,
      child: _buildComposition(),
      aspectRatio: PhotoStripGeometry.aspectRatio(_layout),
      semanticLabel: 'Full-screen preview of your decorated photo strip',
      title: 'Decorate',
    );
  }

  /// The editing tray.
  ///
  /// Its height is a bounded share of the viewport rather than a flex split, so
  /// the photostrip above always wins the remaining space and the controls can
  /// never grow into an oversized panel.
  Widget _buildTray() {
    final double screen = MediaQuery.sizeOf(context).height;
    // The tray is the only thing competing with the strip for height, so it is
    // kept to roughly a third of the viewport. Every tool panel scrolls
    // internally, so a shorter tray costs reachability nothing while the
    // photostrip - the reason the screen exists - stays dominant.
    //
    // 0.36 rather than 0.32: the Filters tab is header + strength slider +
    // a 104 dp shelf + a hint. At 0.32 the viewport ended inside the slider
    // and the control painted nothing at its resting scroll position, which
    // made the primary control of the tab look absent (visible in the
    // Checkpoint 2 captures as a thumb sliver under the finish button).
    final double trayHeight = (screen * 0.36).clamp(212.0, 340.0).toDouble();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
        border: Border(top: BorderSide(color: AppColors.darkLine)),
      ),
      child: SizedBox(
        height: trayHeight,
        child: Column(
          children: <Widget>[
            _buildTabBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(S.md, S.xs, S.md, S.sm),
                child: _buildTabContent(),
              ),
            ),
            _buildDoneButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(S.sm, S.sm, S.sm, 0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.darkLine)),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < _tabLabels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: _tab == i,
                label: _tabLabels[i],
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    // A 2 dp underline marks the active tool. The Retro Pop
                    // version used a solid pink pill here, which fought the
                    // Minimal Dark palette.
                    padding: const EdgeInsets.symmetric(vertical: S.sm),
                    // 44 dp minimum so every tool is a real thumb target
                    // rather than a ~35 dp strip of text.
                    constraints: const BoxConstraints(minHeight: 44),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _tab == i
                              ? AppColors.onDark
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          _tabIcons[i],
                          size: 17,
                          color: _tab == i
                              ? AppColors.onDark
                              : AppColors.darkMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _tabLabels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _tab == i
                                  ? AppColors.onDark
                                  : AppColors.darkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return _buildFiltersTab();
      case 1:
        return _buildFramesTab();
      case 2:
        return _buildStickersTab();
      case 3:
        return _buildTextTab();
      case 4:
        return _buildAdjustTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------------

  Widget _buildFiltersTab() {
    final bool original = _state.filter == PhotoEffect.original;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(
          title: 'Filters',
          // Original does not grade the photo, so no strength figure applies;
          // "100%" there implied an effect the user did not pick.
          trailing: original ? 'No effect' : '${(_state.filterIntensity * 100).round()}%',
        ),
        const SizedBox(height: S.sm),
        // The strength control sits directly under the section header, not
        // under the shelf. The tray viewport is ~150 dp; with the slider below
        // the 104 dp shelf it landed exactly on the viewport cut and painted
        // nothing - the Checkpoint 2 captures show the same clipped control -
        // while the tap target still worked, so the control looked absent.
        // Above the shelf it is visible and reachable without scrolling.
        _DarkSlider(
          key: const ValueKey<String>('filter-intensity'),
          label: 'Strength',
          semanticLabel: 'Effect strength',
          value: _state.filterIntensity,
          min: 0,
          max: 1,
          display: original ? 'No effect' : '${(_state.filterIntensity * 100).round()}%',
          // Disabled on Original, because there is nothing there to grade.
          // Keeping the control visible but inert is the clearest signal that
          // picking an effect is what makes strength meaningful.
          onChanged: original ? null : _changeEffectIntensity,
        ),
        const SizedBox(height: S.sm),
        if (_state.filter != PhotoEffect.original)
           Align(
             alignment: Alignment.centerRight,
             child: TextButton(
               onPressed: _resetEffectToOriginal,
               child: const Text('Reset to Original'),
             ),
           ),
         _buildFilterShelf(),
        // One hint line, not two. The panel is a fixed height and the
        // strength slider is a primary control: a second explanatory line
        // pushed it below the fold, so the disclosure is folded into the
        // same row rather than given a line of its own.
        if (_state.filter == PhotoEffect.original)
          const _Hint(
            'Original leaves the photo untouched. Digital simulation, '
            'not scanned film.',
          )
        else
          _Hint(
            '${_state.filter.label} at '
            '${(_state.filterIntensity * 100).round()}% - hold a thumbnail to '
            'compare. Digital simulation, not scanned film.',
          ),
      ],
    );
  }

  List<XFile> _photos() => widget.photos;

  /// The effect shelf with a scroll affordance.
  ///
  /// Fifteen effects cannot fit on any phone width, so the shelf scrolls.
  /// A faded right edge plus a chevron, shown only while there is more content
  /// off-screen, makes that discoverable instead of relying on the user to try
  /// dragging. The overlay ignores pointers and semantics: it is decoration,
  /// and the chips underneath remain the targets.
  Widget _buildFilterShelf() {
    return SizedBox(
      height: 104,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _effectScroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: S.md),
              child: Row(
                children: <Widget>[
                  for (final PhotoEffect effect in PhotoEffect.values)
                    Padding(
                      padding: const EdgeInsets.only(right: S.sm),
                      child: _FilterThumb(
                        effect: effect,
                        sample: _photos().isEmpty ? null : _photos().first,
                        selected: _state.filter == effect,
                        // Holding a thumbnail compares against the untouched
                        // original without committing a change, which is the
                        // fastest way to judge a subtle grade.
                        onCompareStart: () => setState(() => _comparing = true),
                        onCompareEnd: () => setState(() => _comparing = false),
                        onTap: () => _changeEffect(effect),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_canScrollShelfRight)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 44,
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: <Color>[
                          Color(0x001C1C20),
                          AppColors.darkSurface,
                        ],
                        stops: <double>[0, 0.75],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.onDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Frames
  // ---------------------------------------------------------------------------

  Widget _buildFramesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeader(title: 'Paper colour'),
        const SizedBox(height: S.sm),
        Wrap(
          spacing: S.sm,
          runSpacing: S.sm,
          children: <Widget>[
            for (final BackgroundChoice choice in BackgroundChoice.values)
              _FrameSwatch(
                choice: choice,
                selected: _state.background == choice,
                onTap: () => setState(() {
                  _state = _state.copyWith(background: choice);
                }),
              ),
          ],
        ),
        const SizedBox(height: S.md),
        const _SectionHeader(title: 'Border'),
        const SizedBox(height: S.sm),
        Wrap(
          spacing: S.sm,
          runSpacing: S.sm,
          children: <Widget>[
            for (final FrameStyle style in FrameStyle.values)
              _ChoicePill(
                label: style.label,
                semanticLabel: '${style.label} border',
                selected: _state.frameStyle == style,
                onTap: () => setState(() {
                  _state = _state.copyWith(frameStyle: style);
                }),
              ),
          ],
        ),
        const SizedBox(height: S.md),
        const _SectionHeader(title: 'Frame theme'),
        const SizedBox(height: S.sm),
        Wrap(
          spacing: S.sm,
          runSpacing: S.sm,
          children: <Widget>[
            for (final FrameTheme theme in FrameTheme.values)
              _ChoicePill(
                label: theme.label,
                semanticLabel: '${theme.label} frame theme',
                selected: _state.frameTheme == theme,
                onTap: () => _changeFrameTheme(theme),
              ),
          ],
        ),
        const SizedBox(height: S.md),
        const _SectionHeader(title: 'Pattern'),
        const SizedBox(height: S.sm),
        Wrap(
          spacing: S.sm,
          runSpacing: S.sm,
          children: <Widget>[
            for (final DecorativeStyle style in DecorativeStyle.values)
              _ChoicePill(
                label: style.label,
                semanticLabel: '${style.label} pattern',
                selected: _state.style == style,
                onTap: () => setState(() {
                  _state = _state.copyWith(style: style);
                }),
              ),
          ],
        ),
        const SizedBox(height: S.md),
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Show the date',
                    style: AppText.label.copyWith(color: AppColors.onDark),
                  ),
                  Text(
                    'Stamp today on the footer',
                    style: AppText.caption.copyWith(color: AppColors.darkMuted),
                  ),
                ],
              ),
            ),
            Switch(
              value: _state.showDate,
              activeThumbColor: AppColors.onDark,
              onChanged: (bool value) => setState(() {
                _state = _state.copyWith(showDate: value);
              }),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Stickers
  // ---------------------------------------------------------------------------

  Widget _buildStickersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeader(title: 'Sticker shelf'),
        const SizedBox(height: S.sm),
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: S.sm,
          crossAxisSpacing: S.sm,
          children: <Widget>[
            for (final StickerType type in StickerType.values)
              _StickerChip(
                type: type,
                selected: _pendingSticker == type,
                onTap: () => setState(() {
                  _pendingSticker = _pendingSticker == type ? null : type;
                }),
              ),
          ],
        ),
        const SizedBox(height: S.md),
        if (_pendingSticker != null)
          PressableScale(
            child: FilledButton.icon(
              onPressed: _addSelectedSticker,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text('Add ${_pendingSticker!.label}'),
            ),
          ),
        if (_state.stickers.isEmpty)
          const _Hint(
            'Tap a sticker, then Add. Drag it on the preview to place it.',
          )
        else ...<Widget>[
          const SizedBox(height: S.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${_state.stickers.length} sticker'
                  '${_state.stickers.length == 1 ? '' : 's'} added',
                  style: AppText.label.copyWith(color: AppColors.onDark),
                ),
              ),
              TextButton(
                onPressed: _removeLastSticker,
                child: const Text('Remove last'),
              ),
            ],
          ),
          if (_selectedSticker != null) ...<Widget>[
            const SizedBox(height: S.sm),
            _StickerControls(
              sticker: _state.stickers[_selectedSticker!],
              canMoveUp: _selectedSticker! > 0,
              canMoveDown: _selectedSticker! < _state.stickers.length - 1,
              onScale: (double f) => _scaleSticker(_selectedSticker!, f),
              onRotate: (double a) => _rotateSticker(_selectedSticker!, a),
              onDuplicate: () => _duplicateSticker(_selectedSticker!),
              onDelete: () => _removeSticker(_selectedSticker!),
              onMoveUp: () =>
                  _reorderSticker(_selectedSticker!, _selectedSticker! - 1),
              onMoveDown: () =>
                  _reorderSticker(_selectedSticker!, _selectedSticker! + 2),
            ),
          ],
          Text(
            'Drag stickers directly on the preview. Tap one to select it.',
            style: AppText.caption.copyWith(color: AppColors.darkMuted),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  Widget _buildTextTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeader(title: 'Caption'),
        const SizedBox(height: S.sm),
        TextField(
          controller: _textController,
          style: AppText.body.copyWith(color: AppColors.onDark),
          onChanged: _onTextChanged,
          maxLength: 24,
          decoration: InputDecoration(
            counterStyle: AppText.caption.copyWith(color: AppColors.darkMuted),
            hintText: 'Type a caption',
            hintStyle: AppText.body.copyWith(color: AppColors.darkMuted),
            filled: true,
            fillColor: AppColors.darkSurface,
            enabledBorder: OutlineInputBorder(
              borderRadius: R.all(R.sm),
              borderSide: const BorderSide(color: AppColors.darkLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: R.all(R.sm),
              borderSide: const BorderSide(color: AppColors.onDark, width: 2),
            ),
          ),
        ),
        const SizedBox(height: S.sm),
        Wrap(
          spacing: S.sm,
          children: <Widget>[
            for (final Color color in _textColors)
              _ColorDot(
                color: color,
                selected: _textColor == color,
                onTap: () => setState(() {
                  _textColor = color;
                  final int? i = _selectedText;
                  if (i != null) _updateText(i, color: color);
                }),
              ),
          ],
        ),
        const SizedBox(height: S.md),
        PressableScale(
          child: FilledButton.icon(
            onPressed: _addText,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add Text'),
          ),
        ),
        const SizedBox(height: S.sm),
        if (_state.texts.isEmpty)
          const _Hint('Add a caption, then drag it into place on the preview.')
        else
          for (int i = 0; i < _state.texts.length; i++)
            _TextRow(
              placement: _state.texts[i],
              selected: _selectedText == i,
              onSelect: () => setState(() {
                _selectedText = i;
                _textController.text = _state.texts[i].text;
                _textColor = _state.texts[i].color;
              }),
              onDelete: () => _removeText(i),
            ),
      ],
    );
  }

  static const List<Color> _textColors = <Color>[
    Colors.white,
    Color(0xFFFF6B9D),
    Color(0xFFFED759),
    Color(0xFF8FB8FC),
    Color(0xFF121212),
  ];

  void _onTextChanged(String value) {
    final int? i = _selectedText;
    if (i == null) return;
    _updateText(i, text: value);
  }

  // ---------------------------------------------------------------------------
  // Adjust
  // ---------------------------------------------------------------------------

  Widget _buildAdjustTab() {
    final PhotoAdjustments a = _state.adjustments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: _SectionHeader(title: 'Adjust')),
            TextButton(
              onPressed: a.isNeutral
                  ? null
                  : () => setState(() {
                      _state = _state.copyWith(
                        adjustments: const PhotoAdjustments(),
                      );
                    }),
              child: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: S.xs),
        _DarkSlider(
          label: 'Brightness',
          value: a.brightness,
          min: -1,
          max: 1,
          display: _signed(a.brightness),
          onChanged: (double v) => _updateAdjust(a.copyWith(brightness: v)),
        ),
        _DarkSlider(
          label: 'Contrast',
          value: a.contrast,
          min: -1,
          max: 1,
          display: _signed(a.contrast),
          onChanged: (double v) => _updateAdjust(a.copyWith(contrast: v)),
        ),
        _DarkSlider(
          label: 'Saturation',
          value: a.saturation,
          min: -1,
          max: 1,
          display: _signed(a.saturation),
          onChanged: (double v) => _updateAdjust(a.copyWith(saturation: v)),
        ),
        _DarkSlider(
          label: 'Warmth',
          value: a.warmth,
          min: -1,
          max: 1,
          display: _signed(a.warmth),
          onChanged: (double v) => _updateAdjust(a.copyWith(warmth: v)),
        ),
        const _Hint('Adjustments stack on top of the selected filter.'),
      ],
    );
  }

  static String _signed(double v) {
    final int pct = (v * 100).round();
    return pct > 0 ? '+$pct' : '$pct';
  }

  void _updateAdjust(PhotoAdjustments adjustments) {
    setState(() {
      _state = _state.copyWith(adjustments: adjustments);
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Widget _buildDoneButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.md, S.xs, S.md, S.sm),
      child: PressableScale(
        child: FilledButton.icon(
          onPressed: () => _goToExport(context),
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          label: const Text('Finish & Save'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: AppColors.onDark,
            foregroundColor: AppColors.darkBackground,
            shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
            textStyle: AppText.buttonSmall,
          ),
        ),
      ),
    );
  }

  void _goToExport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExportScreen(
          layout: _layout,
          photos: widget.photos,
          decorationState: _state,
          // Threaded through so "Save to Album" updates the reopened session
          // instead of creating a duplicate.
          albumSessionId: widget.albumSessionId,
          // Null when storage is unavailable, which hides the album action
          // rather than offering a button that cannot work.
          albumService: maybeAlbumOf(context),
        ),
      ),
    );
  }

  /// Selects a new effect, recording the previous state so the choice is
  /// undoable like every other edit in this screen.
  void _changeEffect(PhotoEffect effect) {
    if (_state.filter == effect) return;
    _undoRedo.record(_state);
    setState(() {
      _state = _state.copyWith(filter: effect);
    });
  }

  void _resetEffectToOriginal() {
    if (_state.filter == PhotoEffect.original &&
        _state.filterIntensity == 1.0) {
      return;
    }
    _undoRedo.record(_state);
    setState(() {
      _state = _state.copyWith(
        filter: PhotoEffect.original,
        filterIntensity: 1.0,
      );
    });
  }

  /// Adjusts effect strength, also recorded so a mis-tap on the track is
  /// recoverable.
  void _changeEffectIntensity(double value) {
    if (_state.filterIntensity == value) return;
    _undoRedo.record(_state);
    setState(() {
      _state = _state.copyWith(filterIntensity: value);
    });
  }

  void _resetDecoration() {    _undoRedo.record(_state);
    setState(() {
      _state = DecorationState(
        layout: _layout,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
      );
      _pendingSticker = null;
      _selectedSticker = null;
      _selectedText = null;
    });
  }

  void _changeFrameTheme(FrameTheme theme) {
    if (_state.frameTheme == theme) return;
    _undoRedo.record(_state);
    setState(() {
      _state = _state.copyWith(frameTheme: theme);
    });
  }

  void _addSelectedSticker() {
    final StickerType? type = _pendingSticker;
    if (type == null) return;
    _undoRedo.record(_state);
    setState(() {
      _state = _state.copyWith(
        stickers: <StickerPlacement>[
          ..._state.stickers,
          StickerPlacement(type: type, x: 0.5, y: 0.5),
        ],
      );
      _pendingSticker = null;
      _selectedSticker = _state.stickers.length - 1;
    });
  }

  void _removeSticker(int index) {
    if (index < 0 || index >= _state.stickers.length) return;
    _undoRedo.record(_state);
    setState(() {
      final List<StickerPlacement> list = List<StickerPlacement>.from(
        _state.stickers,
      )..removeAt(index);
      _state = _state.copyWith(stickers: list);
      if (_selectedSticker == index) _selectedSticker = null;
    });
  }

  void _removeLastSticker() {
    if (_state.stickers.isEmpty) return;
    _removeSticker(_state.stickers.length - 1);
  }

  void _moveSticker(int index, Offset delta, Size area) {
    if (index < 0 || index >= _state.stickers.length) return;
    final StickerPlacement s = _state.stickers[index];
    final List<StickerPlacement> list = List<StickerPlacement>.from(
      _state.stickers,
    );
    list[index] = s.copyWith(
      x: (s.x + delta.dx / area.width).clamp(0.0, 1.0),
      y: (s.y + delta.dy / area.height).clamp(0.0, 1.0),
    );
    setState(() {
      _state = _state.copyWith(stickers: list);
    });
  }

  void _scaleSticker(int index, double factor) {
    if (index < 0 || index >= _state.stickers.length) return;
    _undoRedo.record(_state);
    setState(() {
      final List<StickerPlacement> list = List<StickerPlacement>.from(
        _state.stickers,
      );
      final StickerPlacement s = list[index];
      list[index] = s.copyWith(scale: (s.scale * factor).clamp(0.3, 3.0));
      _state = _state.copyWith(stickers: list);
    });
  }

  void _rotateSticker(int index, double angle) {
    if (index < 0 || index >= _state.stickers.length) return;
    _undoRedo.record(_state);
    setState(() {
      final List<StickerPlacement> list = List<StickerPlacement>.from(
        _state.stickers,
      );
      final StickerPlacement s = list[index];
      list[index] = s.copyWith(rotation: s.rotation + angle);
      _state = _state.copyWith(stickers: list);
    });
  }

  void _duplicateSticker(int index) {
    if (index < 0 || index >= _state.stickers.length) return;
    _undoRedo.record(_state);
    setState(() {
      final List<StickerPlacement> list = List<StickerPlacement>.from(
        _state.stickers,
      );
      final StickerPlacement original = list[index];
      // Offset the duplicate slightly so it doesn't perfectly overlap.
      final double dx = original.x < 0.8 ? 0.08 : -0.08;
      final double dy = original.y < 0.8 ? 0.08 : -0.08;
      list.insert(
        index + 1,
        original.copyWith(
          x: (original.x + dx).clamp(0.0, 1.0),
          y: (original.y + dy).clamp(0.0, 1.0),
        ),
      );
      _state = _state.copyWith(stickers: list);
      _selectedSticker = index + 1;
    });
  }

  void _reorderSticker(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _state.stickers.length) return;
    if (newIndex < 0 || newIndex > _state.stickers.length) return;
    _undoRedo.record(_state);
    setState(() {
      final List<StickerPlacement> list = List<StickerPlacement>.from(
        _state.stickers,
      );
      final StickerPlacement item = list.removeAt(oldIndex);
      final int insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
      list.insert(insertAt, item);
      _state = _state.copyWith(stickers: list);
      _selectedSticker = insertAt;
    });
  }

  void _undo() {
    final DecorationState? previous = _undoRedo.undo(_state);
    if (previous == null) return;
    setState(() {
      _state = previous;
      _selectedSticker = null;
      _selectedText = null;
    });
  }

  void _redo() {
    final DecorationState? next = _undoRedo.redo(_state);
    if (next == null) return;
    setState(() {
      _state = next;
      _selectedSticker = null;
      _selectedText = null;
    });
  }

  void _addText() {
    final String text = _textController.text.trim().isEmpty
        ? 'Cute!'
        : _textController.text.trim();
    _undoRedo.record(_state);
    setState(() {
      _state = _state.copyWith(
        texts: <TextPlacement>[
          ..._state.texts,
          TextPlacement(text: text, x: 0.5, y: 0.85, color: _textColor),
        ],
      );
      _selectedText = _state.texts.length - 1;
    });
  }

  void _updateText(int index, {String? text, Color? color}) {
    if (index < 0 || index >= _state.texts.length) return;
    final List<TextPlacement> list = List<TextPlacement>.from(_state.texts);
    list[index] = list[index].copyWith(text: text, color: color);
    setState(() {
      _state = _state.copyWith(texts: list);
    });
  }

  void _removeText(int index) {
    if (index < 0 || index >= _state.texts.length) return;
    _undoRedo.record(_state);
    setState(() {
      final List<TextPlacement> list = List<TextPlacement>.from(_state.texts)
        ..removeAt(index);
      _state = _state.copyWith(texts: list);
      if (_selectedText == index) _selectedText = null;
    });
  }

  void _moveText(int index, Offset delta, Size area) {
    if (index < 0 || index >= _state.texts.length) return;
    final TextPlacement t = _state.texts[index];
    final List<TextPlacement> list = List<TextPlacement>.from(_state.texts);
    list[index] = t.copyWith(
      x: (t.x + delta.dx / area.width).clamp(0.0, 1.0),
      y: (t.y + delta.dy / area.height).clamp(0.0, 1.0),
    );
    setState(() {
      _state = _state.copyWith(texts: list);
    });
  }
}

// -----------------------------------------------------------------------------
// Composition (shared preview)
// -----------------------------------------------------------------------------

/// Horizontal layout picker for the Decorate screen.
///
/// Only layouts with a cell for every already-captured photo are enabled, so
/// switching can never drop a shot.
class _LayoutSwitcher extends StatelessWidget {
  const _LayoutSwitcher({
    required this.current,
    required this.photoCount,
    required this.onSelect,
  });

  final PhotoLayout current;
  final int photoCount;
  final ValueChanged<PhotoLayout> onSelect;

  @override
  Widget build(BuildContext context) {
    // Only layouts whose cell count matches the photos actually captured are
    // offered. A bigger layout would render empty cells and a smaller one
    // would drop a shot, so switching can neither lose a photo nor show a gap.
    final List<PhotoLayout> options = PhotoLayout.values
        .where((PhotoLayout l) => l.photoCount == photoCount || l == current)
        .toList(growable: false);
    if (options.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: S.xs, bottom: S.xxs),
      child: SizedBox(
        height: 30,
        // Scrollable so the row of layout chips can never overflow on a narrow
        // phone (320dp) or with a large text scale.
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: S.md),
          children: <Widget>[
            for (final PhotoLayout option in options)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Semantics(
                  button: true,
                  selected: option == current,
                  label: 'Layout ${option.label}',
                  child: GestureDetector(
                    key: ValueKey<String>('decorate-layout-${option.name}'),
                    onTap: () => onSelect(option),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: AppMotion.of(context, AppMotion.fast),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        // The selected chip used to be a solid white pill, which
                        // read as an unlabelled blob above the editor and
                        // competed with the photostrip. Selection is now a
                        // white outline on the same dark fill, so it matches the
                        // Minimal Dark language used everywhere else.
                        color: AppColors.darkElevated,
                        border: Border.all(
                          color: option == current
                              ? AppColors.onDark
                              : AppColors.darkLine,
                          width: option == current ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.buttonSmall.copyWith(
                          color: option == current
                              ? AppColors.onDark
                              : AppColors.darkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Composition extends StatelessWidget {
  const _Composition({
    required this.layout,
    required this.photos,
    required this.state,
    required this.selectedSticker,
    required this.selectedText,
    required this.onStickerTap,
    required this.onStickerDrag,
    required this.onTextTap,
    required this.onTextDrag,
  });

  final PhotoLayout layout;
  final List<XFile> photos;
  final DecorationState state;
  final int? selectedSticker;
  final int? selectedText;
  final void Function(int index) onStickerTap;
  final void Function(int index, Offset delta, Size area) onStickerDrag;
  final void Function(int index) onTextTap;
  final void Function(int index, Offset delta, Size area) onTextDrag;

  @override
  Widget build(BuildContext context) {
    final bool onDark = state.background == BackgroundChoice.charcoal;
    // The identical recipe the PNG exporter resolves, so the thumbnail, this
    // preview and the saved file cannot disagree.
    final EffectRecipe recipe = EffectRecipe.resolve(
      state.filter,
      state.filterIntensity,
      adjustments: state.adjustments,
    );

    return ClipRRect(
      borderRadius: R.all(R.md),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final double height = constraints.maxHeight;
          final double scale = width / PhotoStripGeometry.exportWidth;
          final double gridHeight =
              PhotoStripGeometry.contentHeight(layout) * scale;
          final double pad = PhotoStripGeometry.outerPadding * scale;
          final double gutter = PhotoStripGeometry.gutter * scale;
          final double stickerSize = PhotoStripGeometry.stickerSize * scale;

          return DecoratedBox(
            decoration: BoxDecoration(color: state.background.color),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // The frame theme paints opaque paper across the whole strip
                // before drawing its border, so it has to be the FIRST child.
                // Painting it last (as this screen used to) buried the photo
                // cells underneath and the composition rendered as a pink
                // frame around an empty interior - while the filter
                // thumbnails, which live outside this Stack, kept working.
                //
                // The wordmark is skipped here because the footer band below
                // draws it itself; painting it here would put a second one on
                // top of the photo grid.
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      key: const ValueKey<String>('composition-canvas'),
                      child: CustomPaint(
                        painter: _FrameThemePainter(
                          theme: state.frameTheme,
                          wordmarkSize:
                              13 * (width / PhotoStripGeometry.exportWidth),
                          paper: state.background.color,
                          frameStyle: state.frameStyle,
                          contentInset: pad,
                          scale: scale,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: pad,
                  right: pad,
                  top: pad,
                  bottom: math.max(0, height - gridHeight + pad),
                  child: KeyedSubtree(
                    key: const ValueKey<String>('composition-grid'),
                    child: _PhotoGrid(
                      layout: layout,
                      photos: photos,
                      gutter: gutter,
                      recipe: recipe,
                    ),
                  ),
                ),
                // Grain covers the whole photo area as one pass, with the same
                // painter and the same deterministic seed the exporter uses.
                // A per-cell pass would stamp one speck pattern into all four.
                if (recipe.grainAmount > 0)
                  Positioned(
                    left: pad,
                    right: pad,
                    top: pad,
                    height: math.max(0, gridHeight - (pad * 2)),
                    child: EffectGrainOverlay(
                      amount: recipe.grainAmount,
                      seed: EffectRecipe.grainSeed,
                    ),
                  ),
                if (state.style != DecorativeStyle.clean)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: gridHeight,
                    child: _StyleOverlay(
                      style: state.style,
                      color: onDark
                          ? AppColors.onDark.withValues(alpha: 0.16)
                          : AppColors.accentDeep.withValues(alpha: 0.12),
                    ),
                  ),
                for (int i = 0; i < state.stickers.length; i++)
                  Positioned(
                    left: state.stickers[i].x * width - (stickerSize / 2),
                    top: state.stickers[i].y * gridHeight - (stickerSize / 2),
                    child: _DraggableSticker(
                      sticker: state.stickers[i],
                      size: stickerSize,
                      selected: selectedSticker == i,
                      onTap: () => onStickerTap(i),
                      onDrag: (Offset delta) =>
                          onStickerDrag(i, delta, Size(width, gridHeight)),
                    ),
                  ),
                for (int i = 0; i < state.texts.length; i++)
                  Positioned(
                    left:
                        state.texts[i].x * width -
                        (TextOverlayRenderer.measure(
                              state.texts[i],
                              width,
                            ).width /
                            2),
                    top:
                        state.texts[i].y * height -
                        (TextOverlayRenderer.measure(
                              state.texts[i],
                              width,
                            ).height /
                            2),
                    child: _DraggableText(
                      placement: state.texts[i],
                      stripWidth: width,
                      selected: selectedText == i,
                      onTap: () => onTextTap(i),
                      onDrag: (Offset delta) =>
                          onTextDrag(i, delta, Size(width, height)),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: math.max(0, height - gridHeight),
                  child: KeyedSubtree(
                    key: const ValueKey<String>('composition-footer'),
                    child: _BrandingStrip(
                      state: state,
                      onDark: onDark,
                      scale: width / PhotoStripGeometry.exportWidth,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FrameThemePainter extends CustomPainter {
  const _FrameThemePainter({
    required this.theme,
    this.wordmarkSize = 36,
    this.paper,
    this.frameStyle,
    this.contentInset = 0,
    this.scale = 1.0,
  });

  final FrameTheme theme;
  final double wordmarkSize;

  /// The paper colour the user picked, overriding the theme's own.
  final Color? paper;

  /// The border rail the user picked, drawn outside the photo cells only.
  final FrameStyle? frameStyle;

  /// Distance from the strip edge to the photo cells.
  final double contentInset;

  /// Preview width / export width, so rail metrics scale down.
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    FrameThemePainter.paint(
      canvas,
      Rect.fromLTWH(0, 0, size.width, size.height),
      theme,
      wordmarkSize: wordmarkSize,
      // The footer band owns the wordmark; see _BrandingStrip.
      includeWordmark: false,
      paper: paper,
      frameStyle: frameStyle,
      contentInset: contentInset,
      scale: scale,
    );
  }

  @override
  bool shouldRepaint(covariant _FrameThemePainter old) =>
      old.theme != theme ||
      old.wordmarkSize != wordmarkSize ||
      old.paper != paper ||
      old.frameStyle != frameStyle ||
      old.contentInset != contentInset ||
      old.scale != scale;
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.layout,
    required this.photos,
    required this.gutter,
    required this.recipe,
  });

  final PhotoLayout layout;
  final List<XFile> photos;
  final double gutter;

  /// Resolved once for the whole grid; every cell renders identically.
  final EffectRecipe recipe;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Cell sizing is delegated to the shared geometry so the preview uses
        // the same 3:4 cell shape the PNG does. Deriving the height from the
        // width here (as this used to) made preview cells square, so the
        // composition the user styled was not the composition they got.
        final Rect cell = PhotoStripGeometry.previewCell(
          layout: layout,
          availableWidth: constraints.maxWidth,
          gutter: gutter,
        );

        // Decode each cell at the size it is actually painted at. Without this
        // every cell held a full-resolution bitmap: ~48 MB for a 12 MP capture,
        // so a four-shot strip pinned ~190 MB and the editor stuttered on
        // iPhone Safari. RepaintBoundary keeps a sticker drag or a caption
        // edit from re-rasterising the photos underneath.
        final int? decodeWidth = PreviewDecode.forWidth(
          cell.width,
          MediaQuery.devicePixelRatioOf(context),
        );

        return Wrap(
          spacing: gutter,
          runSpacing: gutter,
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          children: <Widget>[
            for (int i = 0; i < photos.length; i++)
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: R.all(1.5 * gutter / S.sm),
                  child: SizedBox(
                    width: cell.width,
                    height: cell.height,
                    child: _FilteredImage(
                      photo: photos[i],
                      recipe: recipe,
                      decodeWidth: decodeWidth,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One photo cell in the Decorate composition.
///
/// The effect is resolved once by the caller and handed straight to
/// [EffectImage], which paints through the same canvas primitives the PNG
/// exporter uses. That is what keeps the preview and the saved file in
/// agreement for colour, grain and glow.
class _FilteredImage extends StatelessWidget {
  const _FilteredImage({
    required this.photo,
    required this.recipe,
    this.decodeWidth,
  });

  final XFile photo;
  final EffectRecipe recipe;
  final int? decodeWidth;

  @override
  Widget build(BuildContext context) {
    return EffectImage(
      photo: photo,
      recipe: recipe,
      decodeWidth: decodeWidth,
    );
  }
}

class _DraggableSticker extends StatelessWidget {
  const _DraggableSticker({
    required this.sticker,
    required this.size,
    required this.selected,
    required this.onTap,
    required this.onDrag,
  });

  final StickerPlacement sticker;
  final double size;
  final bool selected;
  final VoidCallback onTap;
  final void Function(Offset delta) onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onPanUpdate: (DragUpdateDetails d) => onDrag(d.delta),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${sticker.type.label} sticker on the preview',
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.onDark : Colors.transparent,
              width: 1.5,
            ),
          ),
          // Apply scale and rotation transforms so the preview matches export.
          child: Transform.rotate(
            angle: sticker.rotation,
            child: Transform.scale(
              scale: sticker.scale,
              child: RetroSticker(type: sticker.type, size: size),
            ),
          ),
        ),
      ),
    );
  }
}

class _DraggableText extends StatelessWidget {
  const _DraggableText({
    required this.placement,
    required this.stripWidth,
    required this.selected,
    required this.onTap,
    required this.onDrag,
  });

  final TextPlacement placement;
  final double stripWidth;
  final bool selected;
  final VoidCallback onTap;
  final void Function(Offset delta) onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onPanUpdate: (DragUpdateDetails d) => onDrag(d.delta),
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Caption: ${placement.text}',
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: R.all(R.xs),
            border: Border.all(
              color: selected ? AppColors.onDark : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: TextOverlay(placement: placement, stripWidth: stripWidth),
        ),
      ),
    );
  }
}

class _StyleOverlay extends StatelessWidget {
  const _StyleOverlay({required this.style, required this.color});

  final DecorativeStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _OverlayPainter(style: style, color: color),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.style, required this.color});

  final DecorativeStyle style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (style == DecorativeStyle.clean) return;

    final Paint paint = Paint()..color = color;
    final double base = size.shortestSide * 0.08;
    final double spacing = size.shortestSide * 0.2;

    for (double y = base; y < size.height; y += spacing) {
      for (double x = base; x < size.width; x += spacing) {
        final Offset center = Offset(x, y);
        switch (style) {
          case DecorativeStyle.clean:
            return;
          case DecorativeStyle.hearts:
            canvas.drawPath(_heart(center, base), paint);
          case DecorativeStyle.stars:
            canvas.drawPath(_star(center, base * 0.7), paint);
          case DecorativeStyle.sparkle:
            canvas.drawCircle(center, base * 0.32, paint);
            canvas.drawRect(
              Rect.fromCenter(
                center: center,
                width: base * 1.2,
                height: base * 0.2,
              ),
              paint,
            );
            canvas.drawRect(
              Rect.fromCenter(
                center: center,
                width: base * 0.2,
                height: base * 1.2,
              ),
              paint,
            );
        }
      }
    }
  }

  static Path _heart(Offset center, double size) {
    final Path path = Path();
    path.moveTo(center.dx, center.dy + size * 0.4);
    path.quadraticBezierTo(
      center.dx - size * 0.65,
      center.dy - size * 0.3,
      center.dx,
      center.dy + size * 0.05,
    );
    path.quadraticBezierTo(
      center.dx + size * 0.65,
      center.dy - size * 0.3,
      center.dx,
      center.dy + size * 0.4,
    );
    path.close();
    return path;
  }

  static Path _star(Offset center, double radius) {
    final Path path = Path();
    for (int i = 0; i < 10; i++) {
      final double r = i.isEven ? radius : radius * 0.45;
      final double angle = (i * math.pi / 5) - (math.pi / 2);
      final Offset point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.style != style || old.color != color;
}

/// The branding footer beneath the photo grid.
///
/// The wordmark is painted by [FrameThemePainter.paintWordmark] - the exact
/// routine `PhotoStripRenderer` uses for the export - so the preview footer and
/// the exported footer are the same artwork at the same relative size, rather
/// than two hand-written approximations that drift apart.
class _BrandingStrip extends StatelessWidget {
  const _BrandingStrip({
    required this.state,
    required this.onDark,
    required this.scale,
  });

  final DecorationState state;
  final bool onDark;

  /// Preview width / export width, so export-space constants scale down.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final Color foreground = onDark ? AppColors.onDark : AppColors.popInk;
    return CustomPaint(
      painter: _FooterPainter(
        state: state,
        foreground: foreground,
        scale: scale,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _FooterPainter extends CustomPainter {
  const _FooterPainter({
    required this.state,
    required this.foreground,
    required this.scale,
  });

  final DecorationState state;
  final Color foreground;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect footer = Offset.zero & size;

    // Mirrors `_renderBranding` in the exporter: same wordmark routine, same
    // export-space em size, same date offset.
    FrameThemePainter.paintWordmark(
      canvas,
      footer,
      state.frameTheme,
      36 * scale,
    );

    if (!state.showDate) return;

    final TextPainter date = _datePainter(
      formatExportDate(state.displayDate),
      TextStyle(
        fontSize: 20 * scale,
        fontWeight: FontWeight.w600,
        color: foreground.withValues(alpha: 0.75),
        letterSpacing: 2 * scale,
      ),
    );
    date.paint(
      canvas,
      Offset(
        footer.center.dx - date.width / 2,
        footer.center.dy + (24 * scale),
      ),
    );
  }

  static TextPainter _datePainter(String text, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    );
    painter.layout();
    return painter;
  }

  @override
  bool shouldRepaint(covariant _FooterPainter old) =>
      old.state != state || old.foreground != foreground || old.scale != scale;
}

// -----------------------------------------------------------------------------
// Tray controls
// -----------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: AppText.overline.copyWith(color: AppColors.darkMuted),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: AppText.label.copyWith(color: AppColors.onDark),
          ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: S.sm),
      child: Text(
        text,
        style: AppText.caption.copyWith(color: AppColors.darkMuted),
      ),
    );
  }
}

/// Small dark capsule action used under the preview (Fit / Inspect).
///
/// A [TextButton] keeps the compact footprint; the 48 dp [Semantics]-friendly
/// touch floor comes from the button's own minimum size.
class _PreviewUtilityButton extends StatelessWidget {
  const _PreviewUtilityButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: AppColors.onDark),
      label: Text(
        label,
        style: AppText.caption.copyWith(color: AppColors.onDark),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.onDark,
        backgroundColor: AppColors.darkElevated,
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
      ),
    );
  }
}

class _DarkSlider extends StatelessWidget {
  const _DarkSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    this.semanticLabel,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double>? onChanged;

  /// Overrides the visible [label] for assistive technology.
  ///
  /// "Strength" is ambiguous on its own because the screen has one slider per
  /// section; the semantic form names what is actually being adjusted.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: AppText.label.copyWith(color: AppColors.onDark),
              ),
            ),
            Text(
              display,
              style: AppText.caption.copyWith(color: AppColors.darkMuted),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.onDark,
            inactiveTrackColor: AppColors.darkLine,
            thumbColor: AppColors.onDark,
            overlayColor: AppColors.onDark.withValues(alpha: 0.18),
          ),
          child: Semantics(
            label: semanticLabel ?? label,
            // Announce the live value so the adjustment is legible without
            // sight, and mark the control's state when it cannot be changed.
            value: display,
            enabled: onChanged != null,
            child: ExcludeSemantics(
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterThumb extends StatelessWidget {
  const _FilterThumb({
    required this.effect,
    required this.sample,
    required this.selected,
    required this.onTap,
    this.onCompareStart,
    this.onCompareEnd,
  });

  final PhotoEffect effect;
  final XFile? sample;
  final bool selected;
  final VoidCallback onTap;

  /// Press-and-hold compares the whole preview against the original.
  final VoidCallback? onCompareStart;
  final VoidCallback? onCompareEnd;

  /// Chip edge in logical pixels; the image inside is inset by the border.
  static const double _chip = 72;
  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    // Thumbnail, preview and export all resolve the same recipe, so a chip
    // shows the treatment the user is about to get - grain and glow included.
    final EffectRecipe recipe = EffectRecipe.resolve(effect, 1);
    final double imageSide = _chip - (_inset * 2);

    // A small chip was decoding the whole 12 MP frame. Capping the decode is
    // the single biggest win in the editor: this row alone held as many
    // full-size bitmaps as there were effects.
    final Widget graded = sample != null
        ? SizedBox(
            width: imageSide,
            height: imageSide,
            child: EffectImage(
              photo: sample!,
              recipe: recipe,
              decodeWidth: PreviewDecode.forSize(
                imageSide,
                MediaQuery.devicePixelRatioOf(context),
              ),
            ),
          )
        : Container(
            width: imageSide,
            height: imageSide,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFFFFC1D9),
                  Color(0xFFFF6B9D),
                  Color(0xFF6EA8FF),
                ],
              ),
            ),
          );

    return Semantics(
      button: true,
      selected: selected,
      label: '${effect.label} effect',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPressStart: onCompareStart == null
            ? null
            : (_) => onCompareStart!(),
        onLongPressEnd: onCompareEnd == null ? null : (_) => onCompareEnd!(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.fast),
              width: _chip,
              height: _chip,
              padding: const EdgeInsets.all(_inset),
              decoration: BoxDecoration(
                borderRadius: R.all(R.sm),
                border: Border.all(
                  color: selected ? AppColors.onDark : AppColors.darkLine,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: R.all(R.xs + 2),
                child: graded,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: _chip + 2,
              child: Text(
                effect.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(
                  fontSize: 10,
                  color: selected ? AppColors.onDark : AppColors.darkMuted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.onDark : AppColors.darkSurface,
            borderRadius: R.pillRadius,
            border: Border.all(
              color: selected ? AppColors.onDark : AppColors.darkLine,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: AppText.buttonSmall.copyWith(
              color: selected ? AppColors.onAccent : AppColors.onDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? AppColors.onDark : AppColors.darkLine,
            width: selected ? 3 : 1.5,
          ),
        ),
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.placement,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
  });

  final TextPlacement placement;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: S.xs),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: R.all(R.sm),
          border: Border.all(
            color: selected ? AppColors.onDark : AppColors.darkLine,
            width: selected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xs),
          child: Row(
            children: <Widget>[
              Icon(Icons.text_fields_rounded, color: placement.color, size: 18),
              const SizedBox(width: S.sm),
              Expanded(
                child: Text(
                  placement.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(color: AppColors.onDark),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.darkMuted,
                tooltip: 'Remove caption',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrameSwatch extends StatelessWidget {
  const _FrameSwatch({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final BackgroundChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${choice.label} frame',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          width: S.touchTarget,
          height: S.touchTarget,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: R.all(R.md),
            border: Border.all(
              color: selected ? AppColors.onDark : AppColors.darkLine,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: choice.color,
              borderRadius: R.all(R.sm),
              border: Border.all(color: AppColors.darkLine),
            ),
            child: selected
                ? const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.popInk,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _StickerChip extends StatelessWidget {
  const _StickerChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final StickerType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${type.label} sticker',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.onDark.withValues(alpha: 0.2)
                : AppColors.darkSurface,
            borderRadius: R.all(R.md),
            border: Border.all(
              color: selected ? AppColors.onDark : AppColors.darkLine,
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(child: RetroSticker(type: type, size: 28)),
        ),
      ),
    );
  }
}

/// Sticker manipulation controls shown in the Stickers tab when a sticker is
/// selected: scale, rotate, duplicate, delete and layer ordering.
class _StickerControls extends StatelessWidget {
  const _StickerControls({
    required this.sticker,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onScale,
    required this.onRotate,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final StickerPlacement sticker;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<double> onScale;
  final ValueChanged<double> onRotate;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(S.sm),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: R.all(R.md),
        border: Border.all(color: AppColors.darkLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${sticker.type.label} sticker',
            style: AppText.label.copyWith(color: AppColors.onDark),
          ),
          const SizedBox(height: S.xs),
          Text(
            'Scale: ${(sticker.scale * 100).round()}%',
            style: AppText.caption.copyWith(color: AppColors.darkMuted),
          ),
          const SizedBox(height: S.xs),
          // Scale controls
          Row(
            children: <Widget>[
              Expanded(
                child: _ControlButton(
                  icon: Icons.remove_rounded,
                  label: 'Smaller',
                  onPressed: () => onScale(0.85),
                ),
              ),
              const SizedBox(width: S.xs),
              Expanded(
                child: _ControlButton(
                  icon: Icons.add_rounded,
                  label: 'Larger',
                  onPressed: () => onScale(1.18),
                ),
              ),
            ],
          ),
          const SizedBox(height: S.xs),
          // Rotate controls
          Row(
            children: <Widget>[
              Expanded(
                child: _ControlButton(
                  icon: Icons.rotate_left_rounded,
                  label: 'Rotate L',
                  onPressed: () => onRotate(-math.pi / 12),
                ),
              ),
              const SizedBox(width: S.xs),
              Expanded(
                child: _ControlButton(
                  icon: Icons.rotate_right_rounded,
                  label: 'Rotate R',
                  onPressed: () => onRotate(math.pi / 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: S.xs),
          // Duplicate & Delete
          Row(
            children: <Widget>[
              Expanded(
                child: _ControlButton(
                  icon: Icons.copy_rounded,
                  label: 'Duplicate',
                  onPressed: onDuplicate,
                ),
              ),
              const SizedBox(width: S.xs),
              Expanded(
                child: _ControlButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  onPressed: onDelete,
                  // Destructive actions keep a red signal in Minimal Dark;
                  // white is reserved for selection and primary actions.
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: S.xs),
          // Layer ordering
          Row(
            children: <Widget>[
              Expanded(
                child: _ControlButton(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Forward',
                  onPressed: canMoveUp ? onMoveUp : null,
                ),
              ),
              const SizedBox(width: S.xs),
              Expanded(
                child: _ControlButton(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Backward',
                  onPressed: canMoveDown ? onMoveDown : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color fg = color ?? AppColors.onDark;
    return Material(
      color: AppColors.darkElevated,
      borderRadius: R.all(R.sm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: R.all(R.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: S.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: onPressed != null ? fg : AppColors.darkMuted,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppText.caption.copyWith(
                  fontSize: 9,
                  color: onPressed != null ? fg : AppColors.darkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkCircleButton extends StatelessWidget {
  const _DarkCircleButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Material(
      color: AppColors.darkElevated,
      shape: const CircleBorder(side: BorderSide(color: AppColors.darkLine)),
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
