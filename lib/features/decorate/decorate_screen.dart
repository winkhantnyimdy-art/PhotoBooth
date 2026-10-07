import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../export/export_screen.dart';
import '../home/layout_model.dart';
import 'decoration_model.dart';

import 'dart:math';

/// Functional decoration screen for a completed PhotoBooth session.
///
/// Shows a live preview of the finished photo strip composition with
/// controls to customize frame, style, stickers, and date display.
/// Navigation continues to ExportScreen for final rendering/share.
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

  /// Builds the live composition preview based on current decoration state.
  Widget _buildCompositionPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate composition dimensions
        final availableWidth = constraints.maxWidth;
        final availableHeight =
            constraints.maxHeight - S.lg; // Reserve space for branding
        final photoCount = widget.photos.length;
        final cols = widget.layout.cols;
        // rows is available for future use if needed

        // Calculate cell dimensions preserving aspect ratio
        return Stack(
          children: [
            // Background/frame
            Container(
              width: availableWidth,
              height: availableHeight,
              decoration: BoxDecoration(
                color: _decorationState.background.color,
                border: Border.all(
                  color:
                      _decorationState.background == BackgroundChoice.charcoal
                      ? AppColors.line
                      : _decorationState.background.color.withValues(
                          alpha: 0.3,
                        ),
                  width: 3,
                ),
                borderRadius: R.all(R.md),
              ),
            ),
            // Photos in grid
            Positioned.fill(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: S.sm,
                  crossAxisSpacing: S.sm,
                ),
                itemCount: photoCount,
                itemBuilder: (context, index) {
                  final file = File(widget.photos[index].path);
                  return ClipRRect(
                    borderRadius: R.all(R.sm),
                    child: Image.file(file, fit: BoxFit.cover),
                  );
                },
              ),
            ),
            // Decorative overlays based on style
            if (_decorationState.style != DecorativeStyle.clean)
              _buildStyleOverlay(availableWidth, availableHeight),
            // Stickers
            for (final sticker in _decorationState.stickers)
              _buildStickerWidget(sticker, availableWidth, availableHeight),
            // Branding area with optional date
            _buildBrandingArea(availableWidth, S.lg),
          ],
        );
      },
    );
  }

  /// Builds decorative overlay based on selected style.
  Widget _buildStyleOverlay(double width, double height) {
    final color = _decorationState.background == BackgroundChoice.charcoal
        ? Colors.white.withValues(alpha: 0.15)
        : AppColors.accentDeep.withValues(alpha: 0.1);

    switch (_decorationState.style) {
      case DecorativeStyle.hearts:
        return CustomPaint(
          size: Size(width, height),
          painter: _HeartPainter(color: color),
        );
      case DecorativeStyle.stars:
        return CustomPaint(
          size: Size(width, height),
          painter: _StarPainter(color: color),
        );
      case DecorativeStyle.sparkle:
        return CustomPaint(
          size: Size(width, height),
          painter: _SparklePainter(color: color),
        );
      case DecorativeStyle.clean:
        return const SizedBox.shrink();
    }
  }

  /// Builds a widget for a single sticker placement.
  Widget _buildStickerWidget(
    StickerPlacement sticker,
    double width,
    double height,
  ) {
    return Positioned(
      left: sticker.x * width,
      top: sticker.y * height,
      child: _buildStickerIcon(sticker.type),
    );
  }

  /// Returns the icon widget for a sticker type.
  Widget _buildStickerIcon(StickerType type) {
    return Icon(
      type.icon,
      color: _decorationState.background == BackgroundChoice.charcoal
          ? Colors.white
          : AppColors.accentDeep,
      size: 24,
      semanticLabel: type.label,
    );
  }

  /// Builds the branding area at the bottom with optional date.
  Widget _buildBrandingArea(double width, double height) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: height,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _decorationState.background == BackgroundChoice.charcoal
              ? Colors.black54
              : Colors.black38,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PHOTOBOOTH',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
              if (_decorationState.showDate)
                Text(
                  '${_decorationState.displayDate.year}-'
                  '${_decorationState.displayDate.month.toString().padLeft(2, '0')}-'
                  '${_decorationState.displayDate.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
            ],
          ),
        ),
      ),
    );
  }

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
          children: [
            // Composition preview (takes most space)
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(S.md),
                child: _buildCompositionPreview(),
              ),
            ),
            // Editor controls
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(S.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Frame/Background selector
                      _buildSectionTitle('Frame'),
                      Wrap(
                        spacing: S.xs,
                        runSpacing: S.xs,
                        children: BackgroundChoice.values
                            .map(
                              (choice) => ChoiceChip(
                                label: Text(choice.label),
                                selected: _decorationState.background == choice,
                                onSelected: (selected) {
                                  setState(() {
                                    _decorationState = _decorationState
                                        .copyWith(background: choice);
                                  });
                                },
                                selectedColor: AppColors.accent,
                                labelStyle: TextStyle(
                                  color: _decorationState.background == choice
                                      ? AppColors.onAccent
                                      : AppColors.textPrimary,
                                ),
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: S.sm,
                                  vertical: S.xs,
                                ),
                                side: BorderSide(color: AppColors.line),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: S.md),
                      // Decorative style selector
                      _buildSectionTitle('Style'),
                      Wrap(
                        spacing: S.xs,
                        runSpacing: S.xs,
                        children: DecorativeStyle.values
                            .map(
                              (style) => ChoiceChip(
                                label: Text(style.label),
                                selected: _decorationState.style == style,
                                onSelected: (selected) {
                                  setState(() {
                                    _decorationState = _decorationState
                                        .copyWith(style: style);
                                  });
                                },
                                selectedColor: AppColors.accent,
                                labelStyle: TextStyle(
                                  color: _decorationState.style == style
                                      ? AppColors.onAccent
                                      : AppColors.textPrimary,
                                ),
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: S.sm,
                                  vertical: S.xs,
                                ),
                                side: BorderSide(color: AppColors.line),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: S.md),
                      // Stickers section
                      _buildSectionTitle('Stickers'),
                      Wrap(
                        spacing: S.xs,
                        runSpacing: S.xs,
                        children: StickerType.values
                            .map(
                              (type) => ChoiceChip(
                                label: Icon(type.icon),
                                selected: _selectedStickerType == type,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedStickerType = selected
                                        ? type
                                        : null;
                                  });
                                },
                                selectedColor: AppColors.accent.withValues(
                                  alpha: 0.2,
                                ),
                                labelPadding: const EdgeInsets.all(S.xs),
                                side: BorderSide(color: AppColors.line),
                              ),
                            )
                            .toList(),
                      ),
                      // Add selected sticker button
                      if (_selectedStickerType != null)
                        Padding(
                          padding: const EdgeInsets.only(top: S.sm),
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                // Add sticker at center of composition
                                final centerPlacement = StickerPlacement(
                                  type: _selectedStickerType!,
                                  x: 0.5,
                                  y: 0.5,
                                );
                                _decorationState = _decorationState.copyWith(
                                  stickers: [
                                    ..._decorationState.stickers,
                                    centerPlacement,
                                  ],
                                );
                                _selectedStickerType = null;
                              });
                            },
                            child: Text('Add ${_selectedStickerType!.label}'),
                          ),
                        ),
                      // Sticker management (if any stickers exist)
                      if (_decorationState.stickers.isNotEmpty) ...[
                        const SizedBox(height: S.md),
                        _buildSectionTitle('Sticker Controls'),
                        Wrap(
                          spacing: S.xs,
                          runSpacing: S.xs,
                          children: [
                            ChoiceChip(
                              label: const Text('Select'),
                              selected: false,
                              onSelected: (_) {
                                // In a real app, this would enter selection mode
                                // For simplicity, we'll allow tapping stickers to select/reposition
                              },
                            ),
                            const SizedBox(width: S.xs),
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  if (_decorationState.stickers.isNotEmpty) {
                                    _decorationState = _decorationState
                                        .copyWith(
                                          stickers: List.from(
                                            _decorationState.stickers,
                                          )..removeLast(),
                                        );
                                  }
                                });
                              },
                              child: const Text('Remove Last'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: S.md),
                      // Date toggle
                      _buildSectionTitle('Options'),
                      Row(
                        children: [
                          const Text('Show date'),
                          const SizedBox(width: S.sm),
                          Switch(
                            value: _decorationState.showDate,
                            onChanged: (value) {
                              setState(() {
                                _decorationState = _decorationState.copyWith(
                                  showDate: value,
                                );
                              });
                            },
                            activeThumbColor: AppColors.accent,
                            activeTrackColor: AppColors.accent.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: S.md),
                      // Done button
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExportScreen(
                                layout: widget.layout,
                                photos: widget.photos,
                                decorationState: _decorationState,
                              ),
                            ),
                          );
                        },
                        child: const Text('Done'),
                      ),
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

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: S.xs),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

