import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/art/bubble_logo.dart';
import '../../core/art/checkerboard.dart';
import '../../core/art/retro_sticker.dart';
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

class DecorateScreen extends StatefulWidget {
  const DecorateScreen({super.key, required this.layout, required this.photos});

  final PhotoLayout layout;
  final List<XFile> photos;

  @override
  State<DecorateScreen> createState() => _DecorateScreenState();
}

class _DecorateScreenState extends State<DecorateScreen> {
  late DecorationState _decorationState;
  StickerType? _selectedStickerType;
  int _selectedTab = 2;

  @override
  void initState() {
    super.initState();
    _decorationState = DecorationState(
      layout: widget.layout,
      background: BackgroundChoice.cream,
      style: DecorativeStyle.clean,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildTopBar(),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(S.sm),
                      child: _buildCompositionPreview(),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          _buildTabBar(),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(S.sm),
                              child: _buildTabContent(),
                            ),
                          ),
                          _buildDoneButton(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const CheckerboardPattern(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
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
              child: Text('Decorate', style: AppText.title),
            ),
          ),
          PressableScale(
            child: OutlinedButton.icon(
              onPressed: _resetDecoration,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.popNavy,
                side: const BorderSide(color: AppColors.popNavy, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
                padding: const EdgeInsets.symmetric(horizontal: S.md),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildTabBar() {
    const List<String> tabs = <String>['Frames', 'Effects', 'Stickers', 'Date'];
    const List<IconData> icons = <IconData>[
      Icons.crop_square_rounded,
      Icons.auto_awesome_rounded,
      Icons.emoji_emotions_rounded,
      Icons.calendar_today_rounded,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(S.md, S.sm, S.md, 0),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = i),
                child: AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.fast),
                  padding: const EdgeInsets.symmetric(vertical: S.sm),
                  decoration: BoxDecoration(
                    color: _selectedTab == i
                        ? AppColors.hotPink
                        : Colors.transparent,
                    borderRadius: R.pillRadius,
                  ),
                  child: Column(
                    children: <Widget>[
                      Icon(
                        icons[i],
                        size: 18,
                        color: _selectedTab == i
                            ? AppColors.onAccent
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tabs[i],
                        style: AppText.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _selectedTab == i
                              ? AppColors.onAccent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildFramesTab();
      case 1:
        return _buildEffectsTab();
      case 2:
        return _buildStickersTab();
      case 3:
        return _buildDateTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFramesTab() {
    return Wrap(
      spacing: S.sm,
      runSpacing: S.sm,
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
    );
  }

  Widget _buildEffectsTab() {
    return Wrap(
      spacing: S.sm,
      runSpacing: S.sm,
      children: <Widget>[
        for (final DecorativeStyle style in DecorativeStyle.values)
          ChoiceChip(
            label: Text(style.label),
            selected: _decorationState.style == style,
            onSelected: (_) => setState(() {
              _decorationState = _decorationState.copyWith(style: style);
            }),
          ),
      ],
    );
  }

  Widget _buildStickersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
          const SizedBox(height: S.md),
          PressableScale(
            child: FilledButton.icon(
              onPressed: _addSelectedSticker,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text('Add ${_selectedStickerType!.label}'),
            ),
          ),
        ],
        if (_decorationState.stickers.isNotEmpty) ...<Widget>[
          const SizedBox(height: S.sm),
          Row(
            children: <Widget>[
              Text(
                '${_decorationState.stickers.length} sticker${_decorationState.stickers.length == 1 ? '' : 's'} added',
                style: AppText.caption,
              ),
              const Spacer(),
              TextButton(
                onPressed: _removeLastSticker,
                child: const Text('Remove last'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDateTab() {
    return Row(
      children: <Widget>[
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
    );
  }

  Widget _buildDoneButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.md, S.sm, S.md, S.md),
      child: PressableScale(
        child: FilledButton.icon(
          onPressed: () => _goToExport(context),
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          label: const Text('Finish & Save  →'),
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
          layout: widget.layout,
          photos: widget.photos,
          decorationState: _decorationState,
        ),
      ),
    );
  }

  void _resetDecoration() {
    setState(() {
      _decorationState = DecorationState(
        layout: widget.layout,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
      );
      _selectedStickerType = null;
    });
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
}

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
      borderRadius: R.all(R.lg),
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
            decoration: BoxDecoration(
              color: state.background.color,
              border: Border.all(
                color: onDark
                    ? AppColors.line
                    : AppColors.popPink,
                width: math.max(2, 4 * scale),
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: pad,
                  right: pad,
                  top: pad,
                  bottom: math.max(0, height - gridHeight + pad),
                  child: _PhotoGrid(
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
                for (final StickerPlacement sticker in state.stickers)
                  Positioned(
                    left: sticker.x * width - (stickerSize / 2),
                    top: sticker.y * gridHeight - (stickerSize / 2),
                    child: RetroSticker(
                      type: sticker.type,
                      size: stickerSize,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: math.max(0, height - gridHeight),
                  child: _BrandingStrip(
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

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.layout,
    required this.photos,
    required this.gutter,
  });

  final PhotoLayout layout;
  final List<XFile> photos;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 80,
              child: PhotoBoothBubbleLogo(width: 80),
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
              color: selected ? AppColors.hotPink : AppColors.line,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: choice.color,
              borderRadius: R.all(R.sm),
              border: Border.all(color: AppColors.line),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 18, color: AppColors.popInk)
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
            color: selected ? AppColors.hotPink.withValues(alpha: 0.15) : AppColors.surface,
            borderRadius: R.all(R.md),
            border: Border.all(
              color: selected ? AppColors.hotPink : AppColors.line,
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

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Material(
      color: enabled ? AppColors.surface : AppColors.surfaceMuted,
      shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? AppColors.popNavy : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
