import 'dart:developer' show ServiceExtensionResponse, registerExtension;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/decorate/decorate_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
  if (kDebugMode) {
    _registerDevelopmentExtensions();
  }
}

/// Debug-only `ext.flutter.photoBooth.*` service extensions.
///
/// The verification harness should drive a real two-finger gesture, but the
/// Android emulator used in this workspace exposes no multitouch path to adb
/// (`input` is single-pointer, its event-console channel never reaches this
/// image's kernel, and `sendevent` needs root this image denies). The zoom
/// extension drives the editor preview's own TransformationController - the
/// exact object a pinch moves - so panning arms, the Fit bar appears and the
/// strip scales exactly as a gesture would, and the capture records the real
/// zoomed editing state.
///
/// Registered under `kDebugMode` only: release builds ship without these.
void _registerDevelopmentExtensions() {
  registerExtension('ext.flutter.photoBooth.previewZoom', (
    String method,
    Map<String, String> parameters,
  ) async {
    scheduleEditorZoomForCurrentEditor(
      double.tryParse(parameters['factor'] ?? ''),
    );
    return ServiceExtensionResponse.result('{"result":"ok"}');
  });
}