/// Custom painter for heart decorations.
class _HeartPainter extends CustomPainter {
  _HeartPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final heartSize = size.shortestSide * 0.15;
    final spacing = size.shortestSide * 0.25;

    // Place hearts in a subtle pattern
    for (double y = heartSize; y < size.height - heartSize; y += spacing) {
      for (double x = heartSize; x < size.width - heartSize; x += spacing) {
        final path = Path();
        // Simple heart shape
        path.moveTo(x, y + heartSize * 0.3);
        path.quadraticBezierTo(
          x - heartSize * 0.4,
          y - heartSize * 0.3,
          x,
          y + heartSize * 0.1,
        );
        path.quadraticBezierTo(
          x + heartSize * 0.4,
          y - heartSize * 0.3,
          x,
          y + heartSize * 0.3,
        );
        path.quadraticBezierTo(
          x - heartSize * 0.4,
          y + heartSize * 0.8,
          x,
          y + heartSize * 1.2,
        );
        path.quadraticBezierTo(
          x + heartSize * 0.4,
          y + heartSize * 0.8,
          x,
          y + heartSize * 0.3,
        );
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeartPainter old) => old.color != color;
}

/// Custom painter for star decorations.
class _StarPainter extends CustomPainter {
  _StarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final starSize = size.shortestSide * 0.1;
    final spacing = size.shortestSide * 0.3;

