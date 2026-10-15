import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/features/camera/camera_geometry.dart';
import 'package:photo_booth/features/camera/photo_viewfinder.dart';
import 'package:photo_booth/features/home/layout_geometry.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// Geometry constants used by the tests.
const Size _landscapeStream = Size(1920, 1080); // desktop / Android native
const Size _portraitStream = Size(1080, 1920); // iOS Safari reports this
const Size _squareStream = Size(1440, 1440);
const Size _phoneViewport = Size(390, 600);

void main() {
  group('CameraGeometry - stream normalization', () {
    test('falls back to a portrait default when the size is unusable', () {
      expect(CameraGeometry.streamAspect(null), CameraGeometry.defaultStreamAspect);
      expect(CameraGeometry.normalizeAspect(0, 0), CameraGeometry.defaultStreamAspect);
      expect(
        CameraGeometry.normalizeAspect(double.nan, 100),
        CameraGeometry.defaultStreamAspect,
      );
      expect(CameraGeometry.normalizeAspect(-5, 100), CameraGeometry.defaultStreamAspect);
    });

    test('a landscape-native frame is recognized as rotated for portrait use', () {
      expect(
        CameraGeometry.streamIsRotated(
          streamSize: _landscapeStream,
          shootInPortrait: true,
        ),
        isTrue,
      );
      expect(
        CameraGeometry.uprightQuarterTurns(
          streamSize: _landscapeStream,
          shootInPortrait: true,
        ),
        1,
      );
      // Upright aspect is the reciprocal of the stored one.
      expect(
        CameraGeometry.uprightAspect(
          streamSize: _landscapeStream,
          shootInPortrait: true,
        ),
        closeTo(1080 / 1920, 1e-9),
      );
    });

    test('a portrait-native frame needs no rotation for portrait use', () {
      // This is the iOS Safari case that produced the letterboxed band.
      expect(
        CameraGeometry.streamIsRotated(
          streamSize: _portraitStream,
          shootInPortrait: true,
        ),
        isFalse,
      );
      expect(
        CameraGeometry.uprightQuarterTurns(
          streamSize: _portraitStream,
          shootInPortrait: true,
        ),
        0,
      );
      expect(
        CameraGeometry.uprightAspect(
          streamSize: _portraitStream,
          shootInPortrait: true,
        ),
        closeTo(1080 / 1920, 1e-9),
      );
    });

    test('upright aspect is identical for landscape- and portrait-native storage', () {
      // The whole point: the viewfinder must not care how the platform labels
      // the frame. Both must resolve to the same portrait aspect.
      final double fromLandscape = CameraGeometry.uprightAspect(
        streamSize: _landscapeStream,
        shootInPortrait: true,
      );
      final double fromPortrait = CameraGeometry.uprightAspect(
        streamSize: _portraitStream,
        shootInPortrait: true,
      );
      expect(fromLandscape, closeTo(fromPortrait, 1e-9));
    });

    test('a square stream keeps its aspect and needs no rotation', () {
      expect(
        CameraGeometry.uprightQuarterTurns(
          streamSize: _squareStream,
          shootInPortrait: true,
        ),
        0,
      );
      expect(
        CameraGeometry.uprightAspect(
          streamSize: _squareStream,
          shootInPortrait: true,
        ),
        closeTo(1.0, 1e-9),
      );
    });

    test('landscape shooting from portrait-native storage rotates the other way', () {
      expect(
        CameraGeometry.uprightQuarterTurns(
          streamSize: _portraitStream,
          shootInPortrait: false,
        ),
        3,
      );
    });
  });

  group('CameraGeometry - full-bleed cover fitting', () {
    test('cover size is at least the viewport on both axes, flush on one', () {
      const List<double> aspects = <double>[
        0.5625, // 9:16 portrait
        1.7778, // 16:9 landscape
        1.0, // square
        0.75, // 3:4 portrait
        2.4, // ultra-wide
      ];
      for (final double aspect in aspects) {
        for (final Size viewport in <Size>[
          _phoneViewport,
          const Size(320, 480),
          const Size(430, 932),
        ]) {
          final Size drawn = CameraGeometry.coverSize(
            viewport: viewport,
            sourceAspect: aspect,
          );
          expect(
            drawn.width,
            greaterThanOrEqualTo(viewport.width - 1e-6),
            reason: 'cover must span the width for aspect $aspect',
          );
          expect(
            drawn.height,
            greaterThanOrEqualTo(viewport.height - 1e-6),
            reason: 'cover must span the height for aspect $aspect',
          );
          final bool flushW = (drawn.width - viewport.width).abs() < 1e-6;
          final bool flushH = (drawn.height - viewport.height).abs() < 1e-6;
          expect(
            flushW || flushH,
            isTrue,
            reason: 'cover must be flush on exactly one axis for aspect $aspect',
          );
          // Aspect ratio is preserved: cover never stretches.
          expect(drawn.width / drawn.height, closeTo(aspect, 1e-9));
        }
      }
    });

    test('isFullBleed is true for every real camera aspect on a phone viewport', () {
      // The direct regression guard for the iPhone 16e report: a portrait feed
      // must have NO letterbox bars on a portrait viewport.
      for (final Size stream in <Size>[_landscapeStream, _portraitStream, _squareStream]) {
        expect(
          CameraGeometry.isFullBleed(
            viewport: _phoneViewport,
            uprightAspectRatio: CameraGeometry.uprightAspect(
              streamSize: stream,
              shootInPortrait: true,
            ),
          ),
          isTrue,
          reason: 'stream $stream must render full-bleed',
        );
      }
    });

    test('previewScale is never below 1 for a full-bleed fit', () {
      for (final Size stream in <Size>[_landscapeStream, _portraitStream]) {
        final double scale = CameraGeometry.previewScale(
          viewport: _phoneViewport,
          uprightAspectRatio: CameraGeometry.uprightAspect(
            streamSize: stream,
            shootInPortrait: true,
          ),
        );
        expect(scale, greaterThanOrEqualTo(1.0));
      }
    });
  });

  group('CameraGeometry - crop window', () {
    test('a landscape viewport crops the sides for a portrait cell', () {
      final Rect window = CameraGeometry.cropWindow(
        viewport: const Size(400, 300),
        outputAspect: 3 / 4,
      );
      expect(window.height, closeTo(300, 1e-9));
      expect(window.width, closeTo(300 * 3 / 4, 1e-9));
      expect(window.center.dx, closeTo(200, 1e-9));
    });

    test('a portrait viewport crops the top and bottom for a square cell', () {
      final Rect window = CameraGeometry.cropWindow(
        viewport: const Size(390, 700),
        outputAspect: 1.0,
      );
      expect(window.width, closeTo(390, 1e-9));
      expect(window.height, closeTo(390, 1e-9));
      expect(window.center.dy, closeTo(350, 1e-9));
    });

    test('the crop window always keeps the requested aspect', () {
      for (final Size viewport in <Size>[
        const Size(320, 480),
        _phoneViewport,
        const Size(430, 932),
      ]) {
        for (final double aspect in <double>[3 / 4, 1.0, 16 / 9]) {
          final Rect w = CameraGeometry.cropWindow(
            viewport: viewport,
            outputAspect: aspect,
          );
          expect(w.width / w.height, closeTo(aspect, 1e-9));
        }
      }
    });
  });

  group('CameraGeometry - camera to export crop alignment', () {
    test('the mapped source rect stays inside the captured frame', () {
      for (final Size viewport in <Size>[
        const Size(320, 480),
        _phoneViewport,
        const Size(430, 932),
      ]) {
        for (final Size source in <Size>[
          const Size(1920, 1080),
          const Size(1080, 1920),
          const Size(1440, 1440),
        ]) {
          final Rect window = CameraGeometry.cropWindow(
            viewport: viewport,
            outputAspect: 3 / 4,
          );
          final Rect src = CameraGeometry.sourceRectForCrop(
            viewport: viewport,
            sourceSize: source,
            cropWindow: window,
          );
          expect(src.left, greaterThanOrEqualTo(0));
          expect(src.top, greaterThanOrEqualTo(0));
          expect(src.right, lessThanOrEqualTo(source.width + 1e-6));
          expect(src.bottom, lessThanOrEqualTo(source.height + 1e-6));
          expect(src.width, greaterThan(0));
          expect(src.height, greaterThan(0));
        }
      }
    });

    test('the mapped source rect keeps the output cell aspect', () {
      // This is the alignment guarantee: the pixels the viewfinder framed are
      // the pixels the renderer crops, so neither is stretched.
      final Rect window = CameraGeometry.cropWindow(
        viewport: _phoneViewport,
        outputAspect: PhotoStripGeometry.cellAspect(PhotoLayout.korean4),
      );
      final Rect src = CameraGeometry.sourceRectForCrop(
        viewport: _phoneViewport,
        sourceSize: const Size(1920, 1080),
        cropWindow: window,
      );
      expect(
        src.width / src.height,
        closeTo(PhotoStripGeometry.cellAspect(PhotoLayout.korean4), 0.01),
      );
    });

    test('normalized source rect is centred', () {
      final Rect n = CameraGeometry.normalizedSourceRect(
        viewport: _phoneViewport,
        sourceSize: const Size(1920, 1080),
        cropWindow: CameraGeometry.cropWindow(
          viewport: _phoneViewport,
          outputAspect: 3 / 4,
        ),
      );
      expect(n.center.dx, closeTo(0.5, 1e-6));
      expect(n.center.dy, closeTo(0.5, 1e-6));
      expect(n.left, greaterThanOrEqualTo(0));
      expect(n.right, lessThanOrEqualTo(1));
    });

    test('coverRect preserves aspect by cropping, never by stretching', () {
      for (final Size source in <Size>[
        const Size(1920, 1080),
        const Size(1080, 1920),
        const Size(1440, 1440),
      ]) {
        for (final Size target in <Size>[
          const Size(576, 768),
          const Size(300, 300),
          const Size(1168, 576),
        ]) {
          final Rect dest = CameraGeometry.coverRect(
            source: source,
            target: target,
          );
          // The destination keeps the SOURCE aspect (it overflows the target on
          // one axis) and is at least as large as the target on both.
          expect(dest.width / dest.height, closeTo(source.width / source.height, 1e-9));
          expect(dest.width, greaterThanOrEqualTo(target.width - 1e-6));
          expect(dest.height, greaterThanOrEqualTo(target.height - 1e-6));
          // The region handed to drawImageRect is drawn into `target`, so it
          // must have the TARGET's shape. This used to assert the *source*
          // aspect instead, which a function returning the entire source image
          // satisfies trivially - that is how the squash bug survived: every
          // captured photo was being stretched into the 3:4 export cell.
          final Rect src = CameraGeometry.sourceRectForCover(
            source: source,
            target: target,
          );
          expect(
            src.width / src.height,
            closeTo(target.width / target.height, 0.01),
            reason:
                'cropping a $source into $target must fill the cell exactly; a '
                'different ratio here means drawImageRect would stretch it',
          );
          expect(src.width, lessThanOrEqualTo(source.width + 1e-6));
          expect(src.height, lessThanOrEqualTo(source.height + 1e-6));

          // A cover crop really does crop when the aspects differ, and does it
          // evenly - which is the centre crop the viewfinder frames.
          final bool sameAspect =
              (source.width / source.height - target.width / target.height).abs() <
                  0.001;
          if (!sameAspect) {
            expect(
              src.width < source.width - 1e-6 ||
                  src.height < source.height - 1e-6,
              isTrue,
              reason: 'a mismatched cover fit must discard part of the source',
            );
            expect(src.left, closeTo(source.width - src.right, 0.5));
            expect(src.top, closeTo(source.height - src.bottom, 0.5));
          }
        }
      }
    });
  });

  group('PhotoLayout', () {
    test('the default is the Korean 4-cut', () {
      expect(kDefaultPhotoLayout, PhotoLayout.korean4);
    });

    test('the Korean 4-cut and the 2x2 grid both hold four photos', () {
      expect(PhotoLayout.korean4.photoCount, 4);
      expect(PhotoLayout.grid4.photoCount, 4);
      expect(PhotoLayout.korean4.cols * PhotoLayout.korean4.rows, 4);
      expect(PhotoLayout.grid4.cols * PhotoLayout.grid4.rows, 4);
    });

    test('two-photo layouts exist and stack vertically', () {
      expect(PhotoLayout.pair2.photoCount, 2);
      expect(PhotoLayout.pair2.cols, 1);
      expect(PhotoLayout.pair2.rows, 2);
    });

    test('every layout has 2x2 and 2x4 compositions available', () {
      final Set<int> counts = PhotoLayout.values
          .map((PhotoLayout l) => l.photoCount)
          .toSet();
      expect(counts, containsAll(<int>[2, 3, 4, 6]));
    });

    test('cell aspect is portrait for every layout', () {
      for (final PhotoLayout layout in PhotoLayout.values) {
        expect(layout.cellAspect, lessThan(1.0), reason: layout.label);
        expect(layout.cellAspect, closeTo(3 / 4, 1e-9));
      }
    });

    test('fitForPhotos keeps every captured photo when switching layout', () {
      // The largest layout that still fits the photos already taken.
      expect(PhotoLayout.fitForPhotos(0), isNull);
      expect(PhotoLayout.fitForPhotos(2), PhotoLayout.pair2);
      expect(PhotoLayout.fitForPhotos(3)?.photoCount, 3);
      expect(PhotoLayout.fitForPhotos(4)?.photoCount, 4);
      expect(PhotoLayout.fitForPhotos(6), PhotoLayout.cut6);

      // Every candidate must be able to hold what we already have.
      for (final int count in <int>[2, 3, 4, 6]) {
        expect(
          PhotoLayout.fitForPhotos(count)!.photoCount,
          greaterThanOrEqualTo(count),
          reason: 'switching layout must never drop a captured photo ($count)',
        );
      }
    });

    test('cell rects tile without overlap for every layout', () {
      for (final PhotoLayout layout in PhotoLayout.values) {
        final List<Rect> cells = <Rect>[
          for (int i = 0; i < layout.photoCount; i++)
            PhotoStripGeometry.cellRect(layout, i),
        ];
        for (int i = 0; i < cells.length; i++) {
          for (int j = i + 1; j < cells.length; j++) {
            expect(cells[i].overlaps(cells[j]), isFalse);
          }
        }
        // Every cell shares the layout's cell aspect.
        for (final Rect c in cells) {
          expect(
            c.width / c.height,
            closeTo(PhotoStripGeometry.cellAspect(layout), 1e-6),
          );
        }
      }
    });
  });

  group('PhotoViewfinder', () {
    CameraController controllerWith(Size? stream, CameraLensDirection lens) {
      return _StubCameraController(
        description: CameraDescription(
          name: 'stub',
          lensDirection: lens,
          sensorOrientation: 0,
        ),
        streamSize: stream,
      );
    }

    Widget host(CameraController controller, Size size) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: PhotoViewfinder(controller: controller),
        ),
      ),
    );

    testWidgets('a portrait stream fills a portrait viewport with no bars', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(controllerWith(_portraitStream, CameraLensDirection.front), _phoneViewport),
      );
      expect(tester.getSize(find.byType(PhotoViewfinder)), _phoneViewport);

      // The feed box is the cover-fitted size: at least the viewport on both
      // axes. Anything smaller would render letterbox bars, which is the defect
      // reported on the iPhone 16e.
      final Size feedBox = tester.getSize(
        find.byKey(const ValueKey('photobooth-feed-box')),
      );
      expect(feedBox.width, greaterThanOrEqualTo(_phoneViewport.width - 0.5));
      expect(feedBox.height, greaterThanOrEqualTo(_phoneViewport.height - 0.5));
      expect(
        feedBox,
        CameraGeometry.coverSize(
          viewport: _phoneViewport,
          sourceAspect: 1080 / 1920,
        ),
      );
    });

    testWidgets('a landscape stream is presented upright with no app rotation', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(controllerWith(_landscapeStream, CameraLensDirection.back), _phoneViewport),
      );

      // Android's camera plugin already returns an upright feed (CameraX
      // setTargetRotation + RotatedPreviewDelegate). Adding our own quarter
      // turn on top rotated the whole viewfinder 90 degrees sideways, so the
      // app must apply NO rotation of its own here.
      expect(find.byType(RotatedBox), findsNothing);

      final Size feedBox = tester.getSize(
        find.byKey(const ValueKey('photobooth-feed-box')),
      );
      expect(feedBox.width, greaterThanOrEqualTo(_phoneViewport.width - 0.5));
      expect(feedBox.height, greaterThanOrEqualTo(_phoneViewport.height - 0.5));
      expect(
        feedBox.width / feedBox.height,
        closeTo(1080 / 1920, 0.01),
        reason: 'the upright portrait frame must fill the viewfinder',
      );
    });

    testWidgets('a non-rotating platform still gets the legacy correction', (
      tester,
    ) async {
      // Android-only in production, but the fallback must stay correct rather
      // than silently regressing.
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: _phoneViewport.width,
              height: _phoneViewport.height,
              child: PhotoViewfinder(
                controller: controllerWith(
                  _landscapeStream,
                  CameraLensDirection.back,
                ),
                platform: TargetPlatform.iOS,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(RotatedBox), findsOneWidget);
    });

    testWidgets('a front camera is mirrored and a back camera is not', (
      tester,
    ) async {
      Iterable<double> horizontalScales() => tester
          .widgetList<Transform>(find.byType(Transform))
          .map((Transform t) => t.transform.storage[0]);

      await tester.pumpWidget(
        host(controllerWith(_portraitStream, CameraLensDirection.front), _phoneViewport),
      );
      expect(
        horizontalScales(),
        contains(-1.0),
        reason: 'a front camera must read as a mirror',
      );

      await tester.pumpWidget(
        host(controllerWith(_portraitStream, CameraLensDirection.back), _phoneViewport),
      );
      expect(
        horizontalScales().where((double s) => s == -1.0),
        isEmpty,
        reason: 'a back camera must never be flipped',
      );
    });

    testWidgets('an uninitialised controller paints a dark backdrop, not white', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(_UninitialisedCameraController(), _phoneViewport),
      );
      expect(find.byType(PhotoViewfinder), findsOneWidget);
      expect(
        find.byType(_StubPreviewSurface),
        findsNothing,
        reason: 'a controller with no frames must not paint a feed',
      );
    });

    testWidgets('the crop guide reports the exported cell aspect', (tester) async {
      final double cellAspect = PhotoStripGeometry.cellAspect(PhotoLayout.korean4);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: _phoneViewport.width,
              height: _phoneViewport.height,
              child: PhotoViewfinder(
                controller: controllerWith(
                  _portraitStream,
                  CameraLensDirection.front,
                ),
                overlay: ViewfinderCropGuide(outputAspect: cellAspect),
              ),
            ),
          ),
        ),
      );
      // The guide must exist and be non-degenerate.
      expect(find.byType(ViewfinderCropGuide), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// A controller that has never produced a frame.
class _UninitialisedCameraController extends CameraController {
  _UninitialisedCameraController()
    : super(
        const CameraDescription(
          name: 'stub',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 0,
        ),
        ResolutionPreset.high,
      );

  @override
  Widget buildPreview() => const _StubPreviewSurface();
}

/// A stand-in for the plugin's preview surface.
///
/// The real [CameraController.buildPreview] returns a texture / platform view.
/// This stub fills whatever box it is given so the viewfinder's layout can be
/// measured deterministically in a widget test.
class _StubPreviewSurface extends StatelessWidget {
  const _StubPreviewSurface();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// Minimal CameraController stand-in; only the members [PhotoViewfinder] reads
/// are backed by real state.
class _StubCameraController extends CameraController {
  _StubCameraController({
    required CameraDescription description,
    required Size? streamSize,
  }) : super(description, ResolutionPreset.high) {
    value = value.copyWith(isInitialized: true, previewSize: streamSize);
  }

  @override
  Widget buildPreview() => const _StubPreviewSurface();
}