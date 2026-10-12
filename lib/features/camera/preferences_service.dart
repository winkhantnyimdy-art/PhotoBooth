import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'camera_preferences.dart';

/// Service for persisting camera preferences using shared_preferences.
class PreferencesService {
  static const String _prefsKey = 'camera_preferences';

  final SharedPreferences _prefs;

  PreferencesService._(this._prefs);

  /// Creates and initializes the preferences service.
  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService._(prefs);
  }

  /// Loads the saved camera preferences, or returns defaults if none exist.
  CameraPreferences load() {
    final String? jsonString = _prefs.getString(_prefsKey);
    if (jsonString == null || jsonString.isEmpty) return const CameraPreferences();
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString) as Map<String, dynamic>;
      return CameraPreferences.fromJson(json);
    } catch (_) {
      return const CameraPreferences();
    }
  }

  /// Saves the camera preferences.
  Future<bool> save(CameraPreferences preferences) {
    return _prefs.setString(_prefsKey, jsonEncode(preferences.toJson()));
  }

  /// Resets preferences to defaults.
  Future<bool> reset() {
    return _prefs.remove(_prefsKey);
  }
}