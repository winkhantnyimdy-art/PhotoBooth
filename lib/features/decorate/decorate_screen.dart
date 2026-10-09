import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/app_surface.dart';
import '../../shared/pressable.dart';
import '../export/export_screen.dart';
import '../home/layout_geometry.dart';
import '../home/layout_model.dart';
import 'decoration_model.dart';

/// Decoration screen for a completed PhotoBooth session.
///
/// Presents a live preview of the finished composition above compact controls
/// for frame, style, stickers and the date. The preview is laid out from
/// [PhotoStripGeometry] — the same geometry the exporter uses — including the
/// sticker coordinate mapping, so what is styled here is what gets rendered.
///
/// No new decoration capability is introduced: the same frames, styles, sticker
/// types and date toggle are offered as before.
class DecorateScreen extends StatefulWidget {
  const DecorateScreen({super.key, required this.layout, required this.photos});

  /// The layout that was used for this session.
  final PhotoLayout layout;

  /// Captured photos in order (first = shot 1, etc.).
  final List<XFile> photos;

  @override
  State<DecorateScreen> createState() => _DecorateScreenState();
}

class _DecorateScreenState extends State<DecorateScreen> {
  late DecorationState _decorationState;
  StickerType? _selectedStickerType;

  @override
  void initState() {
    super.initState();
    _decorationState = DecorationState(
      layout: widget.layout,
      background: BackgroundChoice.cream,
      style: DecorativeStyle.clean,
    );
  }

  /// Live composition preview, constrained to the exporter's true proportions.
  Widget _buildCompositionPreview() {
    final double stripAspect = PhotoStripGeometry.aspectRatio(widget.layout);
    return Center(
      child: AspectRatio(
        aspectRatio: stripAspect,
        child: _Composition(
          layout: widget.layout,
          photos: widget.photos,
          state: _decorationState,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Screen
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Decorate'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(S.md, S.xs, S.md, S.md),
                child: _buildCompositionPreview(),
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(R.lg),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x14302B30),
                      blurRadius: 26,
                      offset: Offset(0, -10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    S.md,
                    S.md,
                    S.md,
                    S.md + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildFrameSection(),
                      const SizedBox(height: S.md),
                      _buildStyleSection(),
                      const SizedBox(height: S.md),
                      _buildStickerSection(),
                      const SizedBox(height: S.md),
                      _buildDateSection(),
                      const SizedBox(height: S.md),
                      _buildDoneButton(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  Widget _buildFrameSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const SectionLabel('Frame'),
      const SizedBox(height: S.sm),
      Wrap(
        spacing: S.sm + S.xs,
        runSpacing: S.sm + S.xs,
        children: <Widget>[
          for (final BackgroundChoice choice in BackgroundChoice.values)
            _FrameSwatch(
              choice: choice,
              selected: _decorationState.background == choice,
              onTap: () => setState(() {
                _decorationState = _decorationState.copyWith(
                  background: choice,
                );
              }),
            ),
        ],
      ),
    ],
  );

  Widget _buildStyleSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const SectionLabel('Style'),
      const SizedBox(height: S.sm),
      Wrap(
        spacing: S.sm,
        runSpacing: S.sm,
        children: <Widget>[
          for (final DecorativeStyle style in DecorativeStyle.values)
            ChoiceChip(
              avatar: Icon(
                _styleIcon(style),
                size: 17,
                color: _decorationState.style == style
                    ? AppColors.onAccent
                    : AppColors.textSecondary,
              ),
              label: Text(style.label),
              selected: _decorationState.style == style,
              onSelected: (_) => setState(() {
                _decorationState = _decorationState.copyWith(style: style);
              }),
            ),
        ],
      ),
    ],
  );

  Widget _buildStickerSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const SectionLabel('Stickers'),
      const SizedBox(height: S.sm),
      Wrap(
        spacing: S.sm,
        runSpacing: S.sm,
        children: <Widget>[
          for (final StickerType type in StickerType.values)
            _StickerChip(
              type: type,
              selected: _selectedStickerType == type,
              onTap: () => setState(() {
                _selectedStickerType = _selectedStickerType == type
                    ? null
                    : type;
              }),
            ),
        ],
      ),
      if (_selectedStickerType != null) ...<Widget>[
        const SizedBox(height: S.sm + S.xs),
        PressableScale(
          child: FilledButton.icon(
            onPressed: _addSelectedSticker,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text('Add ${_selectedStickerType!.label}'),
          ),
        ),
      ],
      if (_decorationState.stickers.isNotEmpty) ...<Widget>[
        const SizedBox(height: S.sm + S.xs),
        Row(
          children: <Widget>[
            const Icon(
              Icons.auto_awesome_rounded,
              size: 15,
              color: AppColors.accentInk,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${_decorationState.stickers.length} '
                'sticker${_decorationState.stickers.length == 1 ? '' : 's'} '
                'added',
                style: AppText.caption,
              ),
            ),
            TextButton.icon(
              onPressed: _removeLastSticker,
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Remove last'),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _buildDateSection() => SoftPanel(
    padding: const EdgeInsets.fromLTRB(S.md, S.sm, S.sm, S.sm),
    child: Row(
      children: <Widget>[
        const Icon(
          Icons.calendar_today_rounded,
          size: 18,
          color: AppColors.accentInk,
        ),
        const SizedBox(width: S.sm + S.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Show the date', style: AppText.label),
              Text('Stamp today on the footer', style: AppText.caption),
            ],
          ),
        ),
        Switch(
          value: _decorationState.showDate,
          onChanged: (bool value) => setState(() {
            _decorationState = _decorationState.copyWith(showDate: value);
          }),
        ),
      ],
    ),
  );

  Widget _buildDoneButton(BuildContext context) {
    return PressableScale(
      child: FilledButton.icon(
        onPressed: () => _goToExport(context),
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: const Text('Preview & Export'),
      ),
    );
  }

  void _goToExport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExportScreen(
          layout: widget.layout,
          photos: widget.photos,
          decorationState: _decorationState,
        ),
      ),
    );
  }

  void _addSelectedSticker() {
    final StickerType? type = _selectedStickerType;
    if (type == null) return;
    setState(() {
      _decorationState = _decorationState.copyWith(
        stickers: <StickerPlacement>[
          ..._decorationState.stickers,
          StickerPlacement(type: type, x: 0.5, y: 0.5),
        ],
      );
      _selectedStickerType = null;
    });
  }

  void _removeLastSticker() {
    if (_decorationState.stickers.isEmpty) return;
    setState(() {
      _decorationState = _decorationState.copyWith(
        stickers: List<StickerPlacement>.from(_decorationState.stickers)
          ..removeLast(),
      );
    });
  }

  static IconData _styleIcon(DecorativeStyle style) {
    switch (style) {
      case DecorativeStyle.clean:
        return Icons.crop_square_rounded;
      case DecorativeStyle.hearts:
        return Icons.favorite_rounded;
      case DecorativeStyle.stars:
        return Icons.star_rounded;
      case DecorativeStyle.sparkle:
        return Icons.auto_awesome_rounded;
    }
  }
}

