import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/theme/app_colors.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/camera/camera_preferences.dart';
import 'package:photo_booth/features/camera/camera_geometry.dart';
import 'package:photo_booth/features/home/layout_geometry.dart';
import 'package:photo_booth/features/camera/camera_screen.dart';
import 'package:photo_booth/features/camera/preferences_service.dart';
import 'package:photo_booth/features/camera/session_state.dart';
import 'package:photo_booth/features/camera/shutter_sound.dart';
import 'package:photo_booth/features/camera/timing.dart';
import 'package:photo_booth/features/decorate/decorate_screen.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/features/review/review_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts shutter-sound calls without needing an audio plugin.
class _RecordingShutterSound extends ShutterSoundService {
  _RecordingShutterSound() : super.silent();

  int prepareCount = 0;
  int playCount = 0;

  @override
  Future<void> prepare() async => prepareCount++;

  @override
  Future<void> play() async => playCount++;
}

/// Stands in for a real camera so the screen can reach its ready state in a
/// widget test. Only the members the screen actually uses are overridden.
class _FakeCameraController extends CameraController {
  _FakeCameraController(CameraDescription description)
    : super(description, ResolutionPreset.high);

  @override
  Future<void> initialize() async {
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(1080, 1920),
    );
  }

  @override
  Widget buildPreview() => const _FakePreview();
}

/// Marks the stub widget returned by [_FakeCameraController.buildPreview] so
/// tests can measure the feed's on-screen box.
class _FakePreview extends StatelessWidget {
  const _FakePreview();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Color(0xFF2A2522));
  }
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

/// Pumps while resolving the test timing's pending delays, until [done] or the
/// step budget runs out. The session runner awaits one delay per countdown tick
/// and between shots.
Future<void> _runSession(
  WidgetTester tester,
  TestTiming timing,
  bool Function() done,
) async {
  for (int i = 0; i < 400; i++) {
    timing.tickAll();
    await tester.pump(const Duration(milliseconds: 20));
    if (done()) return;
  }
  fail('the capture session never finished');
}

/// Builds a [CameraScreen] wired to the fake camera, so tests that push a
/// camera themselves (e.g. an individual retake from Review) get the same
/// working preview and capture the main flow does.
Widget _fakeCameraScreen({
  required PhotoLayout layout,
  required TestTiming timing,
  required List<CameraSessionState> states,
  List<XFile>? captured,
  Completer<void>? captureGate,
  List<_FakeCameraController>? created,
  int? retakeIndex,
  ShutterSoundService? shutterSound,
}) {
  final List<XFile> photos = captured ?? <XFile>[];
  return CameraScreen(
    layout: layout,
    retakeIndex: retakeIndex,
    shutterSound: shutterSound,
    cameraProvider: () async => <CameraDescription>[_front, _back],
    controllerFactory:
        (CameraDescription description, ResolutionPreset preset) {
          final _FakeCameraController controller = _FakeCameraController(
            description,
          );
          created?.add(controller);
          return controller;
        },
    captureProvider: () async {
      photos.add(XFile('/tmp/shot_${photos.length + 1}.jpg'));
      // Holding the capture open keeps the session deterministically in
      // the `capturing` state while the test inspects the flash overlay.
      if (captureGate != null) await captureGate.future;
      return photos.last;
    },
    timing: timing,
    onStateChange: (CameraSessionState state, {int? countdown, int? shot}) {
      states.add(state);
    },
  );
}

/// Brings the camera screen to its ready state with a working preview.
Future<_FakeCameraController> _pumpReadyCamera(
  WidgetTester tester, {
  required PhotoLayout layout,
  required TestTiming timing,
  required List<CameraSessionState> states,
  List<XFile>? captured,
  Completer<void>? captureGate,
  ShutterSoundService? shutterSound,
}) async {
  final List<XFile> photos = captured ?? <XFile>[];
  final List<_FakeCameraController> created = <_FakeCameraController>[];

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme,
      home: _fakeCameraScreen(
        layout: layout,
        timing: timing,
        states: states,
        captured: photos,
        captureGate: captureGate,
        created: created,
        shutterSound: shutterSound,
      ),
    ),
  );

  // Initialise the fake camera, then finish the route entry animation.
  for (int i = 0; i < 5; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 600));
  expect(created, isNotEmpty, reason: 'a controller should be created');
  expect(
    photos.length,
    lessThan(PhotoLayout.pair2.photoCount),
    reason: 'nothing should be captured before the shutter is tapped',
  );
  return created.first;
}

