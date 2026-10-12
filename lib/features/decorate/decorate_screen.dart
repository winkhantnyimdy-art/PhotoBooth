import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/art/frame_theme_painter.dart';
import '../../core/art/retro_sticker.dart';
import '../../core/art/text_overlay.dart';
import '../../core/filters/film_grain.dart';
import '../../core/media/photo_source.dart';
import '../../core/filters/photo_filter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pressable.dart';
import '../export/export_screen.dart';
import '../home/layout_geometry.dart';
import '../home/layout_model.dart';
import 'decoration_model.dart';
import 'frame_theme.dart';

/// The Decorate editor: a dark workspace with the live composition on top and a
/// compact five-tab tool tray below (Filters, Frames, Stickers, Text, Adjust).
///
/// Every control here is functional. Filters, adjustments and the film-grain
/// overlay all resolve through the same engine the exporter uses, so the preview
/// is a faithful preview of the saved PNG rather than a decorative mock-up.
class DecorateScreen extends StatefulWidget {
  const DecorateScreen({super.key, required this.layout, required this.photos});

  final PhotoLayout layout;
  final List<XFile> photos;

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

  @override
  void initState() {
    super.initState();
    _layout = widget.layout;
    _state = DecorationState(
      layout: _layout,
      background: BackgroundChoice.cream,
      style: DecorativeStyle.clean,
    );
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
    _textController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildTopBar(),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.md),
                child: _buildCompositionPreview(),
              ),
            ),
            Expanded(flex: 6, child: _buildTray()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.md, S.sm, S.md, S.xs),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _DarkCircleButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              _DarkCircleButton(
                icon: Icons.undo_rounded,
                onPressed: _undoRedo.canUndo ? _undo : null,
              ),
              _DarkCircleButton(
                icon: Icons.redo_rounded,
                onPressed: _undoRedo.canRedo ? _redo : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Decorate',
                    style: AppText.title.copyWith(color: AppColors.onDark),
                  ),
                ),
              ),
          TextButton.icon(
                onPressed: _resetDecoration,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onDark,
                  textStyle: AppText.buttonSmall,
                ),
              ),
            ],
          ),
          // Layout can be changed without losing any captured photo: only
          // options with a cell for every photo are offered.
          _LayoutSwitcher(
            current: _layout,
            photoCount: widget.photos.length,
            onSelect: _switchLayout,
          ),
        ],
      ),
    );
  }

  Widget _buildCompositionPreview() {
    final double stripAspect = PhotoStripGeometry.aspectRatio(_layout);
    return Center(
      child: AspectRatio(
        aspectRatio: stripAspect,
        child: _Composition(
          layout: _layout,
          photos: widget.photos,
          state: _state,
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
      ),
    );
  }

  Widget _buildTray() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // On very short screens the tab bar + done button can exceed the
          // available height. In that case, make the whole tray scrollable
          // so every control stays reachable.
          final double minTabBarHeight = 48;
          final double minDoneButtonHeight = 68;
          final double minContentHeight = 80;
          final double totalMin = minTabBarHeight + minContentHeight + minDoneButtonHeight;

          if (constraints.maxHeight < totalMin) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildTabBar(),
                  _buildTabContent(),
                  _buildDoneButton(context),
                ],
              ),
            );
          }

          return Column(
            children: <Widget>[
              _buildTabBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(S.md, S.sm, S.md, S.sm),
                  child: _buildTabContent(),
                ),
              ),
              _buildDoneButton(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.sm, S.md, S.sm, S.xs),
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
                  child: AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.fast),
                    padding: const EdgeInsets.symmetric(vertical: S.sm - 2),
                    decoration: BoxDecoration(
                      color: _tab == i
                          ? AppColors.hotPink
                          : Colors.transparent,
                      borderRadius: R.pillRadius,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          _tabIcons[i],
                          size: 18,
                          color: _tab == i
                              ? AppColors.onAccent
                              : AppColors.darkMuted,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tabLabels[i],
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: AppText.caption.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _tab == i
                                ? AppColors.onAccent
                                : AppColors.darkMuted,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(
          title: 'Filters',
          trailing: '${(_state.filterIntensity * 100).round()}%',
        ),
        const SizedBox(height: S.sm),
        SizedBox(
          height: 96,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final PhotoFilterType type in PhotoFilterType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: S.sm),
                    child: _FilterThumb(
                      type: type,
                      sample: _photos().isEmpty ? null : _photos().first,
                      selected: _state.filter == type,
                      onTap: () => setState(() {
                        _state = _state.copyWith(filter: type);
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: S.md),
        _DarkSlider(
          key: const ValueKey<String>('filter-intensity'),
          label: 'Strength',
          value: _state.filterIntensity,
          min: 0,
          max: 1,
          display: '${(_state.filterIntensity * 100).round()}%',
          onChanged: _state.filter == PhotoFilterType.original
              ? null
              : (double v) => setState(() {
                  _state = _state.copyWith(filterIntensity: v);
                }),
        ),
        if (_state.filter == PhotoFilterType.original)
          const _Hint('Pick a filter above, then fine-tune its strength.')
        else
          _Hint('${_state.filter.label} at '
              '${(_state.filterIntensity * 100).round()}% strength.'),
      ],
    );
  }

  List<XFile> _photos() => widget.photos;

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
              activeThumbColor: AppColors.hotPink,
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
          const _Hint('Tap a sticker, then Add. Drag it on the preview to place it.')
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
              onMoveUp: () => _reorderSticker(_selectedSticker!, _selectedSticker! - 1),
              onMoveDown: () => _reorderSticker(_selectedSticker!, _selectedSticker! + 2),
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
              borderSide: const BorderSide(color: AppColors.hotPink, width: 2),
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
      padding: const EdgeInsets.fromLTRB(S.md, S.sm, S.md, S.md),
      child: PressableScale(
        child: FilledButton.icon(
          onPressed: () => _goToExport(context),
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          label: const Text('Finish & Save'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: AppColors.hotPink,
            shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
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
        ),
      ),
    );
  }

  void _resetDecoration() {
    _undoRedo.record(_state);
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
      final List<StickerPlacement> list = List<StickerPlacement>.from(_state.stickers)
        ..removeAt(index);
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
    final List<StickerPlacement> list = List<StickerPlacement>.from(_state.stickers);
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
      final List<StickerPlacement> list = List<StickerPlacement>.from(_state.stickers);
      final StickerPlacement s = list[index];
      list[index] = s.copyWith(scale: (s.scale * factor).clamp(0.3, 3.0));
      _state = _state.copyWith(stickers: list);
    });
  }

  void _rotateSticker(int index, double angle) {
    if (index < 0 || index >= _state.stickers.length) return;
    _undoRedo.record(_state);
    setState(() {
      final List<StickerPlacement> list = List<StickerPlacement>.from(_state.stickers);
      final StickerPlacement s = list[index];
      list[index] = s.copyWith(rotation: s.rotation + angle);
      _state = _state.copyWith(stickers: list);
    });
  }

  void _duplicateSticker(int index) {
    if (index < 0 || index >= _state.stickers.length) return;
    _undoRedo.record(_state);
    setState(() {
      final List<StickerPlacement> list = List<StickerPlacement>.from(_state.stickers);
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
      final List<StickerPlacement> list = List<StickerPlacement>.from(_state.stickers);
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
        .where(
          (PhotoLayout l) => l.photoCount == photoCount || l == current,
        )
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
                        color: option == current
                            ? AppColors.hotPink
                            : AppColors.darkElevated,
                        border: Border.all(
                          color: option == current
                              ? AppColors.hotPink
                              : AppColors.darkLine,
                        ),
                      ),
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.buttonSmall.copyWith(
                          color: option == current
                              ? AppColors.onAccent
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
    final List<double> matrix = buildMatrix(
      state.filter,
      state.filterIntensity,
      state.adjustments,
    );
    final bool filtered = !isIdentityMatrix(matrix);

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
                      colorFilter: filtered
                          ? ColorFilter.matrix(matrix)
                          : null,
                    ),
                  ),
                ),
                if (state.filter.hasGrain && state.filterIntensity > 0)
                  Positioned(
                    left: pad,
                    right: pad,
                    top: pad,
                    height: math.max(0, gridHeight - (pad * 2)),
                    child: FilmGrainOverlay(intensity: state.filterIntensity),
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
                    left: state.texts[i].x * width -
                        (TextOverlayRenderer.measure(state.texts[i], width)
                                .width /
                            2),
                    top: state.texts[i].y * height -
                        (TextOverlayRenderer.measure(state.texts[i], width)
                                .height /
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
                    child: _BrandingStrip(state: state, onDark: onDark),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _FrameThemePainter(
                        theme: state.frameTheme,
                        wordmarkSize: 13 * (width / PhotoStripGeometry.exportWidth),
                      ),
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
  const _FrameThemePainter({required this.theme, this.wordmarkSize = 36});

  final FrameTheme theme;
  final double wordmarkSize;

  @override
  void paint(Canvas canvas, Size size) {
    FrameThemePainter.paint(
      canvas,
      Rect.fromLTWH(0, 0, size.width, size.height),
      theme,
      wordmarkSize: wordmarkSize,
    );
  }

  @override
  bool shouldRepaint(covariant _FrameThemePainter old) =>
      old.theme != theme || old.wordmarkSize != wordmarkSize;
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.layout,
    required this.photos,
    required this.gutter,
    required this.colorFilter,
  });

  final PhotoLayout layout;
  final List<XFile> photos;
  final double gutter;
  final ColorFilter? colorFilter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cell =
            (constraints.maxWidth - (gutter * (layout.cols - 1))) / layout.cols;
        return Wrap(
          spacing: gutter,
          runSpacing: gutter,
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          children: <Widget>[
            for (int i = 0; i < photos.length; i++)
              ClipRRect(
                borderRadius: R.all(1.5 * gutter / S.sm),
                child: SizedBox(
                  width: cell,
                  height: cell,
                  child: _FilteredImage(
                    photo: photos[i],
                    colorFilter: colorFilter,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FilteredImage extends StatelessWidget {
  const _FilteredImage({required this.photo, required this.colorFilter});

  final XFile photo;
  final ColorFilter? colorFilter;

  @override
  Widget build(BuildContext context) {
    final Widget image = PhotoImage(photo: photo);
    if (colorFilter == null) return image;
    return ColorFiltered(colorFilter: colorFilter!, child: image);
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
              color: selected ? AppColors.hotPink : Colors.transparent,
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
              color: selected ? AppColors.hotPink : Colors.transparent,
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

class _BrandingStrip extends StatelessWidget {
  const _BrandingStrip({required this.state, required this.onDark});

  final DecorationState state;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final Color foreground = onDark ? AppColors.onDark : AppColors.textPrimary;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: foreground.withValues(alpha: 0.16)),
        ),
      ),
      child: Center(
        child: FittedBox(
          // The footer is only as tall as the strip leaves over after the photo
          // grid, which is small on narrow previews. Scale the branding group
          // down to fit instead of letting it overflow the footer.
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 80,
                child: Text(
                  'PHOTOBOOTH',
                  textAlign: TextAlign.center,
                  style: AppText.wordmark.copyWith(
                    fontSize: 13,
                    color: AppColors.bubblePink,
                  ),
                ),
              ),
              if (state.showDate) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  formatExportDate(state.displayDate),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: foreground.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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

class _DarkSlider extends StatelessWidget {
  const _DarkSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double>? onChanged;

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
            activeTrackColor: AppColors.hotPink,
            inactiveTrackColor: AppColors.darkLine,
            thumbColor: AppColors.hotPink,
            overlayColor: AppColors.hotPink.withValues(alpha: 0.18),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _FilterThumb extends StatelessWidget {
  const _FilterThumb({
    required this.type,
    required this.sample,
    required this.selected,
    required this.onTap,
  });

  final PhotoFilterType type;
  final XFile? sample;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final List<double> matrix = buildMatrix(
      type,
      1,
      const PhotoAdjustments(),
    );
    final Widget base = sample != null
        ? PhotoImage(photo: sample!, width: 64, height: 64)
        : Container(
            width: 64,
            height: 64,
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
      label: '${type.label} filter',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.fast),
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: R.all(R.sm),
                border: Border.all(
                  color: selected ? AppColors.hotPink : AppColors.darkLine,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: R.all(R.xs + 2),
                child: isIdentityMatrix(matrix)
                    ? base
                    : ColorFiltered(
                        colorFilter: ColorFilter.matrix(matrix),
                        child: base,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 70,
              child: Text(
                type.label,
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
            color: selected ? AppColors.hotPink : AppColors.darkSurface,
            borderRadius: R.pillRadius,
            border: Border.all(
              color: selected ? AppColors.hotPink : AppColors.darkLine,
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
            color: selected ? AppColors.hotPink : AppColors.darkLine,
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
          color: selected ? AppColors.hotPink : AppColors.darkLine,
          width: selected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: S.sm,
          vertical: S.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.text_fields_rounded,
              color: placement.color,
              size: 18,
            ),
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
              color: selected ? AppColors.hotPink : AppColors.darkLine,
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
                ? AppColors.hotPink.withValues(alpha: 0.2)
                : AppColors.darkSurface,
            borderRadius: R.all(R.md),
            border: Border.all(
              color: selected ? AppColors.hotPink : AppColors.darkLine,
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: RetroSticker(type: type, size: 28),
          ),
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
                  color: AppColors.hotPink,
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
              Icon(icon, size: 16, color: onPressed != null ? fg : AppColors.darkMuted),
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
