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
  ///
  /// The CameraX backend throws `CameraException`s whose codes are defined in
  /// `CameraPermissionsManager.java` (`CameraAccessDenied`) and
  /// `android_camera_camerax.dart` (`cameraNotFound`). A denial must tell the
  /// user where to fix it (the system Settings app when "Don't ask again" was
  /// chosen), not just to "try again".
  static CameraUnavailableReason? describeCameraError(String? code) {
    switch (code) {
      case 'CameraAccessDenied':
        return const CameraUnavailableReason(
          title: 'Camera permission needed',
          detail: 'PhotoBooth needs camera access to take photos. Allow the '
              'camera permission and try again. If you chose "Don\'t ask '
              'again", enable it in the system Settings app.',
        );
      case 'cameraNotFound':
        return const CameraUnavailableReason(
          title: 'No cameras detected',
          detail: 'Check that a camera is available, then try again.',
        );
      default:
        return null;
    }
  }

  /// Never reached on native: [isSecureContext] is always true.
  static CameraUnavailableReason get insecureContextReason =>
      CameraUnavailableReason.unknown;

  /// Never reached on native: [hasCameraSupport] is always true.
  static CameraUnavailableReason get unsupportedReason =>
      CameraUnavailableReason.unknown;
}