void main() {
  group('Capture flow', () {
    testWidgets('the shutter is tappable and runs the whole session', (
      tester,
    ) async {
      final TestTiming timing = TestTiming();
      final List<CameraSessionState> states = <CameraSessionState>[];
      final List<XFile> captured = <XFile>[];

      await _pumpReadyCamera(
        tester,
        layout: PhotoLayout.pair2,
        timing: timing,
        states: states,
        captured: captured,
      );

      // The shutter must be exposed as an enabled button.
      final Finder shutter = find.byKey(const ValueKey('shutter'));
      expect(shutter, findsOneWidget);
      expect(
        find.descendant(of: shutter, matching: find.byType(InkWell)),
        findsOneWidget,
        reason: 'the shutter must own a tap target',
      );
      expect(captured, isEmpty, reason: 'no photo before the tap');

      await tester.tap(shutter);
      await _runSession(
        tester,
        timing,
        () => find.byType(ReviewScreen).evaluate().isNotEmpty,
      );

      // The session really ran: countdown, capture and completion were signalled.
      expect(states, contains(CameraSessionState.countdown));
      expect(states, contains(CameraSessionState.capturing));
      expect(states, contains(CameraSessionState.complete));
      expect(captured, hasLength(PhotoLayout.pair2.photoCount));

      // And the user landed on Review with the captured photos.
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
    });

    testWidgets('an individual retake replaces one photo and keeps the rest', (
      tester,
    ) async {
      final TestTiming timing = TestTiming();
      final List<CameraSessionState> states = <CameraSessionState>[];
      final List<XFile> captured = <XFile>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: ReviewScreen(
            layout: PhotoLayout.korean4,
            photos: <XFile>[
              XFile('/tmp/a.jpg'),
              XFile('/tmp/b.jpg'),
              XFile('/tmp/c.jpg'),
              XFile('/tmp/d.jpg'),
            ],
            // The retake camera is injected so the test controls capture.
            retakeCameraBuilder: (BuildContext context, int index) =>
                _fakeCameraScreen(
                  layout: PhotoLayout.korean4,
                  timing: timing,
                  states: states,
                  captured: captured,
                  retakeIndex: index,
                ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // The last photo is selected on arrival, so "Photo 4 of 4".
      expect(find.textContaining('Photo 4 of 4 selected'), findsOneWidget);
      expect(find.text('Replacing shot 4'), findsNothing);

      // Select the second photo explicitly, then retake it.
      // The 4-cut strip is very tall, so the thumbnail strip starts below the
      // fold and has to be scrolled into view before it can be tapped.
      final Finder secondThumbnail = find.byKey(
        const ValueKey('review-thumbnail-1'),
      );
      await tester.ensureVisible(secondThumbnail);
      await tester.pump();
      await tester.tap(secondThumbnail);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.textContaining('Photo 2 of 4 selected'),
        findsOneWidget,
        reason: 'tapping a thumbnail must select that photo',
      );

      await tester.tap(find.text('Retake'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // A retake captures exactly ONE frame, not a whole session.
      expect(find.byType(CameraScreen), findsOneWidget);
      expect(find.text('Replacing shot 2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shutter')));
      await _runSession(
        tester,
        timing,
        () => find.byType(ReviewScreen).evaluate().isNotEmpty,
      );

      // Exactly one new photo was captured.
      expect(captured, hasLength(1));

      // And we are back on Review with all four slots still populated.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(find.textContaining('Photo 2 of 4 selected'), findsOneWidget);
      // Every slot is still populated after the replacement.
      await tester.ensureVisible(
        find.byKey(const ValueKey('review-thumbnail-3')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('review-thumbnail-3')), findsOneWidget);
    });

    testWidgets('retake is a no-op when no photos have been captured', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const ReviewScreen(
            layout: PhotoLayout.pair2,
            photos: <XFile>[],
          ),
        ),
      );
      await tester.pump();

      // Nothing to replace, so Retake must not navigate to a camera.
      await tester.tap(find.text('Retake'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(CameraScreen), findsNothing);
      expect(find.byType(ReviewScreen), findsOneWidget);
    });

    testWidgets('capture timing is unchanged for the 2 CUT layout', (
      tester,
    ) async {
      final TestTiming timing = TestTiming();
      final List<CameraSessionState> states = <CameraSessionState>[];
      final List<XFile> captured = <XFile>[];

      await _pumpReadyCamera(
        tester,
        layout: PhotoLayout.pair2,
        timing: timing,
        states: states,
        captured: captured,
      );

      await tester.tap(find.byKey(const ValueKey('shutter')));
      await _runSession(
        tester,
        timing,
        () => find.byType(ReviewScreen).evaluate().isNotEmpty,
      );

      // Two shots: three countdown ticks each, plus one between-shot pause.
      expect(timing.delays, hasLength(7));
      expect(
        timing.delays.where(
          (Duration d) => d == const Duration(milliseconds: 400),
        ),
        hasLength(1),
      );
      expect(
        timing.delays.where((Duration d) => d == const Duration(seconds: 1)),
        hasLength(6),
      );
    });

    testWidgets('the full flow reaches decoration from the camera', (
      tester,
    ) async {
      final TestTiming timing = TestTiming();
      final List<CameraSessionState> states = <CameraSessionState>[];
      final List<XFile> captured = <XFile>[];

      await _pumpReadyCamera(
        tester,
        layout: PhotoLayout.pair2,
        timing: timing,
        states: states,
        captured: captured,
      );

      await tester.tap(find.byKey(const ValueKey('shutter')));
      await _runSession(
        tester,
        timing,
        () => find.byType(ReviewScreen).evaluate().isNotEmpty,
      );

      // The capture session hands off to ReviewScreen with a push
      // transition. Let it settle before tapping, otherwise the action row is
      // still sliding in from the right and the tap lands off screen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(DecorateScreen), findsOneWidget);
      expect(find.textContaining('Finish & Save'), findsOneWidget);
    });

    testWidgets('the camera switch control is offered with two cameras', (
      tester,
    ) async {
      final TestTiming timing = TestTiming();
      final List<CameraSessionState> states = <CameraSessionState>[];

      await _pumpReadyCamera(
        tester,
        layout: PhotoLayout.pair2,
        timing: timing,
        states: states,
      );

      expect(find.bySemanticsLabel('Switch camera'), findsOneWidget);
    });
  });

  group('Camera preview presentation', () {
    for (final Size surface in <Size>[
      const Size(320, 568),
      const Size(375, 667),
      const Size(390, 844),
      const Size(430, 932),
    ]) {
      testWidgets('the preview is given real space at '
          '${surface.width.toInt()}x${surface.height.toInt()}', (tester) async {
        // The control bar once expanded to the full screen height and left
        // the viewfinder with zero height, which read on device as a
        // completely white preview.
        tester.view.physicalSize = Size(surface.width * 3, surface.height * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final TestTiming timing = TestTiming();
        await _pumpReadyCamera(
          tester,
          layout: PhotoLayout.pair2,
          timing: timing,
          states: <CameraSessionState>[],
        );

        // The viewport must get the majority of the screen: this is exactly
        // what collapsed to zero height when the control bar was a
        // bottomNavigationBar.
        final Size viewport = tester.getSize(
          find.byKey(const ValueKey('camera-viewport')),
        );
        expect(viewport.height, greaterThan(surface.height / 3));
        expect(viewport.width, greaterThan(0));

        // The feed must COVER the crop window - the region that becomes one
        // photo cell - and not merely the whole viewport.
        //
        // Fitting the feed to the viewport instead showed the user far more
        // than the export keeps: on a tall phone the 3:4 window is a fraction
        // of the height, so a large part of what the user framed against was
        // cropped away after the fact. That mismatch was reported as the
        // framing not matching the saved photo.
        final Rect window = CameraGeometry.cropWindow(
          viewport: viewport,
          outputAspect: PhotoStripGeometry.cellAspect(PhotoLayout.pair2),
        );
        final Size feed = tester.getSize(find.byType(_FakePreview));

        expect(
          feed.width,
          greaterThanOrEqualTo(window.width - 0.5),
          reason: 'the feed must span at least the full crop-window width',
        );
        expect(
          feed.height,
          greaterThanOrEqualTo(window.height - 0.5),
          reason:
              'the feed must span at least the full crop-window height; a '
              'shorter feed is the letterboxed band reported on iOS Safari',
        );
        // Exactly one axis is flush; the other overflows and is cropped.
        final bool flushWidth = (feed.width - window.width).abs() < 0.5;
        final bool flushHeight = (feed.height - window.height).abs() < 0.5;
        expect(
          flushWidth || flushHeight,
          isTrue,
          reason: 'a cover fit must be flush on at least one axis',
        );

        // No stretching: the feed keeps the upright stream aspect.
        expect(
          feed.width / feed.height,
          closeTo(1080 / 1920, 0.02),
          reason:
              'the viewfinder must present the upright portrait frame; a 16:9 '
              'band means the device-orientation heuristic is back',
        );

        // The control bar must stay compact, not swallow the screen.
        final Size shutter = tester.getSize(
          find.byKey(const ValueKey('shutter')),
        );
        expect(shutter.height, lessThan(surface.height / 2));
      });
    }

    testWidgets('the viewport is dark, not a light page', (tester) async {
      final TestTiming timing = TestTiming();
      await _pumpReadyCamera(
        tester,
        layout: PhotoLayout.pair2,
        timing: timing,
        states: <CameraSessionState>[],
      );

      // A camera that delivers no frames must read as an empty viewfinder,
      // never as a white page.
      final Set<Color?> backdropColors = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((DecoratedBox box) {
            final Decoration decoration = box.decoration;
            return decoration is BoxDecoration ? decoration.color : null;
          })
          .toSet();

      expect(
        backdropColors,
        contains(AppColors.previewBackdrop),
        reason: 'the camera viewport must be painted dark',
      );
      // The old cream surface must not be used behind the feed any more.
      expect(
        backdropColors,
        isNot(contains(AppColors.surfaceMuted)),
        reason: 'cream behind the feed is what made a blank preview look white',
      );
    });

    testWidgets('the feed fills the viewport instead of collapsing', (
      tester,
    ) async {
      final TestTiming timing = TestTiming();
      await _pumpReadyCamera(
        tester,
        layout: PhotoLayout.pair2,
        timing: timing,
        states: <CameraSessionState>[],
      );

      // The screen must hand the feed a real, non-degenerate box: a collapsed or
      // NaN box is exactly what leaves the texture unpainted (a blank white
      // preview).
      final Size viewport = tester.getSize(
        find.byKey(const ValueKey('camera-viewport')),
      );
      final Size feed = tester.getSize(find.byType(_FakePreview));
      expect(viewport.width, greaterThan(0));
      expect(viewport.height, greaterThan(0));
      expect(feed.width, greaterThan(0));
      expect(feed.height, greaterThan(0));
      expect(feed.width / feed.height, isNot(isNaN));

      // Cover-fitted to the CROP WINDOW rather than to the whole viewport.
      // Fitting the viewport showed the user far more than the export keeps,
      // so the framing they aimed at was not the framing they got.
      final Rect window = CameraGeometry.cropWindow(
        viewport: viewport,
        outputAspect: PhotoStripGeometry.cellAspect(PhotoLayout.pair2),
      );
      expect(feed.width, greaterThanOrEqualTo(window.width - 0.5));
      expect(feed.height, greaterThanOrEqualTo(window.height - 0.5));
      expect(
        (feed.width - window.width).abs() < 0.5 ||
            (feed.height - window.height).abs() < 0.5,
        isTrue,
        reason: 'a cover fit must be flush on at least one axis',
      );

      // The crop window is the shape that is actually kept, and it is centred
      // in the viewport so framing is predictable.
      expect(
        window.width / window.height,
        closeTo(3 / 4, 0.01),
        reason: 'the crop window must match one exported 3:4 photo cell',
      );
      expect(
        ((window.left + (window.width / 2)) - (viewport.width / 2)).abs(),
        lessThan(0.5),
        reason: 'the crop window must be horizontally centred',
      );

      // The feed keeps the UPRIGHT aspect of the stream, not the raw
      // dimensions the plugin reports. The fake controller reports 1920x1080,
      // so an upright portrait frame is 1080/1920 = 0.5625.
      //
      // The old implementation produced 1920/1080 = 1.778 here, which is the
      // narrow horizontal band reported on the iPhone 16e.
      expect(
        feed.width / feed.height,
        closeTo(1080 / 1920, 0.02),
        reason:
            'the viewfinder must present the upright portrait frame; a 16:9 '
            'band means the device-orientation heuristic is back',
      );
    });

    testWidgets('switching cameras rebuilds the preview subtree', (
      tester,
    ) async {
      final TestTiming timing = TestTiming();
      final _FakeCameraController first = await _pumpReadyCamera(
        tester,
        layout: PhotoLayout.pair2,
        timing: timing,
        states: <CameraSessionState>[],
      );

      expect(find.byKey(ValueKey<CameraController>(first)), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Switch camera'));
      for (int i = 0; i < 5; i++) {
        await tester.pump();
      }

      // The old controller's texture subtree must be gone, not reused.
      expect(
        find.byKey(ValueKey<CameraController>(first)),
        findsNothing,
        reason: 'a new controller needs a fresh texture subtree',
      );
      expect(find.byType(_FakePreview), findsOneWidget);
    });

    testWidgets('the capture flash covers the whole viewport', (tester) async {
      final TestTiming timing = TestTiming();
      final List<CameraSessionState> states = <CameraSessionState>[];
      final Completer<void> gate = Completer<void>();

      await _pumpReadyCamera(
        tester,
        layout: PhotoLayout.pair2,
        timing: timing,
        states: states,
        captured: <XFile>[],
        captureGate: gate,
      );

      // Step to the first capture and hold there.
      await tester.tap(find.byKey(const ValueKey('shutter')));
      for (int i = 0; i < 60; i++) {
        timing.tick();
        await tester.pump(const Duration(milliseconds: 20));
        if (states.contains(CameraSessionState.capturing)) break;
      }
      expect(states, contains(CameraSessionState.capturing));
      await tester.pump();

      // The flash is a childless ColoredBox: without StackFit.expand it would
      // silently collapse to zero size and never be seen.
      final RenderBox flash = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('capture-flash')),
      );
      final Size viewport = tester.getSize(
        find.byKey(const ValueKey('camera-viewport')),
      );
      expect(flash.size, viewport);
      expect(flash.size.width, greaterThan(0));
      expect(flash.size.height, greaterThan(0));

      gate.complete();
      await _runSession(
        tester,
        timing,
        () => states.contains(CameraSessionState.complete),
      );
    });

    group('camera preferences', () {
      Future<void> seedPreferences({
        bool shutterSound = true,
        bool flashAnimation = true,
        int countdownSeconds = 3,
      }) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final PreferencesService service = await PreferencesService.create();
        await service.save(
          CameraPreferences(
            countdownSeconds: countdownSeconds,
            shutterSoundEnabled: shutterSound,
            flashAnimationEnabled: flashAnimation,
          ),
        );
      }

      testWidgets('plays the shutter click once per capture when enabled',
          (tester) async {
        await seedPreferences(shutterSound: true);
        final TestTiming timing = TestTiming();
        final List<CameraSessionState> states = <CameraSessionState>[];
        final _RecordingShutterSound sound = _RecordingShutterSound();

        await _pumpReadyCamera(
          tester,
          layout: PhotoLayout.pair2,
          timing: timing,
          states: states,
          shutterSound: sound,
        );
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('shutter')));
        await _runSession(
          tester,
          timing,
          () => states.contains(CameraSessionState.complete),
        );

        // Two shots in the pair2 layout, so two clicks - and the audio session
        // was armed on the shutter tap.
        expect(sound.playCount, 2);
        expect(sound.prepareCount, 1);
      });

      testWidgets('plays no sound when the preference is off', (tester) async {
        await seedPreferences(shutterSound: false);
        final TestTiming timing = TestTiming();
        final List<CameraSessionState> states = <CameraSessionState>[];
        final _RecordingShutterSound sound = _RecordingShutterSound();

        await _pumpReadyCamera(
          tester,
          layout: PhotoLayout.pair2,
          timing: timing,
          states: states,
          shutterSound: sound,
        );
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('shutter')));
        await _runSession(
          tester,
          timing,
          () => states.contains(CameraSessionState.complete),
        );

        expect(sound.playCount, 0);
        expect(sound.prepareCount, 0);
      });

      testWidgets('the flash overlay is shown when the preference is on',
          (tester) async {
        await seedPreferences(flashAnimation: true);
        final TestTiming timing = TestTiming();
        final List<CameraSessionState> states = <CameraSessionState>[];
        final Completer<void> gate = Completer<void>();

        await _pumpReadyCamera(
          tester,
          layout: PhotoLayout.pair2,
          timing: timing,
          states: states,
          captured: <XFile>[],
          captureGate: gate,
        );

        await tester.tap(find.byKey(const ValueKey('shutter')));
        for (int i = 0; i < 60; i++) {
          timing.tick();
          await tester.pump(const Duration(milliseconds: 20));
          if (states.contains(CameraSessionState.capturing)) break;
        }
        await tester.pump();

        expect(
          find.byKey(const ValueKey('capture-flash')),
          findsOneWidget,
        );

        gate.complete();
        await _runSession(
          tester,
          timing,
          () => states.contains(CameraSessionState.complete),
        );
      });

      testWidgets('the flash overlay is hidden when the preference is off',
          (tester) async {
        await seedPreferences(flashAnimation: false);
        final TestTiming timing = TestTiming();
        final List<CameraSessionState> states = <CameraSessionState>[];
        final Completer<void> gate = Completer<void>();

        await _pumpReadyCamera(
          tester,
          layout: PhotoLayout.pair2,
          timing: timing,
          states: states,
          captured: <XFile>[],
          captureGate: gate,
        );

        await tester.tap(find.byKey(const ValueKey('shutter')));
        for (int i = 0; i < 60; i++) {
          timing.tick();
          await tester.pump(const Duration(milliseconds: 20));
          if (states.contains(CameraSessionState.capturing)) break;
        }
        await tester.pump();

        expect(find.byKey(const ValueKey('capture-flash')), findsNothing);

        gate.complete();
        await _runSession(
          tester,
          timing,
          () => states.contains(CameraSessionState.complete),
        );
      });

      testWidgets('the saved countdown length drives the run', (tester) async {
        await seedPreferences(countdownSeconds: 5);
        final TestTiming timing = TestTiming();
        final List<CameraSessionState> states = <CameraSessionState>[];
        final List<int?> countdowns = <int?>[];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.theme,
            home: CameraScreen(
              layout: PhotoLayout.pair2,
              cameraProvider: () async => <CameraDescription>[_front],
              controllerFactory:
                  (CameraDescription d, ResolutionPreset p) =>
                      _FakeCameraController(d),
              captureProvider: () async => XFile('/tmp/shot.jpg'),
              timing: timing,
              shutterSound: _RecordingShutterSound(),
              onStateChange: (CameraSessionState state, {int? countdown, int? shot}) {
                states.add(state);
                if (countdown != null) countdowns.add(countdown);
              },
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('shutter')));
        await _runSession(
          tester,
          timing,
          () => states.contains(CameraSessionState.complete),
        );

        // Two shots at a five second countdown: 5,4,3,2,1 twice.
        expect(countdowns, <int>[5, 4, 3, 2, 1, 5, 4, 3, 2, 1]);
      });
    });
  });
}
