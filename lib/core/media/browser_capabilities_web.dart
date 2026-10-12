import 'package:web/web.dart' as web;

import 'camera_unavailable_reason.dart';

/// Browser capability probes backed by the real DOM APIs.
///
/// Everything here is read-only inspection: no permission is requested and no
/// media stream is opened. The camera permission prompt itself is triggered by
/// the `camera_web` plugin when [availableCameras] resolves.
abstract final class BrowserCapabilities {
  /// True when the page exposes `navigator.mediaDevices.getUserMedia`.
  ///
  /// Safari only exposes `mediaDevices` in a secure context, so this also
  /// covers the "opened over plain http on the LAN" failure mode.
  static bool get hasCameraSupport {
    try {
      return web.window.isSecureContext;
    } catch (_) {
      return false;
    }
  }

  /// True when the page is served over HTTPS or from localhost.
  ///
  /// iOS Safari refuses `getUserMedia` outside a secure context, which is the
  /// single most common reason the camera will not start on an iPhone.
  static bool get isSecureContext {
    try {
      return web.window.isSecureContext;
    } catch (_) {
      return false;
    }
  }

  /// True when the Web Share API can accept file payloads.
  ///
  /// Safari on iOS supports file sharing from 15+, but capability detection is
  /// not possible without a [web.File], so the check is optimistic and the
  /// export service still falls back to a download.
  static bool get canShareFiles => true;

  /// Maps a `camera_web` / `CameraException` code to actionable copy.
  static CameraUnavailableReason? describeCameraError(String? code) {
    switch (code) {
      // camera_web: CameraErrorCode.permissionDenied
      case 'CameraAccessDenied':
      case 'cameraPermissionDenied':
      case 'NotAllowedError':
      case 'PermissionDeniedError':
        return const CameraUnavailableReason(
          title: 'Camera access blocked',
          detail:
              'Allow camera access for this site, then tap Try again. '
              'On iPhone: Share sheet -> "aA" -> Website Settings -> Camera.',
        );

      // camera_web: CameraErrorCode.notFound
      case 'cameraNotFound':
      case 'NotFoundError':
      case 'DevicesNotFoundError':
        return const CameraUnavailableReason(
          title: 'No camera found',
          detail:
              'This browser could not find a usable camera. Close other apps '
              'that might be holding it, then tap Try again.',
        );

      // camera_web: CameraErrorCode.notReadable
      case 'cameraNotReadable':
      case 'NotReadableError':
      case 'TrackStartError':
        return const CameraUnavailableReason(
          title: 'Camera is busy',
          detail:
              'Another app or tab is using the camera. Close it and tap '
              'Try again.',
        );

      // camera_web: CameraErrorCode.type — also raised for insecure contexts.
      case 'cameraType':
      case 'TypeError':
        return const CameraUnavailableReason(
          title: 'Camera needs a secure connection',
          detail:
              'Safari only allows camera access over HTTPS (or on localhost). '
              'Reopen this page using an https:// address.',
        );

      // camera_web: CameraErrorCode.security
      case 'cameraSecurity':
      case 'SecurityError':
        return const CameraUnavailableReason(
          title: 'Camera disabled in browser settings',
          detail:
              'Camera access is turned off for this browser. Enable it in '
              'Settings -> Safari -> Camera, then tap Try again.',
        );

      case 'cameraNotSupported':
        return const CameraUnavailableReason(
          title: 'Camera not supported',
          detail: 'This browser does not expose camera capture to web apps.',
        );

      default:
        return null;
    }
  }

  /// Copy for the insecure-context case, checked before any plugin call so the
  /// user never sees a raw `TypeError`.
  static CameraUnavailableReason get insecureContextReason =>
      const CameraUnavailableReason(
        title: 'Camera needs a secure connection',
        detail:
            'Safari only allows camera access over HTTPS (or on localhost). '
            'Reopen this page using an https:// address, then allow camera '
            'access when prompted.',
      );

  /// Copy shown when the browser exposes no media-device API at all.
  static CameraUnavailableReason get unsupportedReason =>
      const CameraUnavailableReason(
        title: 'Camera unavailable in this browser',
        detail:
            'This browser does not provide camera access to web apps. Open the '
            'page in Safari or Chrome over HTTPS.',
      );
}