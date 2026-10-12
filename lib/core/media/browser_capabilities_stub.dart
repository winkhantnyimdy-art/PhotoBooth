import 'camera_unavailable_reason.dart';

/// Native (Android/iOS) capability stub.
///
/// Native platforms have no secure-context concept and no Web Share API, so the
/// probes report "supported" and camera errors fall back to generic copy.
abstract final class BrowserCapabilities {
  /// True when the runtime can capture from a camera at all.
  static bool get hasCameraSupport => true;

  /// True when `getUserMedia` would be permitted in this context.
  static bool get isSecureContext => true;

  /// True when the platform can show a share sheet for a file.
  static bool get canShareFiles => true;

  /// Maps a thrown camera error to user-facing copy, or null when unknown.
  static CameraUnavailableReason? describeCameraError(String? code) => null;

  /// Never reached on native: [isSecureContext] is always true.
  static CameraUnavailableReason get insecureContextReason =>
      CameraUnavailableReason.unknown;

  /// Never reached on native: [hasCameraSupport] is always true.
  static CameraUnavailableReason get unsupportedReason =>
      CameraUnavailableReason.unknown;
}