/// User-facing explanation for a camera that cannot be started.
///
/// Kept separate from the capability probes so both the native and the browser
/// implementation can construct one without importing each other.
class CameraUnavailableReason {
  const CameraUnavailableReason({required this.title, required this.detail});

  /// Short headline, e.g. "Camera blocked".
  final String title;

  /// One or two sentences telling the user what to do next.
  final String detail;

  /// The copy shown when the failure could not be classified.
  static const CameraUnavailableReason unknown = CameraUnavailableReason(
    title: 'Camera unavailable',
    detail: 'Check that a camera is available, then try again.',
  );
}