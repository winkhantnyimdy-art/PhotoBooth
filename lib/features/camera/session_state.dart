/// Enumeration of possible states during a PhotoBooth session.
enum CameraSessionState {
  /// Ready to start a session (camera initialized, no active countdown/capture).
  ready,

  /// Showing the countdown overlay (3, 2, 1) before a capture.
  countdown,

  /// Currently executing takePicture().
  capturing,

  /// Brief pause between automatic shots (only for multi-shot layouts).
  betweenShots,

  /// All required shots have been successfully captured.
  complete,

  /// An error occurred during capture or initialization.
  error,
}

/// Extension to check if the session is in a ready state.
extension CameraSessionStateIsReady on CameraSessionState {
  bool get isReady => this == CameraSessionState.ready;
}

/// Extension to check if the session is actively running (countdown, capturing,
/// betweenShots). Not ready, not complete, not error.
extension CameraSessionStateIsActive on CameraSessionState {
  bool get isActive =>
      this == CameraSessionState.countdown ||
      this == CameraSessionState.capturing ||
      this == CameraSessionState.betweenShots;
}
