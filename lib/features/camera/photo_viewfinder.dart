import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'camera_geometry.dart';

/// A full-bleed, orientation-independent camera viewfinder.
///
/// ## What it fixes
///
/// The stock `CameraPreview` letterboxes: it derives its box from the *device*
/// orientation, which disagrees with the stream's own dimensions on iOS
/// Safari. The result is a short wide band floating in a tall black viewport.
///
/// This widget instead:
/// 1. normalizes the stream to an upright aspect using [CameraGeometry], which
///    only looks at the frame's real dimensions;
/// 2. draws it with `FittedBox(fit: BoxFit.cover)` so it always fills the whole
///    viewport - the overflow is cropped, never letterboxed;
/// 3. rotates to upright and mirrors the front camera consistently, so what
///    you see is what the exported photo contains.
///
/// The underlying preview surface is produced by the plugin
/// ([CameraController.buildPreview]); this widget only controls how it is
/// transformed, so it behaves identically on Android, iOS and the web.
class PhotoViewfinder extends StatelessWidget {
  const PhotoViewfinder({
    super.key,
    required this.controller,
    this.shootInPortrait = true,
    this.borderRadius = BorderRadius.zero,
    this.overlay,
  });

  final CameraController controller;

  /// Whether the user is holding the phone upright.
  final bool shootInPortrait;

  final BorderRadius borderRadius;

  /// Optional guides drawn on top of the feed (crop windows, rule of thirds).
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: AppColors.previewBackdrop);
    }

    final Size? streamSize = controller.value.previewSize;
    final int quarterTurns = CameraGeometry.uprightQuarterTurns(
      streamSize: streamSize,
      shootInPortrait: shootInPortrait,
    );
    final double uprightAspect = CameraGeometry.uprightAspect(
      streamSize: streamSize,
      shootInPortrait: shootInPortrait,
    );
    final bool mirrored = controller.description.lensDirection ==
        CameraLensDirection.front;

    Widget feed = controller.buildPreview();

    // Front cameras read as a mirror to the user; back cameras must not be
    // flipped. Applied here (and not per-capture) so the live preview and the
    // saved photo agree. Transform does not affect layout.
    if (mirrored) {
      feed = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: feed,
      );
    }

    if (quarterTurns != 0) {
      feed = RotatedBox(quarterTurns: quarterTurns, child: feed);
    }

    // Size the feed explicitly instead of letting FittedBox measure it
    // unconstrained. `buildPreview()` may report no intrinsic size (and in
    // tests never does), and an unconstrained measure collapses to zero,
    // which is how a blank viewfinder happens.
    //
    // `coverSize` returns a box at least as large as the viewport on both axes,
    // so the feed always covers the frame and the overflow is cropped.
    Widget scaled = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size viewport = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final Size drawn = CameraGeometry.coverSize(
          viewport: viewport,
          sourceAspect: uprightAspect,
        );
        return OverflowBox(
          alignment: Alignment.center,
          minWidth: drawn.width,
          maxWidth: drawn.width,
          minHeight: drawn.height,
          maxHeight: drawn.height,
          child: SizedBox(
            key: const ValueKey('photobooth-feed-box'),
            width: drawn.width,
            height: drawn.height,
            child: feed,
          ),
        );
      },
    );

    // FittedBox inside an unbounded-ish box can overflow; clip to the viewport so
    // no part of the stream spills under neighbouring chrome.
    scaled = ClipRect(child: scaled);

    if (overlay != null) {
      scaled = Stack(fit: StackFit.expand, children: <Widget>[scaled, overlay!]);
    }

    if (borderRadius == BorderRadius.zero) return scaled;
    return ClipRRect(borderRadius: borderRadius, child: scaled);
  }
}

/// Crop guides that show exactly which part of the live feed will survive into
/// the exported photo.
///
/// Uses [CameraGeometry.cropWindow], the same maths the strip renderer uses to
/// crop, so the guide is not decorative - it is a true preview of the crop.
class ViewfinderCropGuide extends StatelessWidget {
  const ViewfinderCropGuide({
    super.key,
    required this.outputAspect,
    this.showThirds = true,
    this.color = Colors.white,
  });

  /// width / height of one exported photo cell.
  final double outputAspect;
  final bool showThirds;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final Rect window = CameraGeometry.cropWindow(
          viewport: viewport,
          outputAspect: outputAspect,
        );
        return IgnorePointer(
          child: CustomPaint(
            painter: _CropGuidePainter(
              window: window,
              showThirds: showThirds,
              color: color,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _CropGuidePainter extends CustomPainter {
  const _CropGuidePainter({
    required this.window,
    required this.showThirds,
    required this.color,
  });

  final Rect window;
  final bool showThirds;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (window.width <= 0 || window.height <= 0) return;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: 0.85);

    // Shade everything outside the crop so the kept area reads as "in focus".
    final Rect full = Offset.zero & size;
    final Path outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(full),
      Path()..addRRect(
        RRect.fromRectAndRadius(window, const Radius.circular(12)),
      ),
    );
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: 0.34),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(window, const Radius.circular(12)),
      paint,
    );

    if (!showThirds) return;
    final Paint thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.35);
    for (int i = 1; i < 3; i++) {
      final double dx = window.left + (window.width * i / 3);
      final double dy = window.top + (window.height * i / 3);
      canvas.drawLine(Offset(dx, window.top), Offset(dx, window.bottom), thin);
      canvas.drawLine(Offset(window.left, dy), Offset(window.right, dy), thin);
    }
  }

  @override
  bool shouldRepaint(covariant _CropGuidePainter old) =>
      old.window != window ||
      old.showThirds != showThirds ||
      old.color != color;
}