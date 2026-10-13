/// Camera preferences that persist between app launches.
class CameraPreferences {
  const CameraPreferences({
    this.countdownSeconds = 3,
    this.shutterSoundEnabled = true,
    this.flashAnimationEnabled = true,
    this.mirrorSelfies = true,
  });

  /// Countdown duration in seconds. Must be 3, 5, or 10.
  final int countdownSeconds;

  /// Whether to play a shutter sound on capture.
  final bool shutterSoundEnabled;

  /// Whether to show a flash animation on capture.
  final bool flashAnimationEnabled;

  /// Whether saved selfies are horizontally mirrored.
  ///
  /// Defaults to true so a selfie looks the way it did in the viewfinder.
  /// Back-camera photos are never mirrored either way.
  final bool mirrorSelfies;

  /// Creates a copy with the given fields replaced.
  CameraPreferences copyWith({
    int? countdownSeconds,
    bool? shutterSoundEnabled,
    bool? flashAnimationEnabled,
    bool? mirrorSelfies,
  }) {
    return CameraPreferences(
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      shutterSoundEnabled: shutterSoundEnabled ?? this.shutterSoundEnabled,
      flashAnimationEnabled: flashAnimationEnabled ?? this.flashAnimationEnabled,
      mirrorSelfies: mirrorSelfies ?? this.mirrorSelfies,
    );
  }

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'countdownSeconds': countdownSeconds,
      'shutterSoundEnabled': shutterSoundEnabled,
      'flashAnimationEnabled': flashAnimationEnabled,
      'mirrorSelfies': mirrorSelfies,
    };
  }

  /// Creates [CameraPreferences] from a JSON map.
  ///
  /// Missing keys fall back to the defaults, so preferences written by an older
  /// build still load - notably `mirrorSelfies`, which did not exist before the
  /// selfie-mirroring fix.
  factory CameraPreferences.fromJson(Map<String, dynamic> json) {
    return CameraPreferences(
      countdownSeconds: json['countdownSeconds'] as int? ?? 3,
      shutterSoundEnabled: json['shutterSoundEnabled'] as bool? ?? true,
      flashAnimationEnabled: json['flashAnimationEnabled'] as bool? ?? true,
      mirrorSelfies: json['mirrorSelfies'] as bool? ?? true,
    );
  }

  /// Valid countdown options.
  static const List<int> validCountdownOptions = [3, 5, 10];

  /// Whether the current countdown value is valid.
  bool get isValidCountdown => validCountdownOptions.contains(countdownSeconds);
}