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

/// A full-bleed, orientation-correct camera viewfinder.
///
/// ## Orientation
///
/// Rotation is owned by exactly one layer. On Android the `camera` plugin's
/// `buildPreview()` already returns an upright feed (CameraX
/// `setTargetRotation` + `RotatedPreviewDelegate`), so this widget applies **no**
/// rotation of its own - doing so rotated the whole viewfinder 90 degrees
/// sideways. See [PreviewOrientation].
///
/// ## Framing
///
/// The feed is cover-fitted so it always fills its box with no letterbox bars.
/// The caller sizes that box to the exported photo-cell aspect, which means
/// **what the user frames is exactly what is saved**: the viewfinder no longer
/// draws a smaller crop rectangle inside a larger preview, so there is no
/// misleading dead area and no overflow beyond the captured region.
///
/// Mirroring still happens here, because it is a widget-only concern that
/// `takePicture()` cannot express. It is keyed off the same preference that
/// decides the stored bytes, so preview and capture never disagree.
class PhotoViewfinder extends StatelessWidget {
  const PhotoViewfinder({
    super.key,
    required this.controller,
    this.shootInPortrait = true,
    this.borderRadius = BorderRadius.zero,
    this.overlay,
    this.outputAspect = kDefaultCaptureAspect,
    this.mirrorSelfies = true,
    this.platform = TargetPlatform.android,
  });

  final CameraController controller;

  /// Whether the user is holding the phone upright.
  final bool shootInPortrait;

  final BorderRadius borderRadius;

  /// Optional guides drawn on top of the feed. The default camera passes
  /// nothing: the box is already the crop, so a guide would be noise.
  final Widget? overlay;

  /// width / height of the region that becomes one photo cell. Kept so callers
  /// can reason about framing and tests can assert it; the feed is fitted to
  /// whatever box it is given.
  final double outputAspect;

  /// The "Mirror selfies" preference, which decides preview orientation so it
  /// matches the saved photo.
  final bool mirrorSelfies;

  /// Which platform's preview contract to honour. Defaults to the real one so
  /// tests can exercise both without a device.
  final TargetPlatform platform;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: AppColors.previewBackdrop);
    }

    final Size? streamSize = controller.value.previewSize;

    // Only the platform that does NOT rotate gets a correction from the app.
    final int quarterTurns = PreviewOrientation.appQuarterTurns(
      platform: platform,
      streamSize: streamSize,
      shootInPortrait: shootInPortrait,
    );

    // The aspect of the frame as presented, which is the transpose of the raw
    // buffer on Android because the platform already turned it upright.
    final double uprightAspect = PreviewOrientation.presentedAspect(
      streamSize: streamSize,
      shootInPortrait: shootInPortrait,
    );

    final bool mirrored = SelfieMirroring.shouldMirrorPreview(
      direction: controller.description.lensDirection,
      mirrorSelfies: mirrorSelfies,
    );

    Widget feed = controller.buildPreview();

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
        final Size viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (viewport.width <= 0 || viewport.height <= 0) {
          return const SizedBox.shrink();
        }

        // Cover the box: at least as large on both axes, exact on one, so the
        // overflow is cropped and never letterboxed.
        final Size drawn = CameraGeometry.coverSize(
          viewport: viewport,
          sourceAspect: uprightAspect,
        );

        // A cover fit overflows on exactly one axis and the overflow is
        // centred, so shifting by half of it crops equally from both sides -
        // the same centre crop the renderer performs on the saved photo.
        final double overflowX = math.max(
          0.0,
          (drawn.width - viewport.width) / 2,
        );
        final double overflowY = math.max(
          0.0,
          (drawn.height - viewport.height) / 2,
        );

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            Positioned(
              left: overflowX * -1,
              top: overflowY * -1,
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
      Path()
        ..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(12))),
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
