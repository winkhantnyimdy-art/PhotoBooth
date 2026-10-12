/// Camera preferences that persist between app launches.
class CameraPreferences {
  const CameraPreferences({
    this.countdownSeconds = 3,
    this.shutterSoundEnabled = true,
    this.flashAnimationEnabled = true,
  });

  /// Countdown duration in seconds. Must be 3, 5, or 10.
  final int countdownSeconds;

  /// Whether to play a shutter sound on capture.
  final bool shutterSoundEnabled;

  /// Whether to show a flash animation on capture.
  final bool flashAnimationEnabled;

  /// Creates a copy with the given fields replaced.
  CameraPreferences copyWith({
    int? countdownSeconds,
    bool? shutterSoundEnabled,
    bool? flashAnimationEnabled,
  }) {
    return CameraPreferences(
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      shutterSoundEnabled: shutterSoundEnabled ?? this.shutterSoundEnabled,
      flashAnimationEnabled: flashAnimationEnabled ?? this.flashAnimationEnabled,
    );
  }

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'countdownSeconds': countdownSeconds,
      'shutterSoundEnabled': shutterSoundEnabled,
      'flashAnimationEnabled': flashAnimationEnabled,
    };
  }

  /// Creates [CameraPreferences] from a JSON map.
  factory CameraPreferences.fromJson(Map<String, dynamic> json) {
    return CameraPreferences(
      countdownSeconds: json['countdownSeconds'] as int? ?? 3,
      shutterSoundEnabled: json['shutterSoundEnabled'] as bool? ?? true,
      flashAnimationEnabled: json['flashAnimationEnabled'] as bool? ?? true,
    );
  }

  /// Valid countdown options.
  static const List<int> validCountdownOptions = [3, 5, 10];

  /// Whether the current countdown value is valid.
  bool get isValidCountdown => validCountdownOptions.contains(countdownSeconds);
}