    // Place stars in a subtle pattern
    for (double y = starSize; y < size.height - starSize; y += spacing) {
      for (double x = starSize; x < size.width - starSize; x += spacing) {
        final path = Path();
        // Simple 5-point star
        final points = List.generate(5, (i) {
          final angle = i * 2 * 3.14159 / 5 - 3.14159 / 2;
          final radius = i.isEven ? starSize : starSize * 0.5;
          return Offset(x + radius * cos(angle), y + radius * sin(angle));
        });
        path.addPolygon(points, true);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.color != color;
}

/// Custom painter for sparkle decorations.
class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final sparkleSize = size.shortestSide * 0.08;
    final spacing = size.shortestSide * 0.4;

    // Place sparkles in a subtle pattern
    for (double y = sparkleSize; y < size.height - sparkleSize; y += spacing) {
      for (double x = sparkleSize; x < size.width - sparkleSize; x += spacing) {
        final path = Path();
        // Simple sparkle (cross + circle)
        path.addRect(
          Rect.fromCenter(
            center: Offset(x, y),
            width: sparkleSize * 0.2,
            height: sparkleSize * 1.2,
          ),
        );
        path.addRect(
          Rect.fromCenter(
            center: Offset(x, y),
            width: sparkleSize * 1.2,
            height: sparkleSize * 0.2,
          ),
        );
        path.addOval(
          Rect.fromCenter(
            center: Offset(x, y),
            width: sparkleSize,
            height: sparkleSize,
          ),
        );
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.color != color;
}
