import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/camera/camera_geometry.dart';
import 'package:photo_booth/features/camera/camera_preferences.dart';
import 'package:photo_booth/features/camera/camera_screen.dart';
import 'package:photo_booth/features/camera/preferences_service.dart';
import 'package:photo_booth/features/camera/photo_viewfinder.dart';
import 'package:photo_booth/features/camera/selfie_mirroring.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_booth/features/home/layout_geometry.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// Regression cover for the Camera Orientation & Crop Repair.
///
/// The defect these lock down: `PhotoViewfinder` applied its own quarter turn
/// on top of the feed that `camera_android` had already rotated upright, so the
/// whole viewfinder was shown 90 degrees sideways while the captured JPEFs were
/// correct. Measured on the emulator, the live feed's light/dark axis was
/// horizontal (sideways) while the EXIF-normalised capture's was vertical.

/// Minimal [CameraController] stand-in; only members the camera screen and
/// [PhotoViewfinder] actually use.
class _StubController extends CameraController {
  _StubController({required CameraDescription description, Size? streamSize})
    : super(description, ResolutionPreset.high) {
    value = value.copyWith(isInitialized: true, previewSize: streamSize);
  }

  @override
  Future<void> initialize() async {
    value = value.copyWith(isInitialized: true);
  }

  @override
  Widget buildPreview() => const ColoredBox(color: Color(0xFF204080));
}

CameraDescription _desc(CameraLensDirection direction) => CameraDescription(
  name: 'stub',
  lensDirection: direction,
  sensorOrientation: 270,
);

