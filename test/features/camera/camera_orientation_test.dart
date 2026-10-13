import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/theme/app_colors.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/core/media/preview_decode.dart';
import 'package:photo_booth/features/camera/camera_geometry.dart';
import 'package:photo_booth/features/camera/photo_viewfinder.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/export/photo_strip_renderer.dart';
import 'package:photo_booth/features/home/layout_geometry.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// Marker colours, one per quadrant: top-left red, top-right green,
/// bottom-left blue, bottom-right yellow.
///
/// An asymmetric fixture is what makes orientation testable. A symmetric image
/// looks identical after a horizontal flip, a vertical flip or a 180 rotation,
/// so it cannot distinguish them - which is exactly why the mirrored selfie
/// went unnoticed. With four distinct quadrants each transform produces a
/// different, unambiguous result.
const Color kTopLeft = Color(0xFFFF0000);
const Color kTopRight = Color(0xFF00FF00);
const Color kBottomLeft = Color(0xFF0000FF);
const Color kBottomRight = Color(0xFFFFFF00);

/// Paints the four-quadrant marker.
Future<Uint8List> quadrantPng({int size = 64}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final double h = size / 2;
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, h, h), ui.Paint()..color = kTopLeft);
  canvas.drawRect(
    ui.Rect.fromLTWH(h, 0, h, h),
    ui.Paint()..color = kTopRight,
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(0, h, h, h),
    ui.Paint()..color = kBottomLeft,
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(h, h, h, h),
    ui.Paint()..color = kBottomRight,
  );
  final ui.Image image = await recorder.endRecording().toImage(size, size);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// The nearest marker colour at [x], [y] of the encoded image.
String _markerAt(Uint8List px, int width, int height, double fx, double fy) {
  final int x = (fx * width).clamp(0.0, (width - 1).toDouble()).round();
  final int y = (fy * height).clamp(0.0, (height - 1).toDouble()).round();
  final int i = ((y * width) + x) * 4;
  final int r = px[i];
  final int g = px[i + 1];
  final int b = px[i + 2];

  int distance(Color c) =>
      ((r - c.r * 255).abs() +
              (g - c.g * 255).abs() +
              (b - c.b * 255).abs())
          .round();

  final List<(String, int)> options = <(String, int)>[
    ('TL', distance(kTopLeft)),
    ('TR', distance(kTopRight)),
    ('BL', distance(kBottomLeft)),
    ('BR', distance(kBottomRight)),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return options.first.$1;
}

/// Reads the marker layout of an encoded image.
Future<({String tl, String tr, String bl, String br})> _layout(
  Uint8List png,
) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(png);
  final ui.Codec codec = await ui.instantiateImageCodecFromBuffer(buffer);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ByteData? raw =
      await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final int width = frame.image.width;
  final int height = frame.image.height;
  frame.image.dispose();
  codec.dispose();
  final Uint8List px = raw!.buffer.asUint8List();
  return (
    tl: _markerAt(px, width, height, 0.25, 0.25),
    tr: _markerAt(px, width, height, 0.75, 0.25),
    bl: _markerAt(px, width, height, 0.25, 0.75),
    br: _markerAt(px, width, height, 0.75, 0.75),
  );
}

const ({String tl, String tr, String bl, String br}) kOriginal = (
  tl: 'TL',
  tr: 'TR',
  bl: 'BL',
  br: 'BR',
);

/// A stand-in camera so the viewfinder can be measured without hardware.
class _FakeController extends CameraController {
  _FakeController(CameraDescription description)
    : super(description, ResolutionPreset.high);

  @override
  Future<void> initialize() async {
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(1080, 1920),
    );
  }

  @override
  Widget buildPreview() => const ColoredBox(color: Color(0xFF2A2522));
}

const CameraDescription _front = CameraDescription(
  name: 'fake-front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 0,
);
const CameraDescription _back = CameraDescription(
  name: 'fake-back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 0,
);

