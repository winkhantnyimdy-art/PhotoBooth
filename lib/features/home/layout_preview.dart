import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'layout_geometry.dart';
import 'layout_model.dart';

/// A miniature rendering of a [PhotoLayout] on a selectable card.
///
/// The thumbnail is drawn from [PhotoStripGeometry], the same source the
/// exported PNG uses, so the arrangement a user picks here is exactly the
/// arrangement they get. Nothing is stretched: the strip keeps its true aspect
/// ratio inside the available box.
class LayoutPreview extends StatelessWidget {
  const LayoutPreview({
    super.key,
    required this.layout,
    this.selected = false,
    this.onTap,
  });

  final PhotoLayout layout;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String badge = layout.badge ?? '';
    final String semanticsLabel = layout.badge == null
        ? '${layout.label} layout, ${layout.description}'
        : '${layout.label} layout, ${layout.description}, ${layout.badge}';

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.fast),
            curve: AppMotion.curve,
            padding: const EdgeInsets.symmetric(
              horizontal: S.sm,
              vertical: S.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: R.all(R.lg),
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.line,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : <BoxShadow>[
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.07),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _StripThumbnail(layout: layout, selected: selected),
                const SizedBox(height: S.sm + S.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        layout.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label.copyWith(
                          color: selected
                              ? AppColors.accentInk
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (layout.badge != null) ...<Widget>[
                      const SizedBox(width: S.xs + S.xs),
                      _Badge(
                        label: badge,
                        color: selected
                            ? AppColors.accent
                            : AppColors.accentSoft,
                        foreground: selected
                            ? AppColors.onAccent
                            : AppColors.accentInk,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  layout.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded pill used for the "Popular" marker.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.foreground,
  });

  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: R.all(R.xs)),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: foreground,
        ),
      ),
    );
  }
}

/// Draws the strip at its true aspect ratio using the shared geometry.
class _StripThumbnail extends StatelessWidget {
  const _StripThumbnail({required this.layout, required this.selected});

  final PhotoLayout layout;
  final bool selected;

  /// Fixed thumbnail height so every layout card reads at a consistent size
  /// while the strip itself keeps its real proportions inside that box.
  static const double _thumbHeight = 104;

  @override
  Widget build(BuildContext context) {
    final double aspect = PhotoStripGeometry.aspectRatio(layout);
    return SizedBox(
      height: _thumbHeight,
      child: Center(
        // The padding sits outside the AspectRatio so the painted strip keeps
        // the exported aspect ratio exactly; insetting it would skew the
        // thumbnail (worst for the short 2 CUT strip).
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: AspectRatio(
            aspectRatio: aspect,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: R.all(R.sm),
                border: Border.all(color: AppColors.line),
              ),
              child: CustomPaint(
                painter: _StripPainter(
                  layout: layout,
                  fill: selected ? AppColors.accent : AppColors.accentDeep,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the photo cells of a layout at the geometry's true proportions.
class _StripPainter extends CustomPainter {
  const _StripPainter({required this.layout, required this.fill});

  final PhotoLayout layout;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / PhotoStripGeometry.exportWidth;
    final Paint paint = Paint()..color = fill;

    for (int i = 0; i < layout.photoCount; i++) {
      final Rect cell = PhotoStripGeometry.cellRect(layout, i);
      final Rect scaled = Rect.fromLTWH(
        cell.left * scale,
        cell.top * scale,
        cell.width * scale,
        cell.height * scale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(scaled, const Radius.circular(1.5)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripPainter old) =>
      old.layout != layout || old.fill != fill;
}
