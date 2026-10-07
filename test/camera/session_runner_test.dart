import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/features/camera/session_runner.dart';
import 'package:photo_booth/features/camera/session_state.dart';
import 'package:photo_booth/features/camera/timing.dart';

final fakeXFile = XFile('/fake/photo.png');

/// Advance the test timing by one delay and yield to the event loop so the
/// suspended runner can resume.
Future<void> tick(TestTiming timing) async {
  timing.tick();
  await Future.delayed(const Duration(milliseconds: 1));
}

void main() {
  group('SessionRunner', () {
    test('countdown shows 3, 2, 1', () async {
      final timing = TestTiming();
      final steps = <CameraSessionState>[];
      final countdowns = <int>[];

      final runner = SessionRunner(
        timing: timing,
        takePicture: () async {
          await timing.delay(const Duration(seconds: 1));
          return fakeXFile;
        },
        onStep: (state, {countdown, shot}) {
          steps.add(state);
          if (countdown != null) countdowns.add(countdown);
        },
      );

      final done = runner.run(1).then((_) => true);

      await tick(timing); // countdown 3
      await tick(timing); // countdown 2
      await tick(timing); // countdown 1
      await tick(timing); // capture

      expect(await done, isTrue);
      expect(countdowns, [3, 2, 1]);
      expect(steps, [
        CameraSessionState.countdown,
        CameraSessionState.countdown,
        CameraSessionState.countdown,
        CameraSessionState.capturing,
        CameraSessionState.complete,
      ]);
    });

    test('4 shots require exactly 4 captures', () async {
      final timing = TestTiming();
      int captureCount = 0;

      final runner = SessionRunner(
        timing: timing,
        takePicture: () async {
          captureCount++;
          await timing.delay(const Duration(seconds: 1));
          return fakeXFile;
        },
        onStep: (state, {countdown, shot}) {},
      );

      final done = runner.run(4).then((_) => true);

      // 4 shots: 12 countdown delays + 4 capture delays + 3 between-shot delays
      for (int i = 0; i < 19; i++) {
        await tick(timing);
      }

      expect(await done, isTrue);
      expect(captureCount, 4);
    });

    test('2 shots require exactly 2 captures', () async {
      final timing = TestTiming();
      int captureCount = 0;

      final runner = SessionRunner(
        timing: timing,
        takePicture: () async {
          captureCount++;
          await timing.delay(const Duration(seconds: 1));
          return fakeXFile;
        },
        onStep: (state, {countdown, shot}) {},
      );

      final done = runner.run(2).then((_) => true);

      // 2 shots: 6 countdown delays + 2 capture delays + 1 between-shot delay
      for (int i = 0; i < 9; i++) {
        await tick(timing);
      }

      expect(await done, isTrue);
      expect(captureCount, 2);
    });

    test('between-shot pause present for 4-shot sequence', () async {
      final timing = TestTiming();
      final steps = <CameraSessionState>[];

      final runner = SessionRunner(
        timing: timing,
        takePicture: () async {
          await timing.delay(const Duration(seconds: 1));
          return fakeXFile;
        },
        onStep: (state, {countdown, shot}) => steps.add(state),
      );

      final done = runner.run(4).then((_) => true);

      for (int i = 0; i < 19; i++) {
        await tick(timing);
      }

      expect(await done, isTrue);
      final betweenShots = steps
          .where((s) => s == CameraSessionState.betweenShots)
          .length;
      expect(betweenShots, 3);
    });

    test('capture failure stops sequence with error', () async {
      final timing = TestTiming();
      final steps = <CameraSessionState>[];

      final runner = SessionRunner(
        timing: timing,
        takePicture: () async {
          await timing.delay(const Duration(seconds: 1));
          throw CameraException('err', 'boom');
        },
        onStep: (state, {countdown, shot}) => steps.add(state),
      );

      final done = runner.run(2).then((result) => result);

      // 3 countdown delays + 1 capture delay
      for (int i = 0; i < 4; i++) {
        await tick(timing);
      }

      final result = await done;
      expect(steps.last, CameraSessionState.error);
      expect(result.success, false);
      expect(result.error, equals('Capture failed'));
    });

    test('cancellation stops sequence', () async {
      final timing = TestTiming();
      final token = CancellationToken();

      final runner = SessionRunner(
        timing: timing,
        takePicture: () async {
          await timing.delay(const Duration(seconds: 1));
          return fakeXFile;
        },
        onStep: (state, {countdown, shot}) {},
        cancelToken: token,
      );

      token.cancelled = true;
      final result = await runner.run(4);

      expect(result.success, false);
      expect(result.photos.isEmpty, true);
    });

    test('stepHistory records correct sequence for 2 shots', () async {
      final timing = TestTiming();

      final runner = SessionRunner(
        timing: timing,
        takePicture: () async {
          await timing.delay(const Duration(seconds: 1));
          return fakeXFile;
        },
        onStep: (state, {countdown, shot}) {},
      );

      final done = runner.run(2).then((_) => true);

      for (int i = 0; i < 9; i++) {
        await tick(timing);
      }

      expect(await done, isTrue);
      final history = runner.stepHistory;
      final countdownCount = history
          .where((s) => s == CameraSessionState.countdown)
          .length;
      expect(countdownCount, equals(6)); // 2 countdowns x 3 steps
    });
  });
}
