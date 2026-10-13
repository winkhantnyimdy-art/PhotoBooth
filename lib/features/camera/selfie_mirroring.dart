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

  /// Whether the orientation of the photo that will actually be **stored**.
  ///
  /// True means the saved bytes read left-to-right as a mirror image.
  ///
  /// This is what the viewfinder must show, so that what the user framed is
  /// what they get. It is derived through the same two-step pipeline the
  /// capture path uses - the platform's own mirroring, then the app's - rather
  /// than being asserted directly, so the preview cannot drift away from the
  /// capture if the platform behaviour is ever corrected.
  static bool storedPhotoIsMirrored({
    required CameraLensDirection direction,
    required bool mirrorSelfies,
    bool? platformMirrors,
  }) {
    if (direction != CameraLensDirection.front) return false;
    final bool platformMirrored =
        platformMirrors ?? _platformMirrorsFrontCapture;
    final bool flipped = shouldFlipCapturedPhoto(
      direction: direction,
      mirrorSelfies: mirrorSelfies,
      platformMirrors: platformMirrored,
    );
    // Exactly one of "the platform mirrored it" and "we flipped it" may be
    // true, so the XOR reduces to the user's preference.
    return platformMirrored ^ flipped;
  }

  /// Whether the *live preview* should be mirrored.
  ///
  /// The preview mirrors exactly when the stored photo will be mirrored, for
  /// both lens directions. That is a deliberate change: the viewfinder used to
  /// be an unconditional mirror for the front camera, so a user who turned
  /// "Mirror selfies" off saw a mirrored preview and got an unmirrored photo -
  /// reported as the framing not matching the saved result. Showing the same
  /// orientation in both places removes that class of surprise.
  ///
  /// Back cameras are never mirrored.
  static bool shouldMirrorPreview({
    required CameraLensDirection direction,
    required bool mirrorSelfies,
    bool? platformMirrors,
  }) {
    return storedPhotoIsMirrored(
      direction: direction,
      mirrorSelfies: mirrorSelfies,
      platformMirrors: platformMirrors,
    );
  }

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