void main() {
  group('the asymmetric fixture can tell every transform apart', () {
    test('a horizontal flip swaps left and right only', () async {
      final Uint8List png = await quadrantPng();
      expect(await _layout(png), kOriginal);

      // A local copy of the capture-time transform.
      final ui.ImmutableBuffer buffer =
          await ui.ImmutableBuffer.fromUint8List(png);
      final ui.Codec codec = await ui.instantiateImageCodecFromBuffer(buffer);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      canvas
        ..translate(frame.image.width.toDouble(), 0)
        ..scale(-1, 1)
        ..drawImage(frame.image, Offset.zero, Paint());
      final ui.Picture picture = recorder.endRecording();
      final ui.Image out = await picture.toImage(
        frame.image.width,
        frame.image.height,
      );
      final ByteData? data = await out.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frame.image.dispose();
      out.dispose();
      codec.dispose();
      picture.dispose();

      final layout = await _layout(data!.buffer.asUint8List());
      expect(layout.tl, 'TR', reason: 'left must take the right quadrant');
      expect(layout.tr, 'TL');
      expect(layout.bl, 'BR', reason: 'the vertical order must be untouched');
      expect(layout.br, 'BL');
      expect(layout, isNot(kOriginal));
    });
  });

  group('crop geometry keeps 3:4 and never reverses', () {
    for (final Size viewport in <Size>[
      const Size(320, 568),
      const Size(375, 667),
      const Size(390, 844),
      const Size(430, 932),
      const Size(1024, 768),
    ]) {
      test('cropWindow is 3:4 and centred at ${viewport.width.toInt()}'
          'x${viewport.height.toInt()}', () {
        final double aspect =
            PhotoStripGeometry.cellAspect(PhotoLayout.korean4);
        final Rect window = CameraGeometry.cropWindow(
          viewport: viewport,
          outputAspect: aspect,
        );

        expect(
          window.width / window.height,
          closeTo(aspect, 0.001),
          reason: 'the kept region must have the exported cell shape',
        );
        expect(window.width, lessThanOrEqualTo(viewport.width + 0.01));
        expect(window.height, lessThanOrEqualTo(viewport.height + 0.01));
        expect(
          ((window.left + (window.width / 2)) - (viewport.width / 2)).abs(),
          lessThan(0.01),
          reason: 'horizontally centred',
        );
        expect(
          ((window.top + (window.height / 2)) - (viewport.height / 2)).abs(),
          lessThan(0.01),
          reason: 'vertically centred',
        );
      });
    }

    test('a wider-than-target viewport keeps full height and narrows', () {
      // 400x400 is wider than the 3:4 target, so the crop takes the whole
      // height and trims the sides rather than letterboxing.
      final Rect window = CameraGeometry.cropWindow(
        viewport: const Size(400, 400),
        outputAspect: 3 / 4,
      );
      expect(window.height, closeTo(400, 0.01));
      expect(window.width, closeTo(400 * 0.75, 0.01));
      expect(window.width / window.height, closeTo(0.75, 0.001));
    });

    test('a taller-than-target viewport keeps full width and shortens', () {
      // 390x844 is much taller than 3:4, so the crop keeps the width and drops
      // most of the height. This is the case that made the old viewfinder
      // misleading: it showed the user all 844 px while only ~520 survived.
      final Rect window = CameraGeometry.cropWindow(
        viewport: const Size(390, 844),
        outputAspect: 3 / 4,
      );
      expect(window.width, closeTo(390, 0.01));
      expect(window.height, closeTo(390 / 0.75, 0.01));
      expect(
        window.height,
        lessThan(844 * 0.7),
        reason: 'most of the old preview height was cropped away afterwards',
      );
    });

    test('the source rect stays inside the source and keeps its shape', () {
      const Size viewport = Size(390, 844);
      const Size sourceSize = Size(1080, 1920);
      final Rect window = CameraGeometry.cropWindow(
        viewport: viewport,
        outputAspect: 3 / 4,
      );
      final Rect src = CameraGeometry.sourceRectForCrop(
        viewport: viewport,
        sourceSize: sourceSize,
        cropWindow: window,
      );

      expect(src.left, greaterThanOrEqualTo(0));
      expect(src.top, greaterThanOrEqualTo(0));
      expect(src.right, lessThanOrEqualTo(sourceSize.width + 0.01));
      expect(src.bottom, lessThanOrEqualTo(sourceSize.height + 0.01));

      // Same shape as the window: no stretching anywhere in the chain.
      expect(
        src.width / src.height,
        closeTo(window.width / window.height, 0.001),
      );
      // Centre crop: the kept region is centred in the source.
      expect(
        ((src.left + (src.width / 2)) - (sourceSize.width / 2)).abs(),
        lessThan(0.5),
      );
    });

    test('cover cropping keeps the marker on its original side', () async {
      // The crop must not transpose the image: a top-left marker must still be
      // top-left after the export crop.
      final Uint8List png = await quadrantPng(size: 120);
      final Directory dir = Directory.systemTemp.createTempSync('orient');
      addTearDown(() {
        try {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        } on Object {
          // Best effort.
        }
      });
      final File file = File('${dir.path}/quadrant.png');
      await file.writeAsBytes(png);

      final Uint8List exported = await PhotoStripRenderer().render(
        layout: PhotoLayout.grid4,
        photos: <XFile>[
          XFile(file.path),
          XFile(file.path),
          XFile(file.path),
          XFile(file.path),
        ],
        decorationState: const DecorationState(
          layout: PhotoLayout.grid4,
          background: BackgroundChoice.cream,
          style: DecorativeStyle.clean,
        ),
      );

      final ui.ImmutableBuffer buffer =
          await ui.ImmutableBuffer.fromUint8List(exported);
      final ui.Codec codec = await ui.instantiateImageCodecFromBuffer(buffer);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? raw =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final int width = frame.image.width;
      final int height = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      final Uint8List px = raw!.buffer.asUint8List();

      // Sample inside the first cell, clear of the paper margin.
      final ui.Rect cell = PhotoStripGeometry.cellRect(PhotoLayout.grid4, 0);
      final double sx = width / PhotoStripGeometry.exportWidth;
      final int x = (cell.center.dx * sx).round();
      final int y = (cell.center.dy * sx).round();
      final int i = ((y * width) + x) * 4;

      // Red in the top-left of the source means red-dominant at the cell's
      // top-left sample; the centre lands on the boundary, so sample the cell's
      // own top-left quadrant instead.
      final int qx = (cell.left * sx + (cell.width * sx * 0.25)).round();
      final int qy = (cell.top * sx + (cell.height * sx * 0.25)).round();
      final int qi = ((qy * width) + qx) * 4;
      expect(px[qi], greaterThan(150), reason: 'red channel of the TL marker');
      expect(px[qi + 1], lessThan(110));
      expect(px[qi + 2], lessThan(110));

      // Sanity: the sample is inside the image.
      expect(i, greaterThan(0));
      expect(i + 3, lessThan(px.length));
      expect(height, greaterThan(0));
    });
  });

  group('preview orientation matches the stored photo', () {
    testWidgets('the front preview mirrors only when selfies are mirrored', (
      tester,
    ) async {
      Future<void> pumpViewfinder(bool mirrorSelfies) async {
        final _FakeController controller = _FakeController(_front);
        await controller.initialize();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.theme,
            home: PhotoViewfinder(
              controller: controller,
              mirrorSelfies: mirrorSelfies,
            ),
          ),
        );
        await tester.pump();
      }

      await pumpViewfinder(true);
      expect(
        find.byType(Transform),
        findsWidgets,
        reason: 'a mirrored selfie needs a mirror transform',
      );

      await pumpViewfinder(false);
      expect(
        find.byType(Transform),
        findsNothing,
        reason:
            'with mirroring off the preview must show the natural '
            'orientation, exactly like the photo that will be saved',
      );
    });

    testWidgets('the back preview is never mirrored', (tester) async {
      final _FakeController controller = _FakeController(_back);
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: PhotoViewfinder(
            controller: controller,
            mirrorSelfies: true,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byType(Transform),
        findsNothing,
        reason: 'the back camera must never be flipped',
      );
    });

    testWidgets('the feed is never stretched', (tester) async {
      final _FakeController controller = _FakeController(_front);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: PhotoViewfinder(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();

      final Size feed = tester.getSize(
        find.byKey(const ValueKey('photobooth-feed-box')),
      );
      // The upright stream is 1080x1920; a 3:4 crop window in a 390x844
      // viewport is 390x520, and the feed must keep the stream's own aspect.
      expect(feed.width / feed.height, closeTo(1080 / 1920, 0.01));
    });

    testWidgets('the backdrop is used before the camera is ready', (
      tester,
    ) async {
      final _FakeController controller = _FakeController(_front);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: PhotoViewfinder(controller: controller),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('photobooth-feed-box')), findsNothing);
      expect(find.byType(ColoredBox), findsWidgets);
      expect(AppColors.previewBackdrop, isNot(Colors.white));
    });
  });

  group('preview decode sizing', () {
    test('is bounded so a preview can never allocate a full-size bitmap', () {
      expect(PreviewDecode.maxWidth, lessThanOrEqualTo(2048));

      // A 3x phone previewing a ~350 px cell must not ask for thousands of
      // pixels.
      final int? width = PreviewDecode.forWidth(350, 3);
      expect(width, isNotNull);
      expect(width!, lessThanOrEqualTo(PreviewDecode.maxWidth));
      expect(width, greaterThanOrEqualTo(PreviewDecode.minWidth));
    });

    test('is capped for absurd logical sizes', () {
      expect(PreviewDecode.forWidth(4000, 3), PreviewDecode.maxWidth);
    });

    test('returns null when the size is unknown', () {
      expect(PreviewDecode.forWidth(0, 3), isNull);
      expect(PreviewDecode.forWidth(-10, 3), isNull);
      expect(PreviewDecode.forWidth(double.nan, 3), isNull);
      expect(PreviewDecode.forWidth(200, 0), isNull);
    });

    test('scales with the device pixel ratio', () {
      expect(PreviewDecode.forWidth(200, 1), 200);
      expect(PreviewDecode.forWidth(200, 2), 400);
      expect(PreviewDecode.forWidth(200, 3), 600);
    });
  });
}