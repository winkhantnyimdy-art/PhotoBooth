import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays the shutter click when a photo is captured.
///
/// Two browser realities shape this class:
///
/// 1. **Autoplay policy.** iOS Safari (and Chrome) refuse to start audio that
///    was not triggered by a real user gesture. The shutter press *is* a
///    gesture, but the actual capture happens seconds later after the
///    countdown, long after that gesture's activation window has closed. So
///    [prepare] is called synchronously from the shutter tap to wake the audio
///    context while the gesture is still live, and [play] then only has to
///    resume an already-running context.
/// 2. **Silence is better than a crash.** If audio is unavailable or blocked -
///    private browsing, a locked-down enterprise browser, a muted device -
///    capturing must still work. Every failure is swallowed and recorded in
///    [isAvailable] so the UI can explain the situation instead of throwing
///    inside a capture callback.
class ShutterSoundService {
  ShutterSoundService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  /// A service with no audio backend at all.
  ///
  /// Used where audio is unavailable or unwanted - and by tests, which must not
  /// depend on a registered audio plugin.
  ShutterSoundService.silent() : _player = null;

  final AudioPlayer? _player;

  bool _prepared = false;
  bool _available = true;
  bool _disposed = false;

  /// Asset key declared in `pubspec.yaml`.
  static const String assetPath = 'audio/shutter.wav';

  /// Whether the sound can currently be played.
  ///
  /// False after an audio failure, which the settings screen uses to show a
  /// hint rather than promising a sound the device will not make.
  bool get isAvailable => _available;

  /// Human-readable reason the sound is unavailable, or null.
  String? get unavailableReason =>
      _available ? null : 'Sound is blocked on this device.';

  /// Warms the audio context from inside a user gesture.
  ///
  /// Called on the shutter tap, *before* the countdown starts. Safe to call
  /// repeatedly; only the first call does work.
  Future<void> prepare() async {
    final AudioPlayer? player = _player;
    if (_disposed || _prepared || !_available || player == null) return;
    _prepared = true;
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(AssetSource(assetPath));
      // Resuming at zero volume primes the platform audio session without
      // emitting an audible click, then the real capture plays at full volume.
      await player.setVolume(0);
      await player.resume();
      await player.stop();
      await player.setVolume(1);
    } on Object catch (error) {
      _available = false;
      assert(() {
        debugPrint('ShutterSoundService: audio unavailable ($error)');
        return true;
      }());
    }
  }

  /// Plays the shutter click. No-op when disabled or unavailable.
  Future<void> play() async {
    final AudioPlayer? player = _player;
    if (_disposed || !_available || player == null) return;
    try {
      await player.setSource(AssetSource(assetPath));
      await player.setVolume(1);
      await player.resume();
    } on Object catch (error) {
      _available = false;
      assert(() {
        debugPrint('ShutterSoundService: play failed ($error)');
        return true;
      }());
    }
  }

  /// Releases the underlying player.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _player?.dispose();
    } on Object {
      // Nothing useful to do while tearing down.
    }
  }
}