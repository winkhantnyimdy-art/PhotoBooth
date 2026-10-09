import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/camera/camera_screen.dart';
import 'package:photo_booth/features/camera/session_state.dart';
import 'package:photo_booth/features/camera/timing.dart';
import 'package:photo_booth/features/decorate/decorate_screen.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/features/review/review_screen.dart';

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

/// Brings the camera screen to its ready state with a working preview.
Future<_FakeCameraController> _pumpReadyCamera(
  WidgetTester tester, {
  required PhotoLayout layout,
  required TestTiming timing,
  required List<CameraSessionState> states,
  List<XFile>? captured,
}) async {
  final List<XFile> photos = captured ?? <XFile>[];
  final List<_FakeCameraController> created = <_FakeCameraController>[];

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme,
      home: CameraScreen(
        layout: layout,
        cameraProvider: () async => <CameraDescription>[_front, _back],
        controllerFactory:
            (CameraDescription description, ResolutionPreset preset) {
              final _FakeCameraController controller = _FakeCameraController(
                description,
              );
              created.add(controller);
              return controller;
            },
        captureProvider: () async {
          photos.add(XFile('/tmp/shot_${photos.length + 1}.jpg'));
          return photos.last;
        },
        timing: timing,
        onStateChange: (CameraSessionState state, {int? countdown, int? shot}) {
          states.add(state);
        },
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
    lessThan(PhotoLayout.cut2.photoCount),
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
        layout: PhotoLayout.cut2,
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
      expect(captured, hasLength(PhotoLayout.cut2.photoCount));

      // And the user landed on Review with the captured photos.
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(find.text('Looking good!'), findsOneWidget);
    });

    testWidgets('Retake re-arms the shutter for another session', (
      tester,
    ) async {
      final TestTiming timing = TestTiming();
      final List<CameraSessionState> states = <CameraSessionState>[];
      final List<XFile> captured = <XFile>[];

      await _pumpReadyCamera(
        tester,
        layout: PhotoLayout.cut2,
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

      // Retake returns to the camera, which must be usable again.
      await tester.tap(find.text('Retake'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ReviewScreen), findsNothing);

      final Finder shutter = find.byKey(const ValueKey('shutter'));
      expect(shutter, findsOneWidget);
      final InkWell tapTarget = tester.widget<InkWell>(
        find.descendant(of: shutter, matching: find.byType(InkWell)),
      );
      expect(
        tapTarget.onTap,
        isNotNull,
        reason: 'the shutter must be re-armed',
      );

      // A second session is possible.
      states.clear();
      await tester.tap(find.byKey(const ValueKey('shutter')));
      await _runSession(
        tester,
        timing,
        () => find.byType(ReviewScreen).evaluate().isNotEmpty,
      );
      expect(states, contains(CameraSessionState.complete));
      expect(captured, hasLength(PhotoLayout.cut2.photoCount * 2));
    });

    testWidgets('capture timing is unchanged for the 2 CUT layout', (
      tester,
    ) async {
      final TestTiming timing = TestTiming();
      final List<CameraSessionState> states = <CameraSessionState>[];
      final List<XFile> captured = <XFile>[];

      await _pumpReadyCamera(
        tester,
        layout: PhotoLayout.cut2,
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
        layout: PhotoLayout.cut2,
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

      await tester.tap(find.text('Continue to Decorate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(DecorateScreen), findsOneWidget);
      expect(find.text('Preview & Export'), findsOneWidget);
    });

    testWidgets('the camera switch control is offered with two cameras', (
      tester,
    ) async {
      final TestTiming timing = TestTiming();
      final List<CameraSessionState> states = <CameraSessionState>[];

      await _pumpReadyCamera(
        tester,
        layout: PhotoLayout.cut2,
        timing: timing,
        states: states,
      );

      expect(find.bySemanticsLabel('Switch camera'), findsOneWidget);
    });
  });
}