/// The composition: frame, photo grid, decorative overlay, stickers and the
/// branding strip, laid out from [PhotoStripGeometry].
class _Composition extends StatelessWidget {
  const _Composition({
    required this.layout,
    required this.photos,
    required this.state,
  });

  final PhotoLayout layout;
  final List<XFile> photos;
  final DecorationState state;

  @override
  Widget build(BuildContext context) {
    final bool onDark = state.background == BackgroundChoice.charcoal;

    return ClipRRect(
      borderRadius: R.all(R.sm),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final double height = constraints.maxHeight;

          // Uniform scale from export pixels to preview pixels, so every
          // padding, gutter and cell lands exactly where the exporter puts it.
          final double scale = width / PhotoStripGeometry.exportWidth;
          final double gridHeight =
              PhotoStripGeometry.contentHeight(layout) * scale;
          final double pad = PhotoStripGeometry.outerPadding * scale;
          final double gutter = PhotoStripGeometry.gutter * scale;
          final double stickerSize = PhotoStripGeometry.stickerSize * scale;

          return DecoratedBox(
            decoration: BoxDecoration(
              color: state.background.color,
              border: Border.all(
                color: onDark
                    ? AppColors.line
                    : state.background.color.withValues(alpha: 0.35),
                width: math.max(1.5, 3 * scale),
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: pad,
                  right: pad,
                  top: pad,
                  // The grid occupies the content area only. Without the footer
                  // term here the photos are centred over the branding strip
                  // and sit ~75 export pixels too low.
                  bottom: math.max(0, height - gridHeight + pad),
                  child: _PhotoGrid(
                    key: const ValueKey('composition-grid'),
                    layout: layout,
                    photos: photos,
                    gutter: gutter,
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
                // Stickers map onto the grid area only, exactly as the exporter
                // does, so preview and export agree. The exporter draws its
                // glyphs centred on that point at a fixed size in export
                // pixels, so the preview matches both.
                for (final StickerPlacement sticker in state.stickers)
                  Positioned(
                    left: sticker.x * width - (stickerSize / 2),
                    top: sticker.y * gridHeight - (stickerSize / 2),
                    child: Icon(
                      sticker.type.icon,
                      size: stickerSize,
                      color: onDark ? AppColors.onDark : AppColors.accentDeep,
                      semanticLabel: sticker.type.label,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: math.max(0, height - gridHeight),
                  child: _BrandingStrip(
                    key: const ValueKey('composition-footer'),
                    state: state,
                    onDark: onDark,
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

/// Photo grid drawn from the shared geometry.
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    super.key,
    required this.layout,
    required this.photos,
    required this.gutter,
  });

  final PhotoLayout layout;
  final List<XFile> photos;

  /// Gutter already scaled from export pixels to preview pixels.
  final double gutter;

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
                  child: Image.file(File(photos[i].path), fit: BoxFit.cover),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Tonal decorative overlay for the chosen style.
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

/// Repeating ornamental pattern, mirroring the exporter's overlay.
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

/// Branding footer inside the composition preview.
class _BrandingStrip extends StatelessWidget {
  const _BrandingStrip({super.key, required this.state, required this.onDark});

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'PHOTOBOOTH',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: foreground,
                ),
              ),
              if (state.showDate) ...<Widget>[
                const SizedBox(height: 1),
                Text(
                  formatExportDate(state.displayDate),
                  style: TextStyle(
                    fontSize: 8.5,
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

/// A single colour frame option.
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
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.fast),
            width: S.touchTarget,
            height: S.touchTarget,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: R.all(R.md),
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: choice.color,
                borderRadius: R.all(R.sm),
                border: Border.all(color: AppColors.line),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.accentInk,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon-only sticker picker with a comfortable touch target.
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
      // Suffixed because a style and a sticker can share a name
      // (e.g. "Sparkle"), which would otherwise be ambiguous when read aloud.
      label: '${type.label} sticker',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.fast),
            width: S.touchTarget,
            height: S.touchTarget,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : AppColors.surface,
              borderRadius: R.all(R.md),
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Icon(
              type.icon,
              size: 21,
              color: selected ? AppColors.onAccent : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
