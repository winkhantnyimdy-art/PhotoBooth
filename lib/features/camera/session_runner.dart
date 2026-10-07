import 'package:camera/camera.dart';

import 'session_state.dart';
import 'timing.dart';

/// Cancellation token shared between the runner and the UI so the
/// user can abort an in-progress sequence.
class CancellationToken {
  CancellationToken({this.cancelled = false});

  /// Set to true when the user leaves/cancels the session.
  bool cancelled;
}

/// Result of a completed session run.
class SessionResult {
  const SessionResult({
    required this.success,
    this.error,
    this.photos = const [],
  });

  final bool success;
  final String? error;
  final List<XFile> photos;
}

/// Runs the PhotoBooth capture sequence: countdown (3, 2, 1) per shot,
/// capture, brief between-shot pause, then repeat for the layout's
/// shot count.
///
/// All external concerns are injected:
/// - [timing] — enables instant testing via [TestTiming].
/// - [takePicture] — calls [CameraController.takePicture] in production;
///   test fakes return a fake XFile or throw to simulate errors.
/// - [onStep] — callback called on each state transition; used by tests
///   to record the sequence without real delays.
///
/// Cancellation is cooperative: the runner checks [cancelToken.cancelled]
/// between shots and aborts immediately if set. No [setState] is called
/// inside this class (pure Dart).
class SessionRunner {
  SessionRunner({
    required this.timing,
    required this.takePicture,
    required this.onStep,
    this.cancelToken,
  });

  final Timing timing;
  final Future<XFile?> Function() takePicture;
  final void Function(CameraSessionState state, {int? countdown, int? shot})
  onStep;
  final CancellationToken? cancelToken;

  /// Ordered history of states (for test assertions).
  final List<CameraSessionState> stepHistory = [];

  /// Runs the full sequence for [shots] captures.
  /// Returns a [SessionResult] with all successfully captured photos.
  Future<SessionResult> run(int shots) async {
    final photos = <XFile>[];
    final token = cancelToken;
    for (var i = 0; i < shots; i++) {
      if (token != null && token.cancelled) {
        onStep(CameraSessionState.ready);
        stepHistory.add(CameraSessionState.ready);
        return SessionResult(
          success: photos.isEmpty ? false : photos.length == shots,
          error: photos.isEmpty ? 'Cancelled' : null,
          photos: photos,
        );
      }

      // Countdown 3, 2, 1
      for (var n = 3; n >= 1; n--) {
        if (token != null && token.cancelled) {
          onStep(CameraSessionState.ready);
          stepHistory.add(CameraSessionState.ready);
          return SessionResult(success: photos.length == shots, photos: photos);
        }
        onStep(CameraSessionState.countdown, countdown: n);
        stepHistory.add(CameraSessionState.countdown);
        await timing.delay(const Duration(seconds: 1));
      }

      // Capture
      onStep(CameraSessionState.capturing);
      stepHistory.add(CameraSessionState.capturing);
      final XFile? photo;
      try {
        photo = await takePicture();
      } catch (e) {
        onStep(CameraSessionState.error);
        stepHistory.add(CameraSessionState.error);
        return SessionResult(
          success: false,
          error: 'Capture failed',
          photos: photos,
        );
      }
      if (photo == null) {
        onStep(CameraSessionState.error);
        stepHistory.add(CameraSessionState.error);
        return SessionResult(
          success: false,
          error: 'Capture failed',
          photos: photos,
        );
      }
      photos.add(photo);

      // Between-shot pause (skip after last shot)
      if (i < shots - 1) {
        onStep(CameraSessionState.betweenShots);
        stepHistory.add(CameraSessionState.betweenShots);
        await timing.delay(const Duration(milliseconds: 400));
      }
    }

    onStep(CameraSessionState.complete);
    stepHistory.add(CameraSessionState.complete);
    return SessionResult(success: true, photos: photos);
  }
}
