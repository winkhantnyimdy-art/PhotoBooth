import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'camera_geometry.dart';
import 'selfie_mirroring.dart';

/// Shape of one exported photo cell, used when the caller does not say.
///
/// Matches `PhotoStripGeometry.cellAspect`, i.e. 3:4 portrait.
const double kDefaultCaptureAspect = 3.0 / 4.0;

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
/// 2. fits that upright stream so it **covers the crop window** - the region the
///    exporter will actually keep - rather than covering the whole viewport;
/// 3. mirrors exactly when the stored photo will be mirrored, so the preview and
///    the capture agree.
///
/// ## Why the feed is fitted to the crop window
///
/// Fitting the stream to the entire viewport showed the user far more than
/// survives the export. On a 393x852 viewport the 3:4 crop window is only
/// 393x524, so roughly 40% of the height the user was framing against was
/// cropped away after the fact - which reads as "the framing does not match".
/// Fitting to the window means the preview is a true preview of the capture.
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
    this.outputAspect = kDefaultCaptureAspect,
    this.mirrorSelfies = true,
  });

  final CameraController controller;

  /// Whether the user is holding the phone upright.
  final bool shootInPortrait;

  final BorderRadius borderRadius;

  /// Optional guides drawn on top of the feed (crop windows, rule of thirds).
  final Widget? overlay;

  /// width / height of the region that becomes one photo cell.
  final double outputAspect;

  /// The "Mirror selfies" preference, which decides preview orientation so it
  /// matches the saved photo.
  final bool mirrorSelfies;

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
    final bool mirrored = SelfieMirroring.shouldMirrorPreview(
      direction: controller.description.lensDirection,
      mirrorSelfies: mirrorSelfies,
    );

    Widget feed = controller.buildPreview();

    // Orientation is decided in exactly one place, [SelfieMirroring], from the
    // same preference that decides the saved bytes. A widget-level transform
    // cannot influence `takePicture()`, which is why this used to disagree
    // with the capture on iOS Safari.
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

    // Size the feed explicitly instead of letting it measure itself
    // unconstrained. `buildPreview()` may report no intrinsic size (and in
    // tests never does), and an unconstrained measure collapses to zero, which
    // is how a blank viewfinder happens.
    Widget scaled = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size viewport = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        // The region the exporter keeps.
        final Rect window = CameraGeometry.cropWindow(
          viewport: viewport,
          outputAspect: outputAspect,
        );

        // Fill that window by covering it with the upright stream. `coverSize`
        // is at least as large as the window on both axes, so the window is
        // always full - never letterboxed, never a partial image.
        final Size drawn = CameraGeometry.coverSize(
          viewport: window.size,
          sourceAspect: uprightAspect,
        );

        // A cover fit overflows on exactly one axis and the overflow is
        // centred, so shifting by half of it puts the window over the centre of
        // the feed - exactly the centre crop the renderer performs.
        final double overflowX = math.max(0.0, (drawn.width - window.width) / 2);
        final double overflowY = math.max(0.0, (drawn.height - window.height) / 2);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            Positioned(
              left: window.left - overflowX,
              top: window.top - overflowY,
              width: drawn.width,
              height: drawn.height,
              child: SizedBox(
                key: const ValueKey('photobooth-feed-box'),
                width: drawn.width,
                height: drawn.height,
                child: feed,
              ),
            ),
            if (overlay != null) Positioned.fill(child: overlay!),
          ],
        );
      },
    );

    // Clip so no part of the stream spills under neighbouring chrome.
    scaled = ClipRect(child: scaled);

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