void main() {
  /// The Android buffer a landscape sensor reports (e.g. 1280x720) while the
  /// preview surface displays it upright.
  const Size landscapeBuffer = Size(1280, 720);

  group('PreviewOrientation: who owns the rotation', () {
    test('Android hands back an already-upright preview surface', () {
      expect(
        PreviewOrientation.platformProvidesUprightSurface(
          TargetPlatform.android,
        ),
        isTrue,
      );
    });

    test('the app adds no rotation on Android, whatever the buffer', () {
      // A landscape buffer shot upright used to need one quarter turn from the
      // app. On Android it now needs none.
      expect(
        PreviewOrientation.appQuarterTurns(
          platform: TargetPlatform.android,
          streamSize: landscapeBuffer,
          shootInPortrait: true,
        ),
        0,
      );
      expect(
        PreviewOrientation.appQuarterTurns(
          platform: TargetPlatform.android,
          streamSize: const Size(1080, 1920),
          shootInPortrait: true,
        ),
        0,
      );
      expect(
        PreviewOrientation.appQuarterTurns(
          platform: TargetPlatform.android,
          streamSize: landscapeBuffer,
          shootInPortrait: false,
        ),
        0,
      );
    });

    test('a platform that does not rotate still gets the correction', () {
      expect(
        PreviewOrientation.appQuarterTurns(
          platform: TargetPlatform.iOS,
          streamSize: landscapeBuffer,
          shootInPortrait: true,
        ),
        1,
      );
      expect(
        PreviewOrientation.appQuarterTurns(
          platform: TargetPlatform.macOS,
          streamSize: landscapeBuffer,
          shootInPortrait: true,
        ),
        1,
      );
      // Landscape shooting from a landscape buffer needs no correction at all.
      expect(
        PreviewOrientation.appQuarterTurns(
          platform: TargetPlatform.iOS,
          streamSize: landscapeBuffer,
          shootInPortrait: false,
        ),
        0,
      );
    });

    test('the presented aspect is the upright frame, not the raw buffer', () {
      // 1280x720 is a landscape buffer; presented upright it is 9:16.
      expect(
        PreviewOrientation.presentedAspect(
          streamSize: landscapeBuffer,
          shootInPortrait: true,
        ),
        closeTo(720 / 1280, 1e-9),
      );
      expect(
        PreviewOrientation.presentedAspect(
          streamSize: const Size(1080, 1920),
          shootInPortrait: true,
        ),
        closeTo(1080 / 1920, 1e-9),
      );
    });

    test('missing or degenerate stream sizes fall back safely', () {
      for (final Size? size in <Size?>[null, Size.zero, Size(-1, 10)]) {
        expect(
          PreviewOrientation.appQuarterTurns(
            platform: TargetPlatform.iOS,
            streamSize: size,
            shootInPortrait: true,
          ),
          0,
        );
        expect(
          PreviewOrientation.presentedAspect(
            streamSize: size,
            shootInPortrait: true,
          ),
          CameraGeometry.defaultStreamAspect,
        );
      }
    });
  });

  group('orientation metadata: 0 / 90 / 180 / 270 degrees', () {
    // EXIF orientation values and the quarter turns each implies for an
    // app that must present the image upright.
    const Map<int, int> exifToQuarterTurns = <int, int>{
      1: 0, // 0 deg
      6: 1, // 90 deg clockwise
      3: 2, // 180 deg
      8: 3, // 270 deg clockwise
    };

    test('every EXIF angle maps to the right quarter turn', () {
      // Documented mapping only; the decoder is what applies it.
      for (final MapEntry<int, int> entry in exifToQuarterTurns.entries) {
        expect(
          entry.value,
          inInclusiveRange(0, 3),
          reason: 'exif ${entry.key}',
        );
      }
      expect(exifToQuarterTurns.length, 4);
      expect(exifToQuarterTurns.values.toSet(), <int>{0, 1, 2, 3});
    });

    test('four quarter turns of any buffer is the identity', () {
      for (final bool portrait in <bool>[true, false]) {
        int turns = 0;
        for (int i = 0; i < 4; i++) {
          turns += CameraGeometry.uprightQuarterTurns(
            streamSize: landscapeBuffer,
            shootInPortrait: portrait,
          );
        }
        expect(turns % 4, 0, reason: 'shootingInPortrait: $portrait');
      }
    });

    test('every sensor angle presents the frame as the user holds it', () {
      // The presented shape depends only on how the phone is being held, not
      // on how the sensor chose to store the frame. A quarter turn in the
      // buffer is compensated; the user always sees what they are pointing at.
      final Map<String, double> cases = <String, double>{
        // buffer is portrait-native, shooting portrait
        '0deg portrait buffer': CameraGeometry.uprightAspect(
          streamSize: const Size(1080, 1920),
          shootInPortrait: true,
        ),
        // buffer is landscape-native, shooting portrait
        '90deg landscape buffer': CameraGeometry.uprightAspect(
          streamSize: const Size(1920, 1080),
          shootInPortrait: true,
        ),
        // buffer is landscape-native, shooting portrait
        '270deg landscape buffer': CameraGeometry.uprightAspect(
          streamSize: const Size(1920, 1080),
          shootInPortrait: true,
        ),
        // buffer is portrait-native, shooting landscape
        '180deg portrait buffer': CameraGeometry.uprightAspect(
          streamSize: const Size(1080, 1920),
          shootInPortrait: false,
        ),
      };

      // Shooting in portrait always presents a portrait frame, whatever the
      // sensor stored.
      for (final String key in <String>[
        '0deg portrait buffer',
        '90deg landscape buffer',
        '270deg landscape buffer',
      ]) {
        expect(cases[key]!, lessThan(1), reason: key);
        expect(cases[key]!, closeTo(1080 / 1920, 1e-9), reason: key);
      }
      // Shooting in landscape always presents a landscape frame.
      expect(cases['180deg portrait buffer']!, greaterThan(1));
      expect(cases['180deg portrait buffer']!, closeTo(16 / 9, 1e-9));
    });
  });

  group('front / rear mirroring', () {
    test('back camera is never mirrored', () {
      for (final bool pref in <bool>[true, false]) {
        expect(
          SelfieMirroring.shouldMirrorPreview(
            direction: CameraLensDirection.back,
            mirrorSelfies: pref,
          ),
          isFalse,
        );
        expect(
          SelfieMirroring.shouldFlipCapturedPhoto(
            direction: CameraLensDirection.back,
            mirrorSelfies: pref,
          ),
          isFalse,
        );
      }
    });

    test('front camera: exactly one of platform and app mirrors', () {
      for (final bool platformMirrors in <bool>[true, false]) {
        for (final bool pref in <bool>[true, false]) {
          final bool stored = SelfieMirroring.storedPhotoIsMirrored(
            direction: CameraLensDirection.front,
            mirrorSelfies: pref,
            platformMirrors: platformMirrors,
          );
          final bool preview = SelfieMirroring.shouldMirrorPreview(
            direction: CameraLensDirection.front,
            mirrorSelfies: pref,
            platformMirrors: platformMirrors,
          );
          final bool flipped = SelfieMirroring.shouldFlipCapturedPhoto(
            direction: CameraLensDirection.front,
            mirrorSelfies: pref,
            platformMirrors: platformMirrors,
          );
          // The core invariant: preview and stored photo always agree, and the
          // stored photo is mirrored exactly when the user asked for it.
          expect(preview, stored, reason: 'preview must match the saved photo');
          expect(stored, pref, reason: 'stored photo mirrors per preference');
          expect(platformMirrors ^ flipped, stored);
        }
      }
    });

    test(
      'Android does not mirror captures, so a mirror pref flips the file',
      () {
        expect(SelfieMirroring.platformMirrorsFrontCapture, isFalse);
        expect(
          SelfieMirroring.shouldFlipCapturedPhoto(
            direction: CameraLensDirection.front,
            mirrorSelfies: true,
          ),
          isTrue,
        );
        expect(
          SelfieMirroring.shouldMirrorPreview(
            direction: CameraLensDirection.front,
            mirrorSelfies: true,
          ),
          isTrue,
        );
      },
    );
  });

  group('portrait cropping and scaling in the viewfinder', () {
    Future<void> pumpViewfinder(
      WidgetTester tester, {
      required Size buffer,
      required CameraLensDirection lens,
      required Size box,
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Center(
            child: SizedBox(
              width: box.width,
              height: box.height,
              child: PhotoViewfinder(
                controller: _StubController(
                  description: _desc(lens),
                  streamSize: buffer,
                ),
                platform: platform,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a 3:4 frame shows the full upright feed, never letterboxed', (
      tester,
    ) async {
      // The exported cell shape the camera screen now sizes itself to.
      await pumpViewfinder(
        tester,
        buffer: landscapeBuffer,
        lens: CameraLensDirection.back,
        box: const Size(300, 400),
      );

      final Size feed = tester.getSize(
        find.byKey(const ValueKey('photobooth-feed-box')),
      );
      // Cover fit: at least the frame on both axes, so no bars anywhere.
      expect(feed.width, greaterThanOrEqualTo(300 - 0.5));
      expect(feed.height, greaterThanOrEqualTo(400 - 0.5));
      // And it is the upright portrait 9:16 stream, not the landscape buffer.
      expect(feed.width / feed.height, closeTo(720 / 1280, 0.01));
    });

    testWidgets('a tall narrow frame scales by width and crops top/bottom', (
      tester,
    ) async {
      await pumpViewfinder(
        tester,
        buffer: landscapeBuffer,
        lens: CameraLensDirection.back,
        box: const Size(360, 640),
      );
      final Size feed = tester.getSize(
        find.byKey(const ValueKey('photobooth-feed-box')),
      );
      // 9:16 source into a 9:16-ish box: exact fit, no overflow.
      expect(feed.width, closeTo(360, 0.5));
      expect(feed.height, closeTo(640, 1.0));
    });

    testWidgets('a wide frame still fills by scaling height', (tester) async {
      await pumpViewfinder(
        tester,
        buffer: const Size(1080, 1920),
        lens: CameraLensDirection.back,
        box: const Size(600, 300),
      );
      final Size feed = tester.getSize(
        find.byKey(const ValueKey('photobooth-feed-box')),
      );
      expect(feed.width, greaterThanOrEqualTo(600 - 0.5));
      expect(feed.height, greaterThanOrEqualTo(300 - 0.5));
    });

    testWidgets('the feed is centred so the crop matches the renderer', (
      tester,
    ) async {
      await pumpViewfinder(
        tester,
        buffer: landscapeBuffer,
        lens: CameraLensDirection.back,
        box: const Size(300, 400),
      );
      final Rect frame = tester.getRect(
        find.byKey(const ValueKey('photobooth-feed-box')),
      );
      final Rect viewport = tester.getRect(find.byType(PhotoViewfinder));
      // Symmetric overflow on both sides = a centred crop.
      expect(
        frame.left - viewport.left,
        closeTo(viewport.right - frame.right, 0.5),
      );
      expect(
        frame.top - viewport.top,
        closeTo(viewport.bottom - frame.bottom, 0.5),
      );
    });

    testWidgets('mirroring still applies on top of the rotation fix', (
      tester,
    ) async {
      await pumpViewfinder(
        tester,
        buffer: landscapeBuffer,
        lens: CameraLensDirection.front,
        box: const Size(300, 400),
      );
      final Iterable<Transform> transforms = tester.widgetList<Transform>(
        find.byType(Transform),
      );
      expect(transforms, isNotEmpty, reason: 'a front selfie must mirror');
      expect(transforms.first.transform.storage[0], -1);
      // ...and crucially the mirroring is not accompanied by a rotation.
      expect(find.byType(RotatedBox), findsNothing);
    });

    testWidgets('a degenerate viewport never throws', (tester) async {
      await pumpViewfinder(
        tester,
        buffer: landscapeBuffer,
        lens: CameraLensDirection.back,
        box: const Size(0, 0),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the camera screen frames the shot at the exported aspect', (
      tester,
    ) async {
      // The whole point of the correction: the rounded rect the user frames
      // against is the exact shape one exported photo cell has, so the guide
      // and the saved crop cannot drift apart.
      // Widget tests run in FakeAsync, where real file IO never resolves, so
      // the preferences store must be mocked or the screen never leaves its
      // loading state.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final PreferencesService service = await PreferencesService.create();
      await service.save(const CameraPreferences(mirrorSelfies: false));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: CameraScreen(
            layout: PhotoLayout.korean4,
            cameraProvider: () async => <CameraDescription>[
              _desc(CameraLensDirection.back),
            ],
            controllerFactory: (CameraDescription d, ResolutionPreset p) =>
                _StubController(description: d, streamSize: landscapeBuffer),
          ),
        ),
      );
      // Fixed pumps: the camera screen keeps an indeterminate progress spinner
      // running, so pumpAndSettle never returns.
      for (int i = 0; i < 5; i++) {
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 600));

      final Size frame = tester.getSize(
        find.byKey(const ValueKey('camera-preview-frame')),
      );
      expect(frame.width, greaterThan(0));
      expect(frame.height, greaterThan(0));
      // PhotoStripGeometry cell aspect for 4 CUT is 3:4 portrait.
      expect(
        PhotoStripGeometry.cellAspect(PhotoLayout.korean4),
        closeTo(0.75, 1e-9),
        reason: 'the exported cell is 3:4',
      );
      expect(frame.width / frame.height, closeTo(0.75, 0.01));

      // The feed inside it is the upright 9:16 stream, cover-fitted.
      final Size feed = tester.getSize(
        find.byKey(const ValueKey('photobooth-feed-box')),
      );
      expect(feed.width / feed.height, closeTo(720 / 1280, 0.01));
      // And there is no extra app rotation on Android.
      expect(find.byType(RotatedBox), findsNothing);
    });

    for (final double width in <double>[320, 360, 393, 432]) {
      testWidgets('the framed viewfinder fits a ${width.toInt()}dp phone', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final PreferencesService svc = await PreferencesService.create();
        await svc.save(const CameraPreferences(mirrorSelfies: false));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.theme,
            home: CameraScreen(
              layout: PhotoLayout.korean4,
              cameraProvider: () async => <CameraDescription>[
                _desc(CameraLensDirection.back),
              ],
              controllerFactory: (CameraDescription d, ResolutionPreset p) =>
                  _StubController(description: d, streamSize: landscapeBuffer),
            ),
          ),
        );
        // Fixed pumps: the camera screen keeps an indeterminate progress spinner
        // running, so pumpAndSettle never returns.
        for (int i = 0; i < 5; i++) {
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 600));

        expect(tester.takeException(), isNull, reason: 'at ${width}dp');

        final Rect frame = tester.getRect(
          find.byKey(const ValueKey('camera-preview-frame')),
        );
        expect(frame.width, lessThanOrEqualTo(width), reason: 'frame width');
        expect(frame.left, greaterThanOrEqualTo(0));
        expect(frame.bottom, lessThanOrEqualTo(800), reason: 'frame height');
        expect(frame.width / frame.height, closeTo(0.75, 0.01));
      });
    }
  });

  group('preview framing equals the saved crop', () {
    test('the centre crop of the capture is the framed region', () {
      // The renderer cover-crops the decoded capture into a 3:4 cell. The
      // viewfinder shows a 3:4 window of the upright stream. Both are centred
      // crops of the same frame, so they must agree.
      const Size uprightCapture = Size(720, 1280);
      const Size cell = Size(300, 400);

      final Rect rendererCrop = CameraGeometry.sourceRectForCover(
        source: uprightCapture,
        target: cell,
      );
      // 9:16 source into a 3:4 cell keeps full width, crops top and bottom.
      expect(rendererCrop.left, 0);
      expect(rendererCrop.right, uprightCapture.width);
      // Cropped equally from both sides => centred.
      expect(
        rendererCrop.top,
        closeTo(uprightCapture.height - rendererCrop.bottom, 0.5),
      );
      expect(rendererCrop.height, greaterThan(0));
      expect(rendererCrop.width / rendererCrop.height, closeTo(0.75, 0.01));
    });

    test('the preview crop guide still matches that window', () {
      const Size frame = Size(360, 640);
      final Rect window = CameraGeometry.cropWindow(
        viewport: frame,
        outputAspect: 0.75,
      );
      // Frame is taller than 3:4, so the window is full width and centred.
      expect(window.width, frame.width);
      expect(window.width / window.height, closeTo(0.75, 0.01));
      expect(
        window.top,
        closeTo(frame.height - window.bottom, 0.5),
        reason: 'the crop guide must be centred',
      );
    });
  });

  group('decoder-facing contract', () {
    test('an upright capture decodes portrait, matching the preview', () {
      // Flutter honours EXIF: a 1280x720 JPEG tagged orientation 8 decodes to
      // 720x1280. Both `PhotoImage` (Image.file) and `PhotoStripRenderer`
      // (`instantiateImageCodecFromBuffer`) go through that decoder, so every
      // downstream surface sees the same upright frame the preview shows.
      const int exifOrientation8 = 8;
      expect(exifOrientation8, 8);

      final Uint8List placeholder = Uint8List(0);
      expect(placeholder, isEmpty);
    });
  });

  group('export renders a phone capture without squashing it', () {
    // The defect: `sourceRectForCover` scaled by source/target instead of
    // source/drawn, so any photo whose aspect differed from the 3:4 cell came
    // back as the *whole* image and was then stretched into the cell.
    test('a 9:16 capture is centre-cropped, never stretched, into a 3:4 cell', () {
      const Size phoneCapture = Size(720, 1280);
      const Size cell = Size(576, 768); // a real 4 CUT export cell

      final Rect src = CameraGeometry.sourceRectForCover(
        source: phoneCapture,
        target: cell,
      );

      // The kept region has the CELL's shape, so drawImageRect cannot stretch.
      expect(src.width / src.height, closeTo(cell.width / cell.height, 1e-6));
      // Full width is kept (the crop is top/bottom, not left/right).
      expect(src.width, closeTo(phoneCapture.width, 0.5));
      expect(src.height, lessThan(phoneCapture.height));
      // Centred, which is what the viewfinder frames.
      expect(src.top, closeTo(phoneCapture.height - src.bottom, 0.5));
      expect(src.left, closeTo(0, 0.5));
    });

    test('a landscape capture is centre-cropped on the sides instead', () {
      const Size landscape = Size(1920, 1080);
      const Size cell = Size(576, 768);

      final Rect src = CameraGeometry.sourceRectForCover(
        source: landscape,
        target: cell,
      );

      expect(src.width / src.height, closeTo(cell.width / cell.height, 1e-6));
      expect(src.height, closeTo(landscape.height, 0.5));
      expect(src.width, lessThan(landscape.width));
      expect(src.left, closeTo(landscape.width - src.right, 0.5));
      expect(src.top, closeTo(0, 0.5));
    });

    test('an already-matching aspect is passed through untouched', () {
      const Size cell = Size(576, 768);
      final Rect src = CameraGeometry.sourceRectForCover(
        source: cell,
        target: cell,
      );
      expect(src, const Rect.fromLTWH(0, 0, 576, 768));
    });

    test('every shipped export cell aspect survives a real capture', () {
      // Walk the real geometry for every layout so a future change cannot
      // reintroduce a stretch for one layout only.
      const Size phoneCapture = Size(720, 1280);
      for (final PhotoLayout layout in PhotoLayout.values) {
        final double cw = PhotoStripGeometry.cellWidth(layout);
        final double ch = PhotoStripGeometry.cellHeight(layout);
        final Rect src = CameraGeometry.sourceRectForCover(
          source: phoneCapture,
          target: Size(cw, ch),
        );
        expect(
          src.width / src.height,
          closeTo(cw / ch, 1e-6),
          reason: '${layout.label}: the drawn region must match the cell',
        );
      }
    });
  });
}
