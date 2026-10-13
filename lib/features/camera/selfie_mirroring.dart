import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Decides whether a captured photo must be flipped horizontally before it is
/// stored, and is the single place the selfie-mirroring rules live.
///
/// ## The problem this solves
///
/// A selfie preview reads as a mirror, so the front camera is normally shown
/// flipped. That flip has to live in *exactly one* place, or selfies come out
/// double-mirrored (unreadable text, people on the wrong side) or not
/// mirrored at all.
///
/// Two independent things can mirror a capture, and they must never both do
/// it:
///
/// 1. **The platform.** On iOS Safari the browser already hands back
///    front-camera frames mirrored, so the bytes need no work. The native
///    camera plugins return the sensor's natural orientation, so those bytes
///    *do* need flipping.
/// 2. **The user's preference.** [CameraPreferences.mirrorSelfies] defaults to
///    on, matching what a mirror shows.
///
/// The rule is therefore: flip only when the platform has *not* already
/// flipped and the user *wants* a mirror - or when the platform *has* flipped
/// and the user wants the natural image. Either way exactly one flip happens.
abstract final class SelfieMirroring {
  /// Whether `takePicture()` already returns front-camera frames mirrored on
  /// this platform.
  ///
  /// - Web/iOS Safari: **true**. Verified on the physical iPhone 16e - captured
  ///   selfies arrive left/right reversed, which is the reason this class
  ///   exists. Safari's `<video>` front-camera stream is mirrored and
  ///   `canvas.toBlob` captures that mirrored frame.
  /// - Native Android/iOS/desktop: **false**. The camera plugins deliver the
  ///   sensor's natural pixels.
  ///
  /// This is the one place to correct if a further device/browser combination
  /// turns out to behave differently; the decision logic below is pure and
  /// does not change.
  static bool get platformMirrorsFrontCapture => _platformMirrorsFrontCapture;

  static bool _platformMirrorsFrontCapture = true;

  /// Whether the *live preview* should be mirrored.
  ///
  /// Always true for the front camera, like a physical mirror, regardless of
  /// the preference: the preference controls the saved photo, not the viewfinder.
  /// Back cameras are never mirrored.
  static bool shouldMirrorPreview(CameraLensDirection direction) =>
      direction == CameraLensDirection.front;

  /// Whether a captured [XFile] needs a horizontal flip before it is stored.
  ///
  /// Back cameras are **never** mirrored. Front cameras are flipped only when
  /// doing so makes the stored image match the user's intent, which avoids
  /// both double-mirroring and a silently unmirrored selfie.
  static bool shouldFlipCapturedPhoto({
    required CameraLensDirection direction,
    required bool mirrorSelfies,
    bool? platformMirrors,
  }) {
    if (direction != CameraLensDirection.front) return false;
    final bool platformMirrored =
        platformMirrors ?? _platformMirrorsFrontCapture;
    return mirrorSelfies != platformMirrored;
  }

  /// Overrides the platform capability. Test-only.
  @visibleForTesting
  static void debugSetPlatformMirrorsFrontCapture(bool value) {
    _platformMirrorsFrontCapture = value;
